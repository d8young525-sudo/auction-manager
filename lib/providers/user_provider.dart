import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // 현재 사용자 로드
  Future<void> loadCurrentUser() async {
    final userId = FirebaseService.currentUserId;
    if (userId != null) {
      _currentUser = await FirebaseService.getUserById(userId);
      notifyListeners();
    }
  }

  // 로그인
  Future<void> login(String email, String password) async {
    _currentUser = await FirebaseService.signInWithEmail(email, password);
    notifyListeners();
  }

  // 회원가입
  Future<void> register(String email, String password, String nickname) async {
    _currentUser = await FirebaseService.registerWithEmail(
      email,
      password,
      nickname,
    );
    notifyListeners();
  }

  // 로그아웃
  Future<void> logout() async {
    await FirebaseService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // 프로필 업데이트
  Future<void> updateProfile({
    String? nickname,
    String? bio,
    String? profileImage,
    String? youtubeUrl,
  }) async {
    if (_currentUser == null) return;

    final updatedUser = _currentUser!.copyWith(
      nickname: nickname ?? _currentUser!.nickname,
      bio: bio ?? _currentUser!.bio,
      profileImage: profileImage ?? _currentUser!.profileImage,
      youtubeUrl: youtubeUrl ?? _currentUser!.youtubeUrl,
    );

    await FirebaseService.updateUser(updatedUser);
    _currentUser = updatedUser;
    notifyListeners();
  }
}
