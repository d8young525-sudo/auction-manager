import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/item_provider.dart';
import '../auth/login_screen.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final itemProvider = context.watch<ItemProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final myItems = itemProvider.getMyItems(currentUser.uid);
    final publicItems = myItems.where((item) => item.isPublic).toList();
    final shippingGroups = itemProvider.getShippingGroups(currentUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 설정 화면
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 프로필 정보
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                currentUser.nickname[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentUser.nickname,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (currentUser.bio != null) ...[
              const SizedBox(height: 8),
              Text(
                currentUser.bio!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),

            // 통계
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context,
                  '전체 아이템',
                  '${myItems.length}',
                  Icons.inventory_2,
                ),
                _buildStatItem(
                  context,
                  '공개 아이템',
                  '${publicItems.length}',
                  Icons.public,
                ),
                _buildStatItem(
                  context,
                  '합배송 그룹',
                  '${shippingGroups.length}',
                  Icons.local_shipping,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 합배송 관리
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: const Text('합배송 그룹 관리'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 합배송 그룹 관리 화면
                      _showShippingGroupsDialog(
                          context, shippingGroups, itemProvider);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 관리자 메뉴 (관리자만 표시)
            if (currentUser.isAdmin) ...[
              Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: Colors.amber.shade800),
                  title: Text(
                    '관리자 패널',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('사용자 관리 및 등급 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 로그아웃
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  '로그아웃',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('로그아웃'),
                      content: const Text('로그아웃 하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('로그아웃'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await userProvider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showShippingGroupsDialog(
    BuildContext context,
    List<dynamic> groups,
    ItemProvider itemProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('합배송 그룹'),
        content: SizedBox(
          width: double.maxFinite,
          child: groups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('합배송 그룹이 없습니다'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.name),
                      subtitle:
                          Text('${group.itemCount}개 아이템 / ¥${group.totalPrice}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await itemProvider.deleteShippingGroup(group.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
