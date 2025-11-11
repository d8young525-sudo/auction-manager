import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shipping_group_model.dart';
import '../../models/item_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_service.dart';
import 'package:uuid/uuid.dart';

class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  final _uuid = const Uuid();
  bool _showCompleted = false;
  String? _expandedGroupId;

  Future<void> _createGroup() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    // 기존 그룹 개수 확인
    final existingGroups = await FirebaseService.getShippingGroupsStream(currentUser.uid).first;
    final groupNumber = existingGroups.where((g) => !g.isCompleted).length + 1;

    final nameController = TextEditingController(text: '그룹$groupNumber');

    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 배송 그룹 만들기'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '그룹 이름',
            hintText: '예: 2024년 1월 구매',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, nameController.text);
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newGroup = ShippingGroupModel(
        id: _uuid.v4(),
        userId: currentUser.uid,
        name: result,
        itemIds: [],
        itemCount: 0,
        totalPrice: 0,
        createdAt: DateTime.now(),
      );

      await FirebaseService.addShippingGroup(newGroup);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\'$result\' 그룹이 생성되었습니다')),
        );
      }
    }
  }

  Future<void> _addItemsToGroup(String groupId, List<ItemModel> availableItems) async {
    final selected = <String>{};

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('그룹에 추가할 아이템 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: availableItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('추가할 수 있는 구매완료 아이템이 없습니다'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableItems.length,
                    itemBuilder: (context, index) {
                      final item = availableItems[index];
                      return CheckboxListTile(
                        title: Text(item.title),
                        subtitle: Text('¥${item.purchasePrice ?? 0}'),
                        value: selected.contains(item.id),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(item.id);
                            } else {
                              selected.remove(item.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text('추가 (${selected.length})'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // 선택된 아이템들에 groupId 할당
      for (final itemId in result) {
        await FirebaseService.itemsCollection.doc(itemId).update({
          'shippingGroupId': groupId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // 그룹 통계 업데이트
      await _updateGroupStats(groupId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.length}개 아이템을 그룹에 추가했습니다')),
        );
      }
    }
  }

  Future<void> _updateGroupStats(String groupId) async {
    final items = await FirebaseService.itemsCollection
        .where('shippingGroupId', isEqualTo: groupId)
        .get();

    int totalPrice = 0;
    for (final doc in items.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final price = data['purchasePrice'] as int?;
      if (price != null) {
        totalPrice += price;
      }
    }

    await FirebaseService.shippingGroupsCollection.doc(groupId).update({
      'itemCount': items.docs.length,
      'totalPrice': totalPrice,
      'itemIds': items.docs.map((doc) => doc.id).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _toggleGroupCompletion(String groupId, bool isCompleted) async {
    await FirebaseService.shippingGroupsCollection.doc(groupId).update({
      'completedAt': isCompleted ? DateTime.now().toIso8601String() : null,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _deleteGroup(String groupId) async {
    // 그룹에 속한 아이템들의 shippingGroupId 제거
    final items = await FirebaseService.itemsCollection
        .where('shippingGroupId', isEqualTo: groupId)
        .get();

    for (final doc in items.docs) {
      await FirebaseService.itemsCollection.doc(doc.id).update({
        'shippingGroupId': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    await FirebaseService.deleteShippingGroup(groupId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹이 삭제되었습니다')),
      );
    }
  }

  Future<void> _updateItemPrice(String itemId, int price) async {
    await FirebaseService.updateItemPrice(itemId, price);
    
    // 아이템이 속한 그룹의 통계 업데이트
    final itemDoc = await FirebaseService.itemsCollection.doc(itemId).get();
    final itemData = itemDoc.data() as Map<String, dynamic>?;
    final groupId = itemData?['shippingGroupId'] as String?;
    
    if (groupId != null) {
      await _updateGroupStats(groupId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매금액이 입력되었습니다')),
      );
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
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
            icon: Icon(
              _showCompleted ? Icons.inventory_2 : Icons.archive,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              _showCompleted ? '진행중 목록' : '배송완료 목록',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ShippingGroupModel>>(
        stream: FirebaseService.getShippingGroupsStream(currentUser.uid),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allGroups = groupSnapshot.data ?? [];
          final activeGroups = allGroups.where((g) => !g.isCompleted).toList();
          final completedGroups = allGroups.where((g) => g.isCompleted).toList();
          final displayGroups = _showCompleted ? completedGroups : activeGroups;

          return StreamBuilder<List<ItemModel>>(
            stream: FirebaseService.getMyItemsStream(currentUser.uid),
            builder: (context, itemSnapshot) {
              if (itemSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allItems = itemSnapshot.data ?? [];
              final ungroupedItems = allItems
                  .where((item) =>
                      item.isPurchased &&
                      (item.shippingGroupId == null ||
                          item.shippingGroupId!.isEmpty))
                  .toList();

              return displayGroups.isEmpty && ungroupedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showCompleted
                        ? '배송완료된 그룹이 없습니다'
                        : '배송 그룹을 만들어보세요\n우측 하단 + 버튼을 눌러주세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 그룹 목록
                ...displayGroups.map((group) =>
                    _buildGroupCard(group, allItems, ungroupedItems)),

                if (displayGroups.isNotEmpty && ungroupedItems.isNotEmpty)
                  const Divider(height: 32),

                // 그룹 미지정 아이템
                if (ungroupedItems.isNotEmpty && !_showCompleted) ...[
                  Text(
                    '그룹 미지정 아이템',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...ungroupedItems.map((item) => _buildUngroupedItemCard(item)),
                ],
              ],
            );
            },
          );
        },
      ),
      floatingActionButton: _showCompleted
          ? null
          : FloatingActionButton(
              onPressed: _createGroup,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildGroupCard(
    ShippingGroupModel group,
    List<ItemModel> allItems,
    List<ItemModel> ungroupedItems,
  ) {
    final groupItems =
        allItems.where((item) => item.shippingGroupId == group.id).toList();
    final isExpanded = _expandedGroupId == group.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              group.isCompleted ? Icons.check_circle : Icons.local_shipping,
              color: group.isCompleted ? Colors.green : Colors.blue,
            ),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${group.itemCount}개 아이템 • ¥${group.totalPrice}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _expandedGroupId = isExpanded ? null : group.id;
                });
              },
            ),
            onTap: () {
              setState(() {
                _expandedGroupId = isExpanded ? null : group.id;
              });
            },
          ),

          // 확장된 내용
          if (isExpanded) ...[
            const Divider(height: 1),
            
            // 그룹 아이템 목록
            if (groupItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '아이템이 없습니다',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...groupItems.map((item) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              item.thumbnailUrl,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported, size: 40),
                                );
                              },
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.shopping_bag, size: 40),
                            ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      '¥${item.purchasePrice ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  )),

            const Divider(height: 1),

            // 액션 버튼들
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!group.isCompleted)
                    TextButton.icon(
                      onPressed: () =>
                          _addItemsToGroup(group.id, ungroupedItems),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('아이템 추가'),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('그룹 삭제'),
                          content: Text(
                            '\'${group.name}\' 그룹을 삭제하시겠습니까?\n그룹에 속한 아이템은 그룹 미지정 상태로 변경됩니다.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await _deleteGroup(group.id);
                      }
                    },
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: const Text(
                      '삭제',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _toggleGroupCompletion(group.id, !group.isCompleted),
                    icon: Icon(
                      group.isCompleted ? Icons.undo : Icons.check,
                      size: 18,
                      color: group.isCompleted ? Colors.orange : Colors.green,
                    ),
                    label: Text(
                      group.isCompleted ? '진행중으로' : '배송완료',
                      style: TextStyle(
                        color: group.isCompleted ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUngroupedItemCard(ItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 썸네일 추가
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          item.thumbnailUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 30),
                            );
                          },
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.shopping_bag, size: 30),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '¥${item.purchasePrice ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final controller = TextEditingController(
                      text: item.purchasePrice?.toString() ?? '',
                    );

                    final result = await showDialog<int>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('구매금액 입력'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: '금액 (¥)',
                            hintText: '1000',
                            prefixText: '¥',
                          ),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () {
                              final price = int.tryParse(controller.text);
                              if (price != null) {
                                Navigator.pop(context, price);
                              }
                            },
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    );

                    if (result != null) {
                      await _updateItemPrice(item.id, result);
                    }
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('구매금액 입력'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
