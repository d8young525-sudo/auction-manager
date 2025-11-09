import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/item_provider.dart';
import '../../models/item_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/item_card.dart';
import '../add/add_item_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 현재 사용자 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadCurrentUser();
    });
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 구매 목록'),
        actions: [
          // 정렬 메뉴
          PopupMenuButton<ItemSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) {
              itemProvider.setSort(sort);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ItemSort.deadlineAsc,
                child: Text('마감일 임박순'),
              ),
              const PopupMenuItem(
                value: ItemSort.createdDesc,
                child: Text('등록일순'),
              ),
              const PopupMenuItem(
                value: ItemSort.priceAsc,
                child: Text('가격순'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<ItemModel>>(
        stream: FirebaseService.getMyItemsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다: ${snapshot.error}'),
            );
          }

          final allItems = snapshot.data ?? [];
          
          // 필터 적용
          List<ItemModel> filteredItems = allItems;
          switch (itemProvider.currentFilter) {
            case ItemFilter.favorite:
              filteredItems = allItems.where((item) => item.isFavorite).toList();
              break;
            case ItemFilter.purchased:
              filteredItems = allItems.where((item) => item.isPurchased).toList();
              break;
            case ItemFilter.shipping:
              filteredItems = allItems.where((item) => item.shippingGroupId != null).toList();
              break;
            case ItemFilter.all:
              break;
          }

          // 정렬 적용
          switch (itemProvider.currentSort) {
            case ItemSort.deadlineAsc:
              filteredItems.sort((a, b) => a.deadline.compareTo(b.deadline));
              break;
            case ItemSort.createdDesc:
              filteredItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              break;
            case ItemSort.priceAsc:
              filteredItems.sort((a, b) {
                final priceA = a.purchasePrice ?? 0;
                final priceB = b.purchasePrice ?? 0;
                return priceA.compareTo(priceB);
              });
              break;
          }

          final urgentItems = filteredItems
              .where((item) => item.isDeadlineSoon && !item.isPurchased)
              .toList();

          return Column(
            children: [
              // 마감 임박 배너
              if (urgentItems.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alarm, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '⏰ ${urgentItems.length}개의 아이템이 24시간 내에 마감됩니다!',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 필터 칩
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('전체'),
                      selected: itemProvider.currentFilter == ItemFilter.all,
                      onSelected: (_) => itemProvider.setFilter(ItemFilter.all),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('즐겨찾기'),
                      selected: itemProvider.currentFilter == ItemFilter.favorite,
                      onSelected: (_) =>
                          itemProvider.setFilter(ItemFilter.favorite),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('구매완료'),
                      selected: itemProvider.currentFilter == ItemFilter.purchased,
                      onSelected: (_) =>
                          itemProvider.setFilter(ItemFilter.purchased),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('합배송'),
                      selected: itemProvider.currentFilter == ItemFilter.shipping,
                      onSelected: (_) =>
                          itemProvider.setFilter(ItemFilter.shipping),
                    ),
                  ],
                ),
              ),

              // 아이템 리스트
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '저장된 아이템이 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '우측 하단 + 버튼으로 아이템을 추가해보세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          return ItemCard(item: filteredItems[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      // FAB 추가 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddItemScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
