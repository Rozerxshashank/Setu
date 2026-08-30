class FamilyCircleMember {
  final String userId;
  final String name;
  final String role; // "primary" | "sibling"

  FamilyCircleMember({
    required this.userId,
    required this.name,
    required this.role,
  });

  factory FamilyCircleMember.fromJson(Map<String, dynamic> json) {
    return FamilyCircleMember(
      userId: json['userId'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'name': name, 'role': role};
  }
}

class FamilyCircle {
  final String circleId;
  final String elderName;
  final String elderPhoneNumber;
  final String preferredLanguage;
  final String checkInTime; // "09:00"
  final String timezone; // "Asia/Kolkata"
  final String interactionChannel; // "whatsapp" | "call"
  final List<FamilyCircleMember> members;
  final List<String> memberIds; // Added for Security Rules efficiency
  final DateTime createdAt;

  FamilyCircle({
    required this.circleId,
    required this.elderName,
    required this.elderPhoneNumber,
    required this.preferredLanguage,
    required this.checkInTime,
    required this.timezone,
    required this.interactionChannel,
    required this.members,
    required this.memberIds,
    required this.createdAt,
  });

  factory FamilyCircle.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt = DateTime.now();
    if (json['createdAt'] != null && json['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now();
    }

    return FamilyCircle(
      circleId: json['circleId'] as String,
      elderName: json['elderName'] as String,
      elderPhoneNumber: json['elderPhoneNumber'] as String,
      preferredLanguage: json['preferredLanguage'] as String,
      checkInTime: json['checkInTime'] as String,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata', // Safely fallback for existing circles
      interactionChannel: json['interactionChannel'] as String,
      members:
          (json['members'] as List<dynamic>?)
              ?.map(
                (e) => FamilyCircleMember.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      memberIds: List<String>.from(json['memberIds'] ?? []),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'circleId': circleId,
      'elderName': elderName,
      'elderPhoneNumber': elderPhoneNumber,
      'preferredLanguage': preferredLanguage,
      'checkInTime': checkInTime,
      'timezone': timezone,
      'interactionChannel': interactionChannel,
      'members': members.map((e) => e.toJson()).toList(),
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
