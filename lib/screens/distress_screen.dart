import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver_profile.dart';
import '../models/emergency_report.dart';
import '../services/api_service.dart';

class DistressScreen extends StatefulWidget {
  final EmergencyReport report;
  final DriverProfile profile;

  const DistressScreen({
    super.key,
    required this.report,
    required this.profile,
  });

  @override
  State<DistressScreen> createState() => _DistressScreenState();
}

class _DistressScreenState extends State<DistressScreen> {
  late EmergencyReport _activeReport;
  
  final _notesController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _activeReport = widget.report;
    _contactNameController.text = widget.profile.user?.name ?? '';
    _contactPhoneController.text = widget.profile.user?.userContact ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _updateDetails() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    setState(() => _isUpdating = true);

    try {
      final updatedDescription = '${_activeReport.description}\n\n[Mobile Update]: $notes';
      
      final updated = await ApiService().updateIncidentNotes(
        _activeReport.id,
        updatedDescription,
        _contactNameController.text.trim(),
        _contactPhoneController.text.trim(),
      );

      setState(() {
        _activeReport = updated;
        _notesController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Distress details updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not trigger native phone dialer.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        title: const Text('EMERGENCY ACTIVE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF09090B), fontSize: 15)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ALARM HEADER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFEF2F2), // Light red (var(--destructive-bg))
                    Colors.white,
                  ],
                  stops: [0.0, 0.74],
                ),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.24)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF18181B).withOpacity(0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.24)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SOS Signal Dispatched',
                          style: TextStyle(color: Color(0xFF09090B), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reference Code: ${_activeReport.reportNo}',
                          style: const TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DATA SUMMARY
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE4E4E7)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INCIDENT REPORT METADATA', style: TextStyle(color: Color(0xFF71717A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildMetaRow('Driver Name', widget.profile.user?.name ?? 'Unknown'),
                    _buildMetaRow('Vehicle Assigned', widget.profile.activeTrip?.vehiclePlate ?? 'None'),
                    _buildMetaRow('Active Route', widget.profile.activeTrip?.docNo ?? 'None'),
                    _buildMetaRow('GPS Coordinates', _activeReport.locationName ?? 'Unknown'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: Color(0xFFE4E4E7)),
                    ),
                    const Text('Distress Statement:', style: TextStyle(color: Color(0xFF71717A), fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      _activeReport.description,
                      style: const TextStyle(color: Color(0xFF27272A), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // UPDATE NOTES FORM
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE4E4E7)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('BROADCAST AN UPDATE', style: TextStyle(color: Color(0xFF71717A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactNameController,
                      style: const TextStyle(color: Color(0xFF09090B), fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Contact Person Name',
                        labelStyle: TextStyle(color: Color(0xFF71717A)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE4E4E7)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Color(0xFF09090B), fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number',
                        labelStyle: TextStyle(color: Color(0xFF71717A)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE4E4E7)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF09090B), fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Situation Update (e.g. Engine fire, Cargo safe, tire burst)',
                        labelStyle: TextStyle(color: Color(0xFF71717A)),
                        alignLabelWithHint: true,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE4E4E7)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _updateDetails,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('SEND NOTES UPDATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // CALL BUTTON
            ElevatedButton.icon(
              onPressed: () => _makeCall('+639171234567'),
              icon: const Icon(Icons.phone_in_talk, color: Colors.white),
              label: const Text('CALL DISPATCH CENTER HOTLINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E), // var(--success)
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF09090B), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
