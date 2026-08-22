class UserModel {
  final String userId;
  final String name;
  final String phoneNumber;
  final List<String> circleIds;
  final List<String> fcmTokens;

  UserModel({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.circleIds,
    required this.fcmTokens,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      circleIds: List<String>.from(json['circleIds'] ?? []),
      fcmTokens: List<String>.from(json['fcmTokens'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'circleIds': circleIds,
      'fcmTokens': fcmTokens,
    };
  }
}
