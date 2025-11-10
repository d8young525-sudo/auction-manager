import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import '../models/shipping_group_model.dart';
import '../models/keyword_model.dart';

class FirebaseService {
  // Firebase 인스턴스
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 컬렉션 참조
  static CollectionReference get usersCollection =>
      _firestore.collection('users');
  static CollectionReference get itemsCollection =>
      _firestore.collection('items');
  static CollectionReference get shippingGroupsCollection =>
      _firestore.collection('shippingGroups');
  static CollectionReference get likesCollection =>
      _firestore.collection('likes');
  static CollectionReference get bookmarksCollection =>
      _firestore.collection('bookmarks');
  static CollectionReference get keywordsCollection =>
      _firestore.collection('keywords');

  // 현재 사용자
  static User? get currentFirebaseUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;
  
  // 인증 상태 변경 스트림
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== 인증 관련 ====================

  // 이메일/비밀번호 로그인
  static Future<UserModel> signInWithEmail(
      String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Firestore에서 사용자 정보 가져오기
    final userDoc =
        await usersCollection.doc(userCredential.user!.uid).get();

    if (!userDoc.exists) {
      throw Exception('사용자 정보를 찾을 수 없습니다');
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    
    // 마지막 로그인 시간 업데이트
    await usersCollection.doc(userCredential.user!.uid).update({
      'lastLoginAt': DateTime.now().toIso8601String(),
    });

    return UserModel.fromJson(userData);
  }

  // 이메일/비밀번호 회원가입
  static Future<UserModel> registerWithEmail(
      String email, String password, String nickname) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 새 사용자 정보 생성
    final newUser = UserModel(
      uid: userCredential.user!.uid,
      email: email,
      nickname: nickname,
      tier: UserTier.regular, // 초기 1000명까지는 일반 등급
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    // Firestore에 저장
    await usersCollection.doc(newUser.uid).set(newUser.toJson());

    return newUser;
  }

  // 로그아웃
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // 사용자 정보 가져오기
  static Future<UserModel?> getUserById(String uid) async {
    final userDoc = await usersCollection.doc(uid).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() as Map<String, dynamic>;
    return UserModel.fromJson(userData);
  }

  // 사용자 정보 업데이트
  static Future<void> updateUser(UserModel user) async {
    await usersCollection.doc(user.uid).update(user.toJson());
  }

  // ==================== 아이템 관련 ====================

  // 내 아이템 스트림
  static Stream<List<ItemModel>> getMyItemsStream(String userId) {
    // 단순 쿼리 사용 (인덱스 불필요)
    return itemsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ItemModel.fromJson(data);
      }).toList();
      
