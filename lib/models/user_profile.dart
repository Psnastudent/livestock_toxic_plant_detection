class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String village;
  final int livestockCount;
  final String photoUrl;
  final String loginMethod;
  final DateTime createdAt;
  /// 'user' or 'admin'
  final String role;
  final bool isProfileComplete;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.phoneNumber = '',
    this.village = '',
    this.livestockCount = 0,
    required this.photoUrl,
    required this.loginMethod,
    required this.createdAt,
    this.role = 'user',
    this.isProfileComplete = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: (map['uid'] as String?) ?? 'user_001',
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      village: (map['village'] as String?) ?? '',
      livestockCount: (map['livestockCount'] as num?)?.toInt() ?? 0,
      photoUrl: (map['photoUrl'] as String?) ?? 'https://picsum.photos/id/433/200/200',
      loginMethod: (map['loginMethod'] as String?) ?? 'Mock',
      role: (map['role'] as String?) ?? 'user',
      isProfileComplete: (map['isProfileComplete'] as bool?) ?? false,
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'] as String)
          : (map['createdAt'] as DateTime? ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'village': village,
      'livestockCount': livestockCount,
      'photoUrl': photoUrl,
      'loginMethod': loginMethod,
      'role': role,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? phoneNumber,
    String? village,
    int? livestockCount,
    String? photoUrl,
    String? loginMethod,
    DateTime? createdAt,
    String? role,
    bool? isProfileComplete,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      village: village ?? this.village,
      livestockCount: livestockCount ?? this.livestockCount,
      photoUrl: photoUrl ?? this.photoUrl,
      loginMethod: loginMethod ?? this.loginMethod,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }
}

