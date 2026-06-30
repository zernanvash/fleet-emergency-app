import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_profile.dart';
import '../models/emergency_report.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      // Default gateway (port 3000 where our Next.js BFF is running)
      baseUrl: 'http://100.105.235.94:3000',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Inject stored cookies before each request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('vos_access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Cookie'] = 'vos_access_token=$token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        // Intercept Set-Cookie headers on login/refresh
        final setCookies = response.headers['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          for (var cookie in setCookies) {
            if (cookie.startsWith('vos_access_token=')) {
              final token = cookie.split('vos_access_token=')[1].split(';')[0];
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('vos_access_token', token);
            }
          }
        }
        return handler.next(response);
      },
    ));
  }

  late final Dio _dio;

  /// Update the Base URL if the user is debugging on a custom local network IP (Tailscale, Local Wi-Fi)
  void setBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl.replaceAll(RegExp(r'/+$'), '');
  }

  String get baseUrl => _dio.options.baseUrl;

  /// Auto-discover the working Next.js BFF endpoint by testing candidates in parallel.
  Future<void> autoDiscoverBaseUrl() async {
    final candidates = [
      'http://100.105.235.94:3000',
      'http://10.0.2.2:3000',
      'http://localhost:3000',
    ];

    print('Auto-discovering Next.js BFF URL among candidates: $candidates');

    final results = await Future.wait(
      candidates.map((url) async {
        try {
          final tempDio = Dio(BaseOptions(
            connectTimeout: const Duration(milliseconds: 1500),
            receiveTimeout: const Duration(milliseconds: 1500),
          ));
          final response = await tempDio.get(url);
          if (response.statusCode != null && response.statusCode! < 500) {
            return url;
          }
        } catch (e) {
          if (e is DioException && e.response != null) {
            final status = e.response!.statusCode;
            if (status != null && status < 500) {
              return url;
            }
          }
        }
        return null;
      }),
    );

    final workingUrl =
        results.firstWhere((url) => url != null, orElse: () => null);
    if (workingUrl != null) {
      setBaseUrl(workingUrl);
      print('Next.js BFF connection established at: $workingUrl');
    } else {
      print(
          'Auto-discovery failed to reach Next.js BFF. Defaulting to: $baseUrl');
    }
  }

  /// Clear session data on logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vos_access_token');
  }

  /// Check if the driver has an active session token
  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vos_access_token');
    return token != null && token.isNotEmpty;
  }

  /// Login driver and capture session cookie
  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Some backends return the token directly in the response payload body
        final data = response.data;
        final token = data['token'] ??
            data['accessToken'] ??
            data['access_token'] ??
            data['jwt'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('vos_access_token', token);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('ApiService login error: $e');
      rethrow;
    }
  }

  /// Resolve current logged-in driver's profile, plate number, and active trip plan
  Future<DriverProfile> getDriverProfile() async {
    try {
      final response = await _dio
          .get('/api/scm/fleet-management/emergency-management/driver-profile');
      if (response.statusCode == 200) {
        return DriverProfile.fromJson(response.data);
      }
      throw Exception(
          'Failed to resolve driver profile: Code ${response.statusCode}');
    } catch (e) {
      print('ApiService getDriverProfile error: $e');
      rethrow;
    }
  }

  /// Broadcast distress signal POST request
  Future<EmergencyReport> createEmergencyReport({
    required int? vehicleId,
    required int? driverUserId,
    required int? dispatchPlanId,
    required String locationName,
    required double? latitude,
    required double? longitude,
    required String description,
    required String contactName,
    required String contactPhone,
    List<String> attachments = const [],
  }) async {
    try {
      final response = await _dio.post(
          '/api/scm/fleet-management/emergency-management/reports',
          data: {
            'incident_type': 'other',
            'severity': 'critical',
            'vehicle_id': vehicleId,
            'driver_user_id': driverUserId,
            'dispatch_plan_id': dispatchPlanId,
            'occurred_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 8))
                .toIso8601String()
                .replaceAll('Z', ''),
            'location_name': locationName,
            'latitude': latitude,
            'longitude': longitude,
            'description': description,
            'contact_name': contactName,
            'contact_phone': contactPhone,
            if (attachments.isNotEmpty) 'attachments': jsonEncode(attachments),
          });

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Enriched response contains generated Reference Number ER-XXXX-XXXX
        final reportData = response.data['report'];
        if (reportData == null) {
          throw Exception(
              'API response was successful but report payload was missing.');
        }
        return EmergencyReport.fromJson(reportData);
      }
      throw Exception(
          'Failed to create emergency report: Code ${response.statusCode}');
    } catch (e) {
      if (e is DioException) {
        print('ApiService createEmergencyReport details: ${e.response?.data}');
      }
      print('ApiService createEmergencyReport error: $e');
      rethrow;
    }
  }

  /// Update situation updates for an active distress report
  Future<EmergencyReport> updateIncidentNotes(int reportId, String notes,
      String contactName, String contactPhone) async {
    try {
      final response = await _dio.patch(
          '/api/scm/fleet-management/emergency-management/reports/$reportId',
          data: {
            'description': notes,
            'contact_name': contactName,
            'contact_phone': contactPhone,
          });

      if (response.statusCode == 200) {
        final reportData = response.data['report'];
        if (reportData == null) {
          throw Exception(
              'API response was successful but report payload was missing.');
        }
        return EmergencyReport.fromJson(reportData);
      }
      throw Exception(
          'Failed to update incident details: Code ${response.statusCode}');
    } catch (e) {
      print('ApiService updateIncidentNotes error: $e');
      rethrow;
    }
  }

  /// Cancel/resolve the active emergency report when driver is being helped
  Future<EmergencyReport> resolveEmergencyReport(
      int reportId, String reason) async {
    try {
      final response = await _dio.patch(
          '/api/scm/fleet-management/emergency-management/reports/$reportId',
          data: {
            'status': 'cancelled',
            'cancelled_reason': reason,
          });

      if (response.statusCode == 200) {
        final reportData = response.data['report'];
        if (reportData == null) {
          throw Exception(
              'API response was successful but report payload was missing.');
        }
        return EmergencyReport.fromJson(reportData);
      }
      throw Exception(
          'Failed to resolve emergency report: Code ${response.statusCode}');
    } catch (e) {
      print('ApiService resolveEmergencyReport error: $e');
      rethrow;
    }
  }
}
