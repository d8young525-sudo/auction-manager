// 회원 등급
enum UserTier {
  newbie,   // 신규: 아이템 추가, 발견 조회만 가능
  regular,  // 일반: 큐레이션 공개 가능
  premium,  // 열심: 카드 강조 + "닉네임 추천템" 배지
}

class UserModel {
  String uid;
  String email;
  String nickname;
  String? profileImage;
  String? bio;
  String? youtubeUrl;
  UserTier tier;
  bool isAdmin;
  DateTime createdAt;
  DateTime? lastLoginAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.profileImage,
    this.bio,
    this.youtubeUrl,
    this.tier = UserTier.regular, // 초기 1000명까지는 일반 등급
    this.isAdmin = false,
    required this.createdAt,
    this.lastLoginAt,
  });

  // 등급별 권한 확인
  bool get canPublishItems => tier != UserTier.newbie;
  bool get isPremiumUser => tier == UserTier.premium;
  
  // 등급 이름
  String get tierName {
    switch (tier) {
      case UserTier.newbie:
        return '신규';
      case UserTier.regular:
        return '일반';
      case UserTier.premium:
        return '열심';
    }
  }
  
  // 등급 아이콘
  String get tierIcon {
    switch (tier) {
      case UserTier.newbie:
        return '🆕';
      case UserTier.regular:
        return '👤';
      case UserTier.premium:
        return '⭐';
    }
  }

  // Firestore JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname,
      'profileImage': profileImage,
      'bio': bio,
      'youtubeUrl': youtubeUrl,
      'tier': tier.name,
      'isAdmin': isAdmin,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      profileImage: json['profileImage'] as String?,
      bio: json['bio'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      tier: UserTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => UserTier.regular,
      ),
      isAdmin: json['isAdmin'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? nickname,
    String? profileImage,
    String? bio,
    String? youtubeUrl,
    UserTier? tier,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      profileImage: profileImage ?? this.profileImage,
      bio: bio ?? this.bio,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      tier: tier ?? this.tier,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
