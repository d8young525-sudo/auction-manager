import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../models/shipping_group_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'package:uuid/uuid.dart';

enum ItemFilter { all, favorite, createdDesc }

enum ItemSort { deadlineAsc, createdDesc, priceAsc }

class ItemProvider with ChangeNotifier {
  final _uuid = const Uuid();

  ItemFilter _currentFilter = ItemFilter.all;
  ItemSort _currentSort = ItemSort.deadlineAsc;

  ItemFilter get currentFilter => _currentFilter;
  ItemSort get currentSort => _currentSort;

  // 필터 변경
  void setFilter(ItemFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  // 정렬 변경
  void setSort(ItemSort sort) {
    _currentSort = sort;
    notifyListeners();
  }

  // 내 아이템 목록 가져오기 (스트림용 - 간단한 리스트 반환)
  List<ItemModel> getMyItems(String userId) {
    // 실제로는 StreamBuilder에서 사용
    return [];
  }

  // 공개 아이템 목록 가져오기 (스트림용)
  List<ItemModel> getPublicItems({String? sortBy}) {
    // 실제로는 StreamBuilder에서 사용
    return [];
  }

  // 아이템 추가
  Future<void> addItem(ItemModel item) async {
    await FirebaseService.addItem(item);

    // 알림 예약
    if (!item.isPurchased && !item.isExpired) {
      await NotificationService.scheduleItemDeadlineNotifications(item);
    }

    notifyListeners();
  }

  // 아이템 업데이트
  Future<void> updateItem(ItemModel item) async {
    final updatedItem = item.copyWith(updatedAt: DateTime.now());
    await FirebaseService.updateItem(updatedItem);

    // 알림 재예약
    await NotificationService.cancelItemNotifications(updatedItem.id);
    if (!updatedItem.isPurchased && !updatedItem.isExpired) {
      await NotificationService.scheduleItemDeadlineNotifications(updatedItem);
    }

    notifyListeners();
  }

  // 아이템 삭제
  Future<void> deleteItem(String itemId) async {
    await FirebaseService.deleteItem(itemId);
    await NotificationService.cancelItemNotifications(itemId);
    notifyListeners();
  }

  // 즐겨찾기 토글
  Future<void> toggleFavorite(String itemId) async {
    await FirebaseService.toggleFavorite(itemId);
    notifyListeners();
  }

  // 구매완료 토글
  Future<void> togglePurchased(String itemId) async {
    await FirebaseService.togglePurchased(itemId);
    notifyListeners();
  }

  // 아이템 가격 업데이트
  Future<void> updateItemPrice(String itemId, int price) async {
    await FirebaseService.updateItemPrice(itemId, price);
    notifyListeners();
  }

  // 좋아요 토글
  Future<void> toggleLike(String userId, String itemId) async {
    await FirebaseService.toggleLike(userId, itemId);
    notifyListeners();
  }

  // 북마크 토글
  Future<void> toggleBookmark(String userId, String itemId) async {
    await FirebaseService.toggleBookmark(userId, itemId);
    notifyListeners();
  }

  // 합배송 그룹 생성
  Future<String> createShippingGroup(String userId, String groupName) async {
    final groupId = _uuid.v4();
    final group = ShippingGroupModel(
      id: groupId,
      userId: userId,
      name: groupName,
      createdAt: DateTime.now(),
    );

    await FirebaseService.addShippingGroup(group);
    notifyListeners();
    return groupId;
  }

  // 합배송 그룹 목록 가져오기
  List<ShippingGroupModel> getShippingGroups(String userId) {
    // 실제로는 StreamBuilder에서 사용
    return [];
  }

  // 합배송 그룹 삭제
  Future<void> deleteShippingGroup(String groupId) async {
    await FirebaseService.deleteShippingGroup(groupId);
    notifyListeners();
  }

  // 내 목록에 추가 (큐레이션 복사)
  Future<void> addToMyList(ItemModel sourceItem, String userId) async {
    final newItem = ItemModel(
      id: _uuid.v4(),
      userId: userId,
      url: sourceItem.url,
      title: sourceItem.title,
      thumbnailUrl: sourceItem.thumbnailUrl,
      deadline: sourceItem.deadline,
      size: sourceItem.size,
      isPublic: false,
      tags: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await addItem(newItem);
  }

  // 그룹 업데이트 (나중에 구현)
  Future<void> updateShippingGroup(String groupId) async {
    // TODO: 구현
  }
}
