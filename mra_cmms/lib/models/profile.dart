class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? email;
  final String? type; // e.g., admin, technician
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.email,
    this.type,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        fullName: map['full_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        email: map['email'] as String?,
        type: map['type'] as String?,
        fcmToken: map['fcm_token'] as String?,
        createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
        updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'email': email,
        'type': type,
        'fcm_token': fcmToken,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
