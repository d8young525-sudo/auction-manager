import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await FirebaseService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _changeTier(UserModel user, UserTier newTier) async {
    try {
      await FirebaseService.updateUserTier(user.uid, newTier);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등급이 변경되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _banUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 밴'),
        content: Text('${user.nickname} 사용자를 밴 처리하시겠습니까?\n\n'
            '밴 처리하면 "신규" 등급으로 변경되어 큐레이션 공개가 불가능해집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('밴 처리'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _changeTier(user, UserTier.newbie);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👑 관리자 - 회원 관리'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: user.tier == UserTier.premium
                            ? Colors.amber.shade700
                            : user.tier == UserTier.newbie
                                ? Colors.red.shade400
                                : Theme.of(context).colorScheme.primary,
                        child: Text(
                          user.nickname[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(user.nickname),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: user.tier == UserTier.premium
                                  ? Colors.amber.shade100
                                  : user.tier == UserTier.newbie
                                      ? Colors.red.shade50
                                      : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: user.tier == UserTier.premium
                                    ? Colors.amber.shade700
                                    : user.tier == UserTier.newbie
                                        ? Colors.red.shade400
                                        : Colors.blue.shade400,
                              ),
                            ),
                            child: Text(
                              '${user.tierIcon} ${user.tierName}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: user.tier == UserTier.premium
                                    ? Colors.amber.shade900
                                    : user.tier == UserTier.newbie
                                        ? Colors.red.shade900
                                        : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        user.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('UID: ${user.uid}',
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                  '가입일: ${user.createdAt.toString().substring(0, 10)}',
                                  style: const TextStyle(fontSize: 11)),
                              if (user.lastLoginAt != null)
                                Text(
                                    '마지막 로그인: ${user.lastLoginAt.toString().substring(0, 10)}',
                                    style: const TextStyle(fontSize: 11)),
                              const Divider(height: 24),
                              const Text('등급 변경:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    avatar: const Text('🆕'),
                                    label: const Text('신규'),
                                    backgroundColor:
                                        user.tier == UserTier.newbie
                                            ? Colors.red.shade100
                                            : null,
                                    onPressed: user.tier != UserTier.newbie
                                        ? () => _changeTier(user, UserTier.newbie)
                                        : null,
                                  ),
                                  ActionChip(
                                    avatar: const Text('👤'),
                                    label: const Text('일반'),
                                    backgroundColor:
                                        user.tier == UserTier.regular
                                            ? Colors.blue.shade100
                                            : null,
                                    onPressed: user.tier != UserTier.regular
                                        ? () => _changeTier(user, UserTier.regular)
                                        : null,
                                  ),
                                  ActionChip(
                                    avatar: const Text('⭐'),
                                    label: const Text('열심'),
                                    backgroundColor:
                                        user.tier == UserTier.premium
                                            ? Colors.amber.shade100
                                            : null,
                                    onPressed: user.tier != UserTier.premium
                                        ? () => _changeTier(user, UserTier.premium)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.block,
                                      color: Colors.red),
                                  label: const Text('사용자 밴 (신규 등급으로 변경)',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () => _banUser(user),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
