import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'offline_queue.dart';

class BackgroundSyncService {
  static const String _notificationChannelId = 'my_foreground';
  static const int _notificationId = 888;

  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  /// Initialize the background service configuration.
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Start manually when an item is enqueued
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'VOS Emergency Sync Active',
        initialNotificationContent: 'Monitoring connectivity to broadcast distress beacon...',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onStart,
      ),
    );
  }

  /// Start the background service.
  Future<void> start() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  /// Stop the background service.
  Future<void> stop() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  }
}

/// The top-level execution entry point for the background isolate.
@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  // If the main app requests stopping the service
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Run a periodic sync timer in the background
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    final hasPending = await OfflineQueue().hasPending();
    if (!hasPending) {
      // No pending reports — sync is finished. Stop the service.
      timer.cancel();
      service.stopSelf();
      return;
    }

    try {
      final result = await OfflineQueue().flush();
      if (result != null) {
        // Report successfully sent in background!
        timer.cancel();

        // Update the notification to indicate success before shutting down
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: 'Distress Beacon Dispatched',
              content: 'SOS signal was successfully uploaded in background.',
            );
          }
        }

        // Wait 3 seconds so the driver can see the success notification, then stop service
        Future.delayed(const Duration(seconds: 3), () {
          service.stopSelf();
        });
      }
    } catch (_) {
      // Request failed — will try again on the next tick
    }
  });

  return true;
}
