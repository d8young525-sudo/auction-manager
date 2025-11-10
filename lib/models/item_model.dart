class ItemModel {
  String id;
  String userId;
  String url;
  String title;
  String thumbnailUrl;
  DateTime deadline;
  String? size;
  String? memo;
  bool isFavorite;
  bool isPurchased;
  int? purchasePrice;
  String? shippingGroupId;
  bool isPublic;
  List<String> tags;
  bool instantPurchase; // 즉시결제 가능 여부
  int likeCount;
  int bookmarkCount;
  DateTime createdAt;
  DateTime updatedAt;

  ItemModel({
    required this.id,
    required this.userId,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.deadline,
    this.size,
    this.memo,
    this.isFavorite = false,
    this.isPurchased = false,
    this.purchasePrice,
    this.shippingGroupId,
    this.isPublic = false,
    this.tags = const [],
    this.instantPurchase = false,
    this.likeCount = 0,
    this.bookmarkCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // 마감까지 남은 시간 계산
  Duration get timeUntilDeadline => deadline.difference(DateTime.now());

  // 마감 임박 여부 (24시간 이내)
  bool get isDeadlineSoon => timeUntilDeadline.inHours <= 24 && timeUntilDeadline.inHours >= 0;

  // 마감 지남 여부
  bool get isExpired => timeUntilDeadline.isNegative;

  // 마감일 표시 문자열
  String get deadlineString {
    if (isExpired) return '마감됨';
    
    final days = timeUntilDeadline.inDays;
    final hours = timeUntilDeadline.inHours % 24;
    
    if (days > 0) {
      return 'D-$days';
    } else if (hours > 0) {
      return '$hours시간 후';
    } else {
      return '${timeUntilDeadline.inMinutes}분 후';
    }
  }

  // Firestore JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'url': url,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'deadline': deadline.toIso8601String(),
      'size': size,
      'memo': memo,
      'isFavorite': isFavorite,
      'isPurchased': isPurchased,
      'purchasePrice': purchasePrice,
      'shippingGroupId': shippingGroupId,
      'isPublic': isPublic,
      'tags': tags,
      'instantPurchase': instantPurchase,
      'likeCount': likeCount,
      'bookmarkCount': bookmarkCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      size: json['size'] as String?,
      memo: json['memo'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isPurchased: json['isPurchased'] as bool? ?? false,
      purchasePrice: json['purchasePrice'] as int?,
      shippingGroupId: json['shippingGroupId'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      instantPurchase: json['instantPurchase'] as bool? ?? false,
      likeCount: json['likeCount'] as int? ?? 0,
      bookmarkCount: json['bookmarkCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ItemModel copyWith({
    String? id,
    String? userId,
    String? url,
    String? title,
    String? thumbnailUrl,
    DateTime? deadline,
    String? size,
    String? memo,
    bool? isFavorite,
    bool? isPurchased,
    int? purchasePrice,
    String? shippingGroupId,
    bool? isPublic,
    List<String>? tags,
    bool? instantPurchase,
    int? likeCount,
    int? bookmarkCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      deadline: deadline ?? this.deadline,
      size: size ?? this.size,
      memo: memo ?? this.memo,
      isFavorite: isFavorite ?? this.isFavorite,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      shippingGroupId: shippingGroupId ?? this.shippingGroupId,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
      instantPurchase: instantPurchase ?? this.instantPurchase,
      likeCount: likeCount ?? this.likeCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
