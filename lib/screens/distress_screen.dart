import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver_profile.dart';
import '../models/emergency_report.dart';
import '../services/api_service.dart';

class DistressScreen extends StatefulWidget {
  final EmergencyReport? report;
  final DriverProfile profile;
  final Future<EmergencyReport>? dispatchRequest;
  final String? pendingLocationName;
  final String? pendingDescription;

  const DistressScreen({
    super.key,
    required this.profile,
    this.report,
    this.dispatchRequest,
    this.pendingLocationName,
    this.pendingDescription,
  });

  @override
  State<DistressScreen> createState() => _DistressScreenState();
}

class _DistressScreenState extends State<DistressScreen> {
  late EmergencyReport _activeReport;

  bool _isDispatching = false;
  bool _isUpdating = false;
  String? _dispatchError;

  bool get _hasServerReport => _activeReport.id > 0;

  @override
  void initState() {
    super.initState();
    _activeReport = widget.report ?? _buildPendingReport();
    _isDispatching = widget.report == null && widget.dispatchRequest != null;
    _listenForDispatchResult();
  }

  EmergencyReport _buildPendingReport() {
    return EmergencyReport(
      id: 0,
      reportNo: 'Sending...',
      incidentType: 'distress_beacon',
      severity: 'critical',
      status: 'sending',
      locationName: widget.pendingLocationName ?? 'Location pending',
      description: widget.pendingDescription ??
          'Distress Beacon broadcast from VOS Mobile application.',
      reportedAt: DateTime.now().toIso8601String(),
      contactName: widget.profile.user?.name ?? 'Driver',
      contactPhone: widget.profile.user?.userContact ?? '',
    );
  }

  Future<void> _listenForDispatchResult() async {
    final request = widget.dispatchRequest;
    if (request == null) return;

    try {
      final report = await request;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeReport = report;
          _isDispatching = false;
          _dispatchError = null;
        });
        _showSnack('SOS signal sent to dispatch.');
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isDispatching = false;
          _dispatchError = e.toString();
        });
        _showSnack('SOS signal is not confirmed yet. Check connection.',
            isError: true);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else if (mounted) {
      _showSnack('Could not trigger native phone dialer.', isError: true);
    }
  }

  void _confirmBeingHelped() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF16A34A),
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Confirm Resolution',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF09090B),
                ),
              ),
            ],
          ),
          content: const Text(
            'Confirm that assistance has arrived or the emergency is resolved. This closes the active SOS distress beacon.',
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
                Navigator.pop(context);
                _resolveIncident();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CONFIRM RESOLVED',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resolveIncident() async {
    if (!_hasServerReport) {
      _showSnack('Dispatch confirmation is required before closing this SOS.',
          isError: true);
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await ApiService().resolveEmergencyReport(
        _activeReport.id,
        'Driver confirmed assistance has arrived / situation resolved.',
      );

      if (mounted) {
        _showSnack('Distress beacon resolved successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to resolve beacon: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF166534),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFFE4E4E7), height: 1),
        ),
        title: const Text(
          'EMERGENCY ACTIVE',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF09090B),
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDispatchHero(),
                const SizedBox(height: 16),
                _buildActiveBeaconPanel(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchHero() {
    final hasError = _dispatchError != null;
    final tone = hasError
        ? const Color(0xFFF59E0B)
        : (_isDispatching ? const Color(0xFF1D4ED8) : const Color(0xFFB91C1C));
    final softTone = hasError
        ? const Color(0xFFFEF3C7)
        : (_isDispatching ? const Color(0xFFDBEAFE) : const Color(0xFFFEE2E2));
    final label = hasError
        ? 'SIGNAL NOT CONFIRMED'
        : (_isDispatching ? 'SENDING SOS SIGNAL' : 'SOS SIGNAL DISPATCHED');
    final headline = hasError
        ? 'Keep this emergency page open.'
        : (_isDispatching
            ? 'Opening response channel...'
            : 'Emergency response is active.');
    final body = hasError
        ? 'The page is still usable, but dispatch has not confirmed the report. Call the hotline now if the situation is critical.'
        : (_isDispatching
            ? 'Your emergency page is ready while VOS sends coordinates and driver context in the background.'
            : 'Ref ${_activeReport.reportNo} is live. Keep this page open so dispatch can receive driver updates quickly.');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            softTone.withValues(alpha: 0.74),
            Colors.white,
          ],
          stops: const [0, 0.72],
        ),
        border: Border.all(
          color: tone.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18181B).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: softTone,
              border: Border.all(
                color: tone.withValues(alpha: 0.24),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _isDispatching
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    hasError
                        ? Icons.signal_wifi_connected_no_internet_4_rounded
                        : Icons.warning_amber_rounded,
                    color: tone,
                    size: 29,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  headline,
                  style: const TextStyle(
                    color: Color(0xFF09090B),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF52525B),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBeaconPanel() {
    final hasError = _dispatchError != null;
    final tone = hasError
        ? const Color(0xFFF59E0B)
        : (_isDispatching ? const Color(0xFF1D4ED8) : const Color(0xFFB91C1C));
    final title = hasError
        ? 'Signal needs attention'
        : (_isDispatching
            ? 'Broadcasting SOS...'
            : 'SOS Signal Dispatched');
    final description = hasError
        ? 'Dispatch has not confirmed the digital report yet. Please call the hotline below.'
        : 'SCM dispatch has received your coordinates and active trip context. A representative will call you immediately. Keep this screen open.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E4E7)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withValues(alpha: 0.12),
              border: Border.all(
                color: tone.withValues(alpha: 0.32),
                width: 2,
              ),
            ),
            child: _isDispatching
                ? Padding(
                    padding: const EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      color: tone,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    hasError ? Icons.priority_high_rounded : Icons.sos_rounded,
                    color: tone,
                    size: 32,
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF09090B),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF52525B),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.08),
              border: Border.all(color: tone.withValues(alpha: 0.16)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REFERENCE ID',
                  style: TextStyle(
                    color: tone,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _activeReport.reportNo,
                  style: const TextStyle(
                    color: Color(0xFF09090B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _makeCall('+639171234567'),
          icon: const Icon(Icons.phone_in_talk, color: Colors.white),
          label: const Text('CALL DISPATCH HOTLINE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed:
              (_isUpdating || !_hasServerReport) ? null : _confirmBeingHelped,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            _hasServerReport ? 'I AM BEING HELPED' : 'WAITING FOR CONFIRMATION',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF09090B),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE4E4E7),
            disabledForegroundColor: const Color(0xFF71717A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
