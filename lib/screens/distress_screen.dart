import 'package:flutter/material';
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
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('EMERGENCY ACTIVE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
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
                color: Colors.red[950]!.withOpacity(0.4),
                border: Border.all(color: Colors.red[800]!.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_rounded, size: 50, color: Colors.red[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'SOS Signal Dispatched',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reference Code: ${_activeReport.reportNo}',
                    style: TextStyle(color: Colors.red[200]!.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DATA SUMMARY
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INCIDENT REPORT METADATA', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildMetaRow('Driver Name', widget.profile.user?.name ?? 'Unknown'),
                    _buildMetaRow('Vehicle Assigned', widget.profile.activeTrip?.vehiclePlate ?? 'None'),
                    _buildMetaRow('Active Route', widget.profile.activeTrip?.docNo ?? 'None'),
                    _buildMetaRow('GPS Coordinates', _activeReport.locationName ?? 'Unknown'),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 4),
                    const Text('Distress Statement:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      _activeReport.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // UPDATE NOTES FORM
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('BROADCAST AN UPDATE', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactNameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Contact Person Name',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Situation Update (e.g. Engine fire, Cargo safe, tire burst)',
                        labelStyle: TextStyle(color: Colors.grey),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _updateDetails,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('SEND NOTES UPDATE', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
              label: const Text('CALL DISPATCH CENTER HOTLINE', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
