import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/item_provider.dart';
import '../auth/login_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
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
            const SizedBox(height: 24),

            // 월별 지출 통계
            _buildMonthlySpendingCard(context, myItems),
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

  // 월별 지출 통계 카드
  Widget _buildMonthlySpendingCard(BuildContext context, List<dynamic> items) {
    // 구매 완료된 아이템만 필터링
    final purchasedItems = items.where((item) => item.isPurchased).toList();

    // 현재 월 계산
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    final twoMonthsAgo = DateTime(now.year, now.month - 2);

    // 월별 지출 계산
    int currentMonthSpending = 0;
    int lastMonthSpending = 0;
    int twoMonthsAgoSpending = 0;

    for (final item in purchasedItems) {
      final price = (item.purchasePrice ?? 0) as int;
      final createdDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
      );

      if (createdDate == currentMonth) {
        currentMonthSpending += price;
      } else if (createdDate == lastMonth) {
        lastMonthSpending += price;
      } else if (createdDate == twoMonthsAgo) {
        twoMonthsAgoSpending += price;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '월별 지출 통계',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMonthlySpendingRow(
              context,
              '${now.month}월 (이번 달)',
              currentMonthSpending,
              isCurrentMonth: true,
            ),
            const Divider(height: 24),
            _buildMonthlySpendingRow(
              context,
              '${lastMonth.month}월',
              lastMonthSpending,
            ),
            const Divider(height: 24),
            _buildMonthlySpendingRow(
              context,
              '${twoMonthsAgo.month}월',
              twoMonthsAgoSpending,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '3개월 총 지출',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  Text(
                    '¥${currentMonthSpending + lastMonthSpending + twoMonthsAgoSpending}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySpendingRow(
    BuildContext context,
    String month,
    int amount, {
    bool isCurrentMonth = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          month,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
            color: isCurrentMonth ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        Text(
          '¥$amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isCurrentMonth ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}
