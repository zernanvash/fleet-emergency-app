class DriverProfile {
  final bool isDriver;
  final UserProfile? user;
  final ActiveTrip? activeTrip;

  DriverProfile({
    required this.isDriver,
    this.user,
    this.activeTrip,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      isDriver: json['isDriver'] ?? false,
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
      activeTrip: json['activeTrip'] != null
          ? ActiveTrip.fromJson(json['activeTrip'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isDriver': isDriver,
      'user': user?.toJson(),
      'activeTrip': activeTrip?.toJson(),
    };
  }
}

class UserProfile {
  final int userId;
  final String name;
  final String? userContact;
  final String? userEmail;

  UserProfile({
    required this.userId,
    required this.name,
    this.userContact,
    this.userEmail,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      userContact: json['user_contact'],
      userEmail: json['user_email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'user_contact': userContact,
      'user_email': userEmail,
    };
  }
}

class ActiveTrip {
  final int id;
  final String docNo;
  final String? status;
  final int? vehicleId;
  final String? vehiclePlate;

  ActiveTrip({
    required this.id,
    required this.docNo,
    this.status,
    this.vehicleId,
    this.vehiclePlate,
  });

  factory ActiveTrip.fromJson(Map<String, dynamic> json) {
    return ActiveTrip(
      id: json['id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      status: json['status'],
      vehicleId: json['vehicle_id'],
      vehiclePlate: json['vehicle_plate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doc_no': docNo,
      'status': status,
      'vehicle_id': vehicleId,
      'vehicle_plate': vehiclePlate,
    };
  }
}
