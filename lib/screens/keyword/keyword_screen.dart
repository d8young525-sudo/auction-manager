import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/keyword_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_service.dart';

class KeywordScreen extends StatefulWidget {
  const KeywordScreen({super.key});

  @override
  State<KeywordScreen> createState() => _KeywordScreenState();
}

class _KeywordScreenState extends State<KeywordScreen> {
  final _uuid = const Uuid();

  Future<void> _addKeyword() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('키워드 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '옥션에서 찾고 있는 상품의 키워드를 입력하세요.\n새로운 공개 아이템이 올라오면 알림을 받을 수 있습니다.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '키워드',
                hintText: '예: 나이키, 빈티지, 청바지',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newKeyword = KeywordModel(
        id: _uuid.v4(),
        userId: currentUser.uid,
        keyword: result,
        createdAt: DateTime.now(),
      );

      await FirebaseService.keywordsCollection.doc(newKeyword.id).set(newKeyword.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$result" 키워드가 추가되었습니다')),
        );
      }
    }
  }

  Future<void> _toggleNotification(KeywordModel keyword) async {
    await FirebaseService.keywordsCollection.doc(keyword.id).update({
      'notificationEnabled': !keyword.notificationEnabled,
    });
  }

  Future<void> _deleteKeyword(KeywordModel keyword) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('키워드 삭제'),
        content: Text('"${keyword.keyword}" 키워드를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.keywordsCollection.doc(keyword.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${keyword.keyword}" 키워드가 삭제되었습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('키워드 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '키워드 추가',
            onPressed: _addKeyword,
          ),
        ],
      ),
      body: StreamBuilder<List<KeywordModel>>(
        stream: FirebaseService.getKeywordsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }

          final keywords = snapshot.data ?? [];

          if (keywords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 키워드가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우측 상단 + 버튼으로 키워드를 추가해보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addKeyword,
                    icon: const Icon(Icons.add),
                    label: const Text('키워드 추가'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 안내 카드
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '키워드를 등록하면 발견 탭에 관련 아이템이 올라올 때 알림을 받을 수 있습니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 키워드 리스트
              ...keywords.map((keyword) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: keyword.notificationEnabled
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.label,
                          color: keyword.notificationEnabled
                              ? Colors.blue.shade700
                              : Colors.grey.shade500,
                        ),
                      ),
                      title: Text(
                        keyword.keyword,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        keyword.notificationEnabled ? '알림 켜짐' : '알림 꺼짐',
                        style: TextStyle(
                          fontSize: 13,
                          color: keyword.notificationEnabled
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              keyword.notificationEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              color: keyword.notificationEnabled
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade500,
                            ),
                            tooltip: keyword.notificationEnabled
                                ? '알림 끄기'
                                : '알림 켜기',
                            onPressed: () => _toggleNotification(keyword),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '삭제',
                            onPressed: () => _deleteKeyword(keyword),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
