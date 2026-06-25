class EmergencyReport {
  final int id;
  final String reportNo;
  final String incidentType;
  final String severity;
  final String status;
  final String? locationName;
  final String description;
  final String reportedAt;
  final String? contactName;
  final String? contactPhone;

  EmergencyReport({
    required this.id,
    required this.reportNo,
    required this.incidentType,
    required this.severity,
    required this.status,
    this.locationName,
    required this.description,
    required this.reportedAt,
    this.contactName,
    this.contactPhone,
  });

  factory EmergencyReport.fromJson(Map<String, dynamic> json) {
    return EmergencyReport(
      id: json['id'] ?? 0,
      reportNo: json['report_no'] ?? '',
      incidentType: json['incident_type'] ?? '',
      severity: json['severity'] ?? '',
      status: json['status'] ?? 'reported',
      locationName: json['location_name'],
      description: json['description'] ?? '',
      reportedAt: json['reported_at'] ?? '',
      contactName: json['contact_name'],
      contactPhone: json['contact_phone'],
    );
  }
}
