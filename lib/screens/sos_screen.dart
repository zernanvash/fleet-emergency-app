import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_report.dart';
import '../services/api_service.dart';
import '../services/directus_auth_service.dart';
import '../models/driver_profile.dart';
import 'distress_screen.dart';
import 'login_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  DriverProfile? _profile;
  Position? _position;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Concentric Rings Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _startLocationListening() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  Future<void> _loadData() async {
    try {
      // 1. Resolve Driver Profile & active trip via Directus directly
      final userId = await DirectusAuthService().getStoredUserId();
      if (userId == null) {
        // No session — go back to login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }
      final profileData = await DirectusAuthService().getDriverProfile(userId);
      if (mounted) {
        setState(() {
          _profile = profileData;
        });
      }

      if (!profileData.isDriver) {
        return;
      }

      // 2. Resolve Geolocation
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          // Attempt instant fallback to last known location first
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null && mounted) {
            setState(() => _position = lastPos);
          }

          // Start continuous background location updates
          _startLocationListening();

          // Fetch current position with a shorter, more responsive timeout and medium accuracy
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          if (mounted) {
            setState(() => _position = pos);
          }
        }
      } catch (geoError) {
        debugPrint('Non-blocking GPS error: $geoError');
      }
    } catch (e) {
      debugPrint('Load context error: $e');
    }
  }

  // --- SOS Button tap & confirm handler ---

  void _confirmSOS() {
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, resolving driver profile...'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm SOS Alert',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF09090B),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to broadcast a critical distress beacon to SCM dispatch? This will send your coordinates immediately.',
            style: TextStyle(color: Color(0xFF71717A)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _triggerSOS(); // Proceed with SOS
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('SEND ALERT',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.vibrate();

    final profile = _profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver profile is still loading.')),
      );
      return;
    }

    // Try a last-second quick fetch of coordinates if the background stream hasn't resolved it yet.
    if (_position == null) {
      try {
        final lastPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 2),
        );
        _position = lastPos;
      } catch (e) {
        debugPrint('Last-second location fetch timed out or failed: $e');
      }
    }

    final lat = _position?.latitude;
    final lon = _position?.longitude;

    final locationName = lat != null
        ? 'GPS: ${lat.toStringAsFixed(6)}, ${lon?.toStringAsFixed(6)}'
        : 'Location Unknown';

    const description =
        'Distress Beacon broadcast from VOS Mobile application.';
    final dispatchRequest = _createEmergencyReport(
      profile: profile,
      locationName: locationName,
      latitude: lat,
      longitude: lon,
      description: description,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DistressScreen(
            profile: profile,
            dispatchRequest: dispatchRequest,
            pendingLocationName: locationName,
            pendingDescription: description,
          ),
        ),
      );
    }
  }

  Future<EmergencyReport> _createEmergencyReport({
    required DriverProfile profile,
    required String locationName,
    required double? latitude,
    required double? longitude,
    required String description,
  }) {
    return ApiService().createEmergencyReport(
      vehicleId: profile.activeTrip?.vehicleId,
      driverUserId: profile.user?.userId,
      dispatchPlanId: profile.activeTrip?.id,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      description: description,
      contactName: profile.user?.name ?? 'Driver',
      contactPhone: profile.user?.userContact ?? '',
    );
  }

  Future<void> _handleLogout() async {
    await DirectusAuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile?.isDriver == false) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Color(0xFFF59E0B)),
              const SizedBox(height: 16),
              const Text(
                'Access Restricted',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF09090B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account is not registered as an SCM driver.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF71717A)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                ),
                child: const Text('LOGOUT'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(color: Color(0xFFE4E4E7), height: 1.0, thickness: 1.0),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SOS CONSOLE',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1,
                    color: Color(0xFF09090B))),
            const SizedBox(height: 2),
            Text(
              _profile == null
                  ? 'Loading profile...'
                  : '${_profile?.user?.name ?? 'Driver'}  •  ${_profile?.activeTrip?.vehiclePlate ?? 'No Vehicle'}  •  Trip: ${_profile?.activeTrip?.docNo ?? 'None'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF71717A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF71717A)),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSosActionPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildSosActionPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 0.9,
          colors: [
            const Color(0xFF1D4ED8).withValues(alpha: 0.1),
            Colors.white,
          ],
        ),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Text(
            'EMERGENCY ACTION',
            style: TextStyle(
              color: Color(0xFF71717A),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap SOS only after confirming the route and location details.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF52525B),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          GestureDetector(
            onTap: _confirmSOS,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final secondPulse = (_pulseController.value + 0.5) % 1.0;
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        _buildPulseRing(_pulseController.value, 0.14),
                        _buildPulseRing(secondPulse, 0.09),
                      ],
                    );
                  },
                ),
                Semantics(
                  button: true,
                  label: 'Send SOS distress alert to dispatch',
                  child: Material(
                    elevation: 12,
                    shape: const CircleBorder(),
                    shadowColor:
                        const Color(0xFFDC2626).withValues(alpha: 0.35),
                    child: Container(
                      width: 154,
                      height: 154,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF7F1D1D),
                          width: 4,
                        ),
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFFEF4444),
                            Color(0xFFB91C1C),
                          ],
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'SEND ALERT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white70,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dispatch receives coordinates, trip context, and driver contact after confirmation.',
                    style: TextStyle(color: Color(0xFF78350F), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRing(double progress, double maxOpacity) {
    return Transform.scale(
      scale: 1.0 + (progress * 0.45),
      child: Container(
        width: 154,
        height: 154,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFEF4444)
                .withValues(alpha: (1.0 - progress) * maxOpacity),
            width: 2.0,
          ),
        ),
      ),
    );
  }
}
