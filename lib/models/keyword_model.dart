class KeywordModel {
  String id;
  String userId;
  String keyword;
  String? translation; // 번역된 키워드 (옵션)
  bool notificationEnabled;
  DateTime createdAt;

  KeywordModel({
    required this.id,
    required this.userId,
    required this.keyword,
    this.translation,
    this.notificationEnabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'keyword': keyword,
      'translation': translation,
      'notificationEnabled': notificationEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory KeywordModel.fromJson(Map<String, dynamic> json) {
    return KeywordModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      keyword: json['keyword'] as String,
      translation: json['translation'] as String?,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  KeywordModel copyWith({
    String? id,
    String? userId,
    String? keyword,
    String? translation,
    bool? notificationEnabled,
    DateTime? createdAt,
  }) {
    return KeywordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      keyword: keyword ?? this.keyword,
      translation: translation ?? this.translation,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
