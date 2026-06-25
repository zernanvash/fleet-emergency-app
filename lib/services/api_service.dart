import 'dart:io';
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
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
        final token = data['token'] ?? data['accessToken'] ?? data['access_token'] ?? data['jwt'];
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
      final response = await _dio.get('/api/scm/fleet-management/emergency-management/driver-profile');
      if (response.statusCode == 200) {
        return DriverProfile.fromJson(response.data);
      }
      throw Exception('Failed to resolve driver profile: Code ${response.statusCode}');
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
  }) async {
    try {
      final response = await _dio.post('/api/scm/fleet-management/emergency-management/reports', data: {
        'incident_type': 'other',
        'severity': 'critical',
        'vehicle_id': vehicleId,
        'driver_user_id': driverUserId,
        'dispatch_plan_id': dispatchPlanId,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'location_name': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'contact_name': contactName,
        'contact_phone': contactPhone,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Enriched response contains generated Reference Number ER-XXXX-XXXX
        final reportData = response.data['report'];
        return EmergencyReport.fromJson(reportData);
      }
      throw Exception('Failed to create emergency report: Code ${response.statusCode}');
    } catch (e) {
      print('ApiService createEmergencyReport error: $e');
      rethrow;
    }
  }

  /// Update situation updates for an active distress report
  Future<EmergencyReport> updateIncidentNotes(int reportId, String notes, String contactName, String contactPhone) async {
    try {
      final response = await _dio.patch('/api/scm/fleet-management/emergency-management/reports/$reportId', data: {
        'description': notes,
        'contact_name': contactName,
        'contact_phone': contactPhone,
      });

      if (response.statusCode == 200) {
        final reportData = response.data['report'];
        return EmergencyReport.fromJson(reportData);
      }
      throw Exception('Failed to update incident details: Code ${response.statusCode}');
    } catch (e) {
      print('ApiService updateIncidentNotes error: $e');
      rethrow;
    }
  }
}
