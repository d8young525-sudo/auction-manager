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
          
          // 필터 적용 (구매완료 아이템도 포함)
          List<ItemModel> filteredItems = allItems;
          switch (itemProvider.currentFilter) {
            case ItemFilter.favorite:
              filteredItems = allItems.where((item) => item.isFavorite).toList();
              break;
            case ItemFilter.createdDesc:
              filteredItems = allItems;
              // 등록일순 정렬
              filteredItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              break;
            case ItemFilter.all:
              // 기본: 마감일순 정렬
              filteredItems.sort((a, b) => a.deadline.compareTo(b.deadline));
              break;
            default:
              break;
          }
          
          // all 필터인 경우에만 마감일순 정렬 (기본)
          if (itemProvider.currentFilter == ItemFilter.all) {
            filteredItems.sort((a, b) => a.deadline.compareTo(b.deadline));
          }

          final urgentItems = filteredItems
              .where((item) => item.isDeadlineSoon)
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

              // 필터 탭 (간소화: 전체 | 즐겨찾기 | 등록일순)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: itemProvider.currentFilter == ItemFilter.all,
                      onSelected: (_) => itemProvider.setFilter(ItemFilter.all),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('즐겨찾기'),
                      selected: itemProvider.currentFilter == ItemFilter.favorite,
                      onSelected: (_) => itemProvider.setFilter(ItemFilter.favorite),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('등록일순'),
                      selected: itemProvider.currentFilter == ItemFilter.createdDesc,
                      onSelected: (_) => itemProvider.setFilter(ItemFilter.createdDesc),
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