      // 메모리에서 생성일 최신 순 정렬
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return items;
    });
  }

  // 공개 아이템 스트림 (피드용)
  static Stream<List<ItemModel>> getPublicItemsStream(
      {String sortBy = 'latest'}) {
    // 단순 쿼리 사용 (인덱스 불필요)
    Query query = itemsCollection
        .where('isPublic', isEqualTo: true)
        .limit(100);

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ItemModel.fromJson(data);
      }).toList();

      // 마감 지난 아이템 필터링 (메모리에서)
      final validItems = items.where((item) => 
        !item.isExpired && 
        item.deadline.isAfter(DateTime.now())
      ).toList();

      // 메모리에서 정렬
      if (sortBy == 'latest') {
        // 생성일 최신 순
        validItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (sortBy == 'deadline') {
        // 마감일 빠른 순
        validItems.sort((a, b) => a.deadline.compareTo(b.deadline));
      } else if (sortBy == 'popular') {
        // 인기순 (좋아요 + 북마크)
        validItems.sort((a, b) {
          final scoreA = a.likeCount + a.bookmarkCount;
          final scoreB = b.likeCount + b.bookmarkCount;
          return scoreB.compareTo(scoreA);
        });
      }

      // 최대 50개만 반환
      return validItems.take(50).toList();
    });
  }

  // 아이템 추가
  static Future<void> addItem(ItemModel item) async {
    await itemsCollection.doc(item.id).set(item.toJson());
  }

  // 단일 아이템 조회
  static Future<ItemModel?> getItem(String itemId) async {
    final itemDoc = await itemsCollection.doc(itemId).get();
    if (itemDoc.exists) {
      final data = itemDoc.data() as Map<String, dynamic>;
      return ItemModel.fromJson(data);
    }
    return null;
  }

  // 아이템 업데이트
  static Future<void> updateItem(ItemModel item) async {
    await itemsCollection.doc(item.id).update(item.toJson());
  }

  // 아이템 삭제
  static Future<void> deleteItem(String itemId) async {
    await itemsCollection.doc(itemId).delete();
  }

  // 즐겨찾기 토글
  static Future<void> toggleFavorite(String itemId) async {
    final itemDoc = await itemsCollection.doc(itemId).get();
    if (itemDoc.exists) {
      final data = itemDoc.data() as Map<String, dynamic>;
      final currentFavorite = data['isFavorite'] ?? false;
      await itemsCollection.doc(itemId).update({
        'isFavorite': !currentFavorite,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // 구매완료 토글
  static Future<void> togglePurchased(String itemId) async {
    final itemDoc = await itemsCollection.doc(itemId).get();
    if (itemDoc.exists) {
      final data = itemDoc.data() as Map<String, dynamic>;
      final currentPurchased = data['isPurchased'] ?? false;
      await itemsCollection.doc(itemId).update({
        'isPurchased': !currentPurchased,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // 아이템 가격 업데이트
  static Future<void> updateItemPrice(String itemId, int price) async {
    await itemsCollection.doc(itemId).update({
      'purchasePrice': price,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ==================== 좋아요/북마크 관련 ====================

  // 좋아요 토글
  static Future<void> toggleLike(String userId, String itemId) async {
    final likeId = '${userId}_$itemId';
    final likeDoc = await likesCollection.doc(likeId).get();

    if (likeDoc.exists) {
      // 좋아요 취소
      await likesCollection.doc(likeId).delete();
      await itemsCollection.doc(itemId).update({
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      // 좋아요 추가
      await likesCollection.doc(likeId).set({
        'userId': userId,
        'itemId': itemId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await itemsCollection.doc(itemId).update({
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // 좋아요 확인
  static Future<bool> isLiked(String userId, String itemId) async {
    final likeId = '${userId}_$itemId';
    final likeDoc = await likesCollection.doc(likeId).get();
    return likeDoc.exists;
  }

  // 북마크 토글
  static Future<void> toggleBookmark(String userId, String itemId) async {
    final bookmarkId = '${userId}_$itemId';
    final bookmarkDoc = await bookmarksCollection.doc(bookmarkId).get();

    if (bookmarkDoc.exists) {
      // 북마크 취소
      await bookmarksCollection.doc(bookmarkId).delete();
      await itemsCollection.doc(itemId).update({
        'bookmarkCount': FieldValue.increment(-1),
      });
    } else {
      // 북마크 추가
      await bookmarksCollection.doc(bookmarkId).set({
        'userId': userId,
        'itemId': itemId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await itemsCollection.doc(itemId).update({
        'bookmarkCount': FieldValue.increment(1),
      });
    }
  }

  // 북마크 확인
  static Future<bool> isBookmarked(String userId, String itemId) async {
    final bookmarkId = '${userId}_$itemId';
    final bookmarkDoc = await bookmarksCollection.doc(bookmarkId).get();
    return bookmarkDoc.exists;
  }

  // ==================== 합배송 그룹 관련 ====================

  // 합배송 그룹 스트림
  static Stream<List<ShippingGroupModel>> getShippingGroupsStream(
      String userId) {
    return shippingGroupsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final groups = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ShippingGroupModel.fromJson(data);
      }).toList();
      
      // 메모리에서 정렬 (인덱스 불필요)
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return groups;
    });
  }

  // 합배송 그룹 추가
  static Future<void> addShippingGroup(ShippingGroupModel group) async {
    await shippingGroupsCollection.doc(group.id).set(group.toJson());
  }

  // 합배송 그룹 업데이트
  static Future<void> updateShippingGroup(ShippingGroupModel group) async {
    await shippingGroupsCollection.doc(group.id).update(group.toJson());
  }

  // 합배송 그룹 삭제
  static Future<void> deleteShippingGroup(String groupId) async {
    await shippingGroupsCollection.doc(groupId).delete();
  }

  // ==================== 관리자 관련 ====================

  // 모든 사용자 가져오기 (관리자 전용)
  static Future<List<UserModel>> getAllUsers() async {
    final snapshot = await usersCollection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return UserModel.fromJson(data);
    }).toList();
  }

  // 사용자 등급 변경 (관리자 전용)
  static Future<void> updateUserTier(String uid, UserTier tier) async {
    await usersCollection.doc(uid).update({
      'tier': tier.name,
    });
  }

  // 관리자 권한 설정 (관리자 전용)
  static Future<void> setAdminStatus(String uid, bool isAdmin) async {
    await usersCollection.doc(uid).update({
      'isAdmin': isAdmin,
    });
  }

  // ==================== 키워드 관련 ====================

  // 키워드 스트림
  static Stream<List<KeywordModel>> getKeywordsStream(String userId) {
    return keywordsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final keywords = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return KeywordModel.fromJson(data);
      }).toList();
      
      // 메모리에서 정렬 (인덱스 불필요)
      keywords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return keywords;
    });
  }

  // 키워드 추가
  static Future<void> addKeyword(KeywordModel keyword) async {
    await keywordsCollection.doc(keyword.id).set(keyword.toJson());
  }

  // 키워드 업데이트
  static Future<void> updateKeyword(KeywordModel keyword) async {
    await keywordsCollection.doc(keyword.id).update(keyword.toJson());
  }

  // 키워드 삭제
  static Future<void> deleteKeyword(String keywordId) async {
    await keywordsCollection.doc(keywordId).delete();
  }
}
