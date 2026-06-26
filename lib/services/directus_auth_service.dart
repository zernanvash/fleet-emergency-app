import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_profile.dart';

/// Hybrid auth service:
///   - LOGIN  → Spring Boot /auth/login (same as VOS web app)
///   - PROFILE → Directus REST API with static token
///
/// This means the user's VOS credentials work exactly as they do on the web.
/// The Directus static token is only used for reading driver/trip data, never
/// for user authentication.
class DirectusAuthService {
  // ── Config ───────────────────────────────────────────────────────────────────

  /// Spring Boot base URL — same server the BFF proxies to.
  static const String _springBase = 'http://100.105.235.94:8082';

  /// Directus CMS base URL — for driver/trip collection reads.
  static const String _directusBase = 'http://goatedcodoer:8056';

  /// Read-only static token — only used for collection reads, not auth.
  static const String _staticToken = 'AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW';

  // ── Singleton ─────────────────────────────────────────────────────────────────

  static final DirectusAuthService _instance = DirectusAuthService._internal();
  factory DirectusAuthService() => _instance;

  late final Dio _spring;
  late final Dio _directus;

  DirectusAuthService._internal() {
    _spring = Dio(BaseOptions(
      baseUrl: _springBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _directus = Dio(BaseOptions(
      baseUrl: _directusBase,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Authorization': 'Bearer $_staticToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  // ── Login (Spring Boot) ───────────────────────────────────────────────────────

  /// Authenticates the user against Spring Boot (same as VOS web app).
  /// Returns the user's [userId] decoded from the JWT on success, or null.
  Future<int?> login(String email, String password) async {
    try {
      final res = await _spring.post('/auth/login', data: {
        'email': email.trim(),
        'hashPassword': password.trim(), // Spring Boot field name
        'rememberMe': false,
        'latitude': '',
        'longitude': '',
      });

      final token = res.data['token'] as String?;
      if (token == null || token.isEmpty) return null;

      // Decode JWT payload (no verification needed — we trust our own Spring Boot)
      final userId = _extractUserIdFromJwt(token);
      final firstName = _extractClaimFromJwt(token, 'FirstName') ?? '';
      final lastName = _extractClaimFromJwt(token, 'LastName') ?? '';

      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('directus_user_id', userId);
        await prefs.setString('directus_user_email', email.trim());
        await prefs.setString('directus_user_name', '$firstName $lastName'.trim());
        await prefs.setString('spring_jwt', token);
        await prefs.setString('vos_access_token', token);
      }

      return userId;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;

      if (status == 401 || status == 403) {
        final msg = body is Map ? (body['message'] ?? '') : '';
        if (msg.toString().toLowerCase().contains('block')) {
          throw DirectusAuthException('Your account has been blocked. Contact your administrator.');
        }
        if (msg.toString().toLowerCase().contains('lock')) {
          throw DirectusAuthException('Account is temporarily locked. Try again later.');
        }
        return null; // Invalid credentials
      }

      // Network / server unreachable
      throw DirectusAuthException('Cannot reach the VOS server. Check your connection.');
    } catch (e) {
      throw DirectusAuthException('Login error: ${e.toString()}');
    }
  }

  // ── Profile (Directus) ───────────────────────────────────────────────────────

  /// Fetches the driver profile and active trip for [userId].
  Future<DriverProfile> getDriverProfile(int userId) async {
    // 1. Fetch user record
    Map<String, dynamic>? userRow;
    try {
      final userRes = await _directus.get(
        '/items/user'
        '?filter=${Uri.encodeComponent('{"user_id":{"_eq":$userId}}')}'
        '&fields=user_id,user_fname,user_lname,user_email,user_contact'
        '&limit=1',
      );
      final ul = userRes.data['data'] as List?;
      if (ul != null && ul.isNotEmpty) {
        userRow = ul[0] as Map<String, dynamic>;
      }
    } catch (e) {
      print('Directus user fetch error: $e');
    }

    // Fallback: use name from stored prefs if Directus fetch fails
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString('directus_user_name') ?? 'VOS User';
    final storedEmail = prefs.getString('directus_user_email') ?? '';

    // 2. Check if they are a registered driver
    Map<String, dynamic>? driverRow;
    try {
      final driverRes = await _directus.get(
        '/items/driver'
        '?filter=${Uri.encodeComponent('{"user_id":{"_eq":$userId}}')}'
        '&fields=id,user_id,branch_id'
        '&limit=1',
      );
      final dl = driverRes.data['data'] as List?;
      if (dl != null && dl.isNotEmpty) {
        driverRow = dl[0] as Map<String, dynamic>;
      }
    } catch (e) {
      print('Directus driver fetch error: $e');
    }

    // 3. Find active trip (post_dispatch_plan with status = Dispatched)
    Map<String, dynamic>? tripRow;
    try {
      final tripFilter = Uri.encodeComponent(
        '{"_and":[{"status":{"_eq":"Dispatched"}},{"driver_id":{"_eq":$userId}}]}',
      );
      final tripRes = await _directus.get(
        '/items/post_dispatch_plan'
        '?filter=$tripFilter'
        '&fields=id,doc_no,status,vehicle_id'
        '&limit=1'
        '&sort=-date_encoded',
      );
      final tl = tripRes.data['data'] as List?;
      if (tl != null && tl.isNotEmpty) {
        tripRow = tl[0] as Map<String, dynamic>;
      }
    } catch (e) {
      print('Directus active trip fetch error: $e');
    }

    // 4. Fallback: latest trip plan of any status if no active Dispatched trip is found
    if (tripRow == null) {
      try {
        final tripFilter = Uri.encodeComponent(
          '{"driver_id":{"_eq":$userId}}',
        );
        final tripRes = await _directus.get(
          '/items/post_dispatch_plan'
          '?filter=$tripFilter'
          '&fields=id,doc_no,status,vehicle_id'
          '&limit=1'
          '&sort=-date_encoded',
        );
        final tl = tripRes.data['data'] as List?;
        if (tl != null && tl.isNotEmpty) {
          tripRow = tl[0] as Map<String, dynamic>;
        }
      } catch (e) {
        print('Directus backup trip fetch error: $e');
      }
    }

    // 5. Fetch vehicle plate details if vehicle_id is present
    String? vehiclePlate;
    int? vehicleId;
    if (tripRow != null && tripRow['vehicle_id'] != null) {
      final vId = tripRow['vehicle_id'];
      if (vId is int) {
        vehicleId = vId;
      } else if (vId is Map) {
        vehicleId = vId['id'] ?? vId['vehicle_id'];
      } else {
        vehicleId = int.tryParse(vId.toString());
      }

      if (vehicleId != null) {
        try {
          final vehRes = await _directus.get('/items/vehicles/$vehicleId?fields=vehicle_plate');
          final data = vehRes.data['data'];
          if (data is Map) {
            vehiclePlate = data['vehicle_plate']?.toString();
          }
        } catch (e) {
          print('Directus vehicle fetch error: $e');
        }
      }
    }

    // Build UserProfile
    final userProfile = UserProfile(
      userId: userRow?['user_id'] ?? userId,
      name: userRow != null
          ? '${userRow['user_fname'] ?? ''} ${userRow['user_lname'] ?? ''}'.trim()
          : storedName,
      userContact: userRow?['user_contact']?.toString(),
      userEmail: userRow?['user_email']?.toString() ?? storedEmail,
    );

    // Build ActiveTrip
    ActiveTrip? activeTrip;
    if (tripRow != null) {
      activeTrip = ActiveTrip(
        id: tripRow['id'] ?? 0,
        docNo: tripRow['doc_no'] ?? '',
        status: tripRow['status']?.toString(),
        vehicleId: vehicleId,
        vehiclePlate: vehiclePlate,
      );
    }

    if (driverRow == null) {
      return DriverProfile(
        isDriver: false,
        user: userProfile,
        activeTrip: null,
      );
    }

    return DriverProfile(
      isDriver: true,
      user: userProfile,
      activeTrip: activeTrip,
    );
  }

  // ── Session helpers ───────────────────────────────────────────────────────────

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('directus_user_id');
  }

  Future<int?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('directus_user_id');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('directus_user_id');
    await prefs.remove('directus_user_email');
    await prefs.remove('directus_user_name');
    await prefs.remove('spring_jwt');
    await prefs.remove('vos_access_token');
  }

  // ── JWT helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      // Pad base64url to multiple of 4
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  int? _extractUserIdFromJwt(String token) {
    final payload = _decodeJwtPayload(token);
    if (payload == null) return null;
    final sub = payload['sub'];
    if (sub is int) return sub;
    if (sub is String) return int.tryParse(sub);
    return null;
  }

  String? _extractClaimFromJwt(String token, String claim) {
    final payload = _decodeJwtPayload(token);
    return payload?[claim]?.toString();
  }
}

/// Thrown when auth fails for a known, user-displayable reason.
class DirectusAuthException implements Exception {
  final String message;
  const DirectusAuthException(this.message);

  @override
  String toString() => message;
}
