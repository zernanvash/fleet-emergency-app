import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'upload_service.dart';
import 'background_sync_service.dart';

/// Stores a single pending emergency report in SharedPreferences so it
/// survives app restarts and is retried the next time the BFF is reachable.
///
/// Only one report can be queued at a time (the last SOS always wins).
class OfflineQueue {
  static final OfflineQueue _instance = OfflineQueue._internal();
  factory OfflineQueue() => _instance;
  OfflineQueue._internal();

  static const _payloadKey = 'offline_report_payload';
  static const _photosKey = 'offline_report_photos';

  /// Serialize [payload] (report POST body) and optional [localPhotoPaths]
  /// to SharedPreferences.
  Future<void> enqueue(
    Map<String, dynamic> payload,
    List<String> localPhotoPaths,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_payloadKey, jsonEncode(payload));
    await prefs.setString(_photosKey, jsonEncode(localPhotoPaths));

    // Start background sync service to handle transmission if app is minimized
    await BackgroundSyncService().start();
  }

  /// Returns true if there is a queued report waiting to be sent.
  Future<bool> hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_payloadKey);
  }

  /// Clears the queue without sending.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_payloadKey);
    await prefs.remove(_photosKey);
  }

  /// Uploads any queued photos, then POSTs the emergency report.
  ///
  /// Returns the created [EmergencyReport] on success, or null if there is
  /// nothing queued or the attempt fails (caller should retry later).
  Future<Map<String, dynamic>?> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPayload = prefs.getString(_payloadKey);
    if (rawPayload == null) return null;

    final payload = Map<String, dynamic>.from(jsonDecode(rawPayload) as Map);
    final rawPhotos = prefs.getString(_photosKey);
    final photoPaths = rawPhotos != null
        ? List<String>.from(jsonDecode(rawPhotos) as List)
        : <String>[];

    try {
      // 1. Upload any locally-stored photos that were captured while offline.
      if (photoPaths.isNotEmpty) {
        final uuids = <String>[];
        final baseUrl = ApiService().baseUrl;
        for (final path in photoPaths) {
          final file = File(path);
          if (await file.exists()) {
            try {
              final uuid = await UploadService().uploadPhoto(file, baseUrl);
              uuids.add(uuid);
            } catch (e) {
              // Skip individual failed uploads; don't block the whole report.
            }
          }
        }
        if (uuids.isNotEmpty) {
          payload['attachments'] = jsonEncode(uuids);
        }
      }

      // 2. POST the report.
      final report = await ApiService().createEmergencyReport(
        vehicleId: payload['vehicle_id'] as int?,
        driverUserId: payload['driver_user_id'] as int?,
        dispatchPlanId: payload['dispatch_plan_id'] as int?,
        locationName: payload['location_name'] as String? ?? 'Location Unknown',
        latitude: (payload['latitude'] as num?)?.toDouble(),
        longitude: (payload['longitude'] as num?)?.toDouble(),
        description: payload['description'] as String? ?? '',
        contactName: payload['contact_name'] as String? ?? '',
        contactPhone: payload['contact_phone'] as String? ?? '',
        attachments: payload['attachments'] != null
            ? List<String>.from(
                jsonDecode(payload['attachments'] as String) as List)
            : [],
      );

      await clear();
      return report.toJson();
    } catch (_) {
      // BFF still unreachable — leave the queue intact.
      return null;
    }
  }
}
