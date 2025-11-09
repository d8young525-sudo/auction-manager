class ShippingGroupModel {
  String id;
  String userId;
  String name;
  List<String> itemIds;
  int totalPrice;
  int itemCount;
  DateTime createdAt;
  DateTime? completedAt;

  ShippingGroupModel({
    required this.id,
    required this.userId,
    required this.name,
    this.itemIds = const [],
    this.totalPrice = 0,
    this.itemCount = 0,
    required this.createdAt,
    this.completedAt,
  });

  // 완료 여부
  bool get isCompleted => completedAt != null;

  // Firestore JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'itemIds': itemIds,
      'totalPrice': totalPrice,
      'itemCount': itemCount,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ShippingGroupModel.fromJson(Map<String, dynamic> json) {
    return ShippingGroupModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      itemIds: (json['itemIds'] as List<dynamic>?)?.cast<String>() ?? [],
      totalPrice: json['totalPrice'] as int? ?? 0,
      itemCount: json['itemCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  ShippingGroupModel copyWith({
    String? id,
    String? userId,
    String? name,
    List<String>? itemIds,
    int? totalPrice,
    int? itemCount,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ShippingGroupModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      totalPrice: totalPrice ?? this.totalPrice,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
