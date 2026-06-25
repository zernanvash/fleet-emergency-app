import 'dart:async';
import 'package:flutter/material';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../models/driver_profile.dart';
import 'distress_screen.dart';
import 'login_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  DriverProfile? _profile;
  Position? _position;
  
  bool _isLoading = true;
  String _statusText = 'Initializing SOS Console...';
  
  // SOS Hold Animation states
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  bool _isHolding = false;
  
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
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Resolving driver context...';
    });

    try {
      // 1. Resolve Driver Profile & active trip
      final profileData = await ApiService().getDriverProfile();
      setState(() => _profile = profileData);

      if (!profileData.isDriver) {
        setState(() {
          _isLoading = false;
          _statusText = 'Access Restricted: Profile is not a driver.';
        });
        return;
      }

      // 2. Resolve Geolocation
      setState(() => _statusText = 'Resolving GPS coordinates...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        setState(() => _position = pos);
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Load context error: $e');
      setState(() {
        _isLoading = false;
        _statusText = 'Error initializing: $e';
      });
    }
  }

  // --- SOS Button hold handler ---

  void _startHolding() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _holdProgress += 0.025; // 40 ticks (50ms * 40 = 2 seconds)
        
        // Haptic feedback tick
        if (timer.tick % 4 == 0) {
          HapticFeedback.lightImpact();
        }
      });

      if (_holdProgress >= 1.0) {
        _holdTimer?.cancel();
        _triggerSOS();
      }
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    if (_holdProgress < 1.0) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.vibrate();
    
    setState(() {
      _isLoading = true;
      _statusText = 'Broadcasting emergency signals...';
    });

    try {
      final lat = _position?.latitude;
      final lon = _position?.longitude;
      final locationName = lat != null ? 'GPS: ${lat.toStringAsFixed(6)}, ${lon?.toStringAsFixed(6)}' : 'Location Unknown';

      final report = await ApiService().createEmergencyReport(
        vehicleId: _profile?.activeTrip?.vehicleId,
        driverUserId: _profile?.user?.userId,
        dispatchPlanId: _profile?.activeTrip?.id,
        locationName: locationName,
        latitude: lat,
        longitude: lon,
        description: 'Distress Beacon broadcast from VOS Mobile application.',
        contactName: _profile?.user?.name ?? 'Driver',
        contactPhone: _profile?.user?.userContact ?? '',
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DistressScreen(
              report: report,
              profile: _profile!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit SOS: $e')),
        );
        setState(() {
          _isLoading = false;
          _isHolding = false;
          _holdProgress = 0.0;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await ApiService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[950],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red[500]),
              const SizedBox(height: 16),
              Text(
                _statusText,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_profile?.isDriver == false) {
      return Scaffold(
        backgroundColor: Colors.grey[950],
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_person, size: 80, color: Colors.amber[500]),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: Colors.amber[100], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account is not registered as an SCM driver.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                child: const Text('LOGOUT'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('SOS DISTRESS BEACON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CONTEXT BLOCK
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[900],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('Driver', _profile?.user?.name ?? 'Unknown'),
                    ),
                    Expanded(
                      child: _buildInfoItem('Vehicle Plate', _profile?.activeTrip?.vehiclePlate ?? 'Not Assigned'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('Trip Sequence', _profile?.activeTrip?.docNo ?? 'No active trip'),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'GPS Position',
                        _position != null 
                            ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
                            : 'Locating...',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 2. SOS BUTTON AREA
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.red[950]!.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isHolding ? 'HOLDING SOS BROADCAST...' : 'HOLD BUTTON TO TRIGGER SOS',
                    style: TextStyle(
                      color: _isHolding ? Colors.red[400] : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // THE PANIC GESTURE TRIGGER
                  GestureDetector(
                    onTapDown: (_) => _startHolding(),
                    onTapUp: (_) => _stopHolding(),
                    onTapCancel: () => _stopHolding(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated Concentric Pulsing Rings
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 160 + (_pulseController.value * 60),
                                  height: 160 + (_pulseController.value * 60),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red[500]!.withOpacity((1 - _pulseController.value) * 0.15),
                                  ),
                                ),
                                Container(
                                  width: 160 + ((_pulseController.value + 0.5) % 1.0 * 60),
                                  height: 160 + ((_pulseController.value + 0.5) % 1.0 * 60),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red[500]!.withOpacity((1 - (_pulseController.value + 0.5) % 1.0) * 0.1),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        
                        // Circular Hold Progress Tracker Overlay
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: _holdProgress,
                            strokeWidth: 6,
                            backgroundColor: Colors.transparent,
                            color: Colors.red[500],
                          ),
                        ),

                        // Physical Circular Button UI
                        Material(
                          elevation: 12,
                          shape: const CircleBorder(),
                          shadowColor: Colors.red[500]!.withOpacity(0.4),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red[900]!, width: 4),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.red[500]!,
                                  Colors.red[800]!,
                                ],
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.siren_rounded, size: 40, color: Colors.white),
                                SizedBox(height: 4),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.black,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  'DISTRESS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // WARN BLOCK
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[500]!.withOpacity(0.08),
                      border: Border.all(color: Colors.amber[500]!.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber[600], size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Warning: Distressing will automatically alert SCM central dispatch operations with coordinates.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
