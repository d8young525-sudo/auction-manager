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
              // 필터 탭 (간소화: 전체 | 즐겨찾기 | 등록일순)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterTab('전체', ItemFilter.all, itemProvider),
                    const SizedBox(width: 8),
                    _buildFilterTab('즐겨찾기', ItemFilter.favorite, itemProvider),
                    const SizedBox(width: 8),
                    _buildFilterTab('등록일순', ItemFilter.createdDesc, itemProvider),
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

  Widget _buildFilterTab(String label, ItemFilter filter, ItemProvider itemProvider) {
    final isSelected = itemProvider.currentFilter == filter;
    return GestureDetector(
      onTap: () => itemProvider.setFilter(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
