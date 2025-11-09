import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  bool _showArchived = false;

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
        createdAt: DateTime.now(),
      );

      await FirebaseService.addShippingGroup(newGroup);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$result 그룹이 생성되었습니다')),
        );
      }
    }
  }

  Future<void> _addItemsToGroup(ShippingGroupModel group, List<ItemModel> availableItems) async {
    final selected = <String>{};

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${group.name}에 추가할 아이템 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: availableItems.isEmpty
                ? const Center(
                    child: Text('추가 가능한 구매완료 아이템이 없습니다'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableItems.length,
                    itemBuilder: (context, index) {
                      final item = availableItems[index];
                      return CheckboxListTile(
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.purchasePrice != null
                            ? Text('¥${NumberFormat('#,###').format(item.purchasePrice)}')
                            : null,
                        value: selected.contains(item.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
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
              child: Text('추가 (${selected.length}개)'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // 선택된 아이템들의 shippingGroupId 업데이트
      for (final itemId in result) {
        await FirebaseService.itemsCollection.doc(itemId).update({
          'shippingGroupId': group.id,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // 그룹 정보 업데이트 (아이템 개수와 총액 계산)
      await _updateGroupStats(group.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.length}개 아이템이 추가되었습니다')),
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
    });
  }

  Future<void> _toggleArchive(ShippingGroupModel group) async {
    final newCompletedAt = group.isCompleted ? null : DateTime.now();

    await FirebaseService.shippingGroupsCollection.doc(group.id).update({
      'completedAt': newCompletedAt?.toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            group.isCompleted ? '${group.name}을 활성화했습니다' : '${group.name}을 아카이브했습니다',
          ),
        ),
      );
    }
  }

  Future<void> _deleteGroup(ShippingGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text('${group.name}을 삭제하시겠습니까?\n(아이템은 삭제되지 않습니다)'),
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
      // 그룹 내 아이템들의 shippingGroupId 제거
      final items = await FirebaseService.itemsCollection
          .where('shippingGroupId', isEqualTo: group.id)
          .get();

      for (final doc in items.docs) {
        await doc.reference.update({
          'shippingGroupId': null,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // 그룹 삭제
      await FirebaseService.deleteShippingGroup(group.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${group.name}이 삭제되었습니다')),
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
        title: const Text('배송 그룹 관리'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: _showArchived ? '활성 그룹 보기' : '아카이브 보기',
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 그룹 만들기',
            onPressed: _createGroup,
          ),
        ],
      ),
      body: StreamBuilder<List<ShippingGroupModel>>(
        stream: FirebaseService.getShippingGroupsStream(currentUser.uid),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (groupSnapshot.hasError) {
            return Center(child: Text('오류: ${groupSnapshot.error}'));
          }

          final allGroups = groupSnapshot.data ?? [];
          final groups = allGroups
              .where((g) => _showArchived ? g.isCompleted : !g.isCompleted)
              .toList();

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showArchived ? Icons.archive_outlined : Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showArchived ? '아카이브된 그룹이 없습니다' : '배송 그룹이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showArchived
                        ? '배송 완료된 그룹이 여기에 표시됩니다'
                        : '우측 상단 + 버튼으로 그룹을 만들어보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<List<ItemModel>>(
            stream: FirebaseService.getMyItemsStream(currentUser.uid),
            builder: (context, itemSnapshot) {
              final allItems = itemSnapshot.data ?? [];
              final availableItems = allItems
                  .where((item) => item.isPurchased && item.shippingGroupId == null)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 그룹 리스트
                  ...groups.map((group) {
                    final groupItems = allItems
                        .where((item) => item.shippingGroupId == group.id)
                        .toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 그룹 헤더
                          ListTile(
                            leading: Icon(
                              group.isCompleted ? Icons.archive : Icons.inventory_2,
                              color: group.isCompleted ? Colors.grey : Colors.blue,
                            ),
                            title: Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${group.itemCount}개 아이템 · ¥${NumberFormat('#,###').format(group.totalPrice)}',
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  onTap: () => Future.delayed(
                                    Duration.zero,
                                    () => _toggleArchive(group),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        group.isCompleted ? Icons.unarchive : Icons.archive,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(group.isCompleted ? '활성화' : '배송 완료'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  onTap: () => Future.delayed(
                                    Duration.zero,
                                    () => _deleteGroup(group),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('삭제', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 아이템 리스트
                          if (groupItems.isNotEmpty)
                            ...groupItems.map((item) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  title: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  trailing: item.purchasePrice != null
                                      ? Text(
                                          '¥${NumberFormat('#,###').format(item.purchasePrice)}',
                                          style: const TextStyle(fontSize: 13),
                                        )
                                      : null,
                                )),

                          // 아이템 추가 버튼
                          if (!group.isCompleted)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('아이템 추가'),
                                onPressed: () => _addItemsToGroup(group, availableItems),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // 그룹화 안 된 아이템
                  if (!_showArchived && availableItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '그룹화 안 된 구매완료 아이템 (${availableItems.length}개)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...availableItems.map((item) => Card(
                          child: ListTile(
                            dense: true,
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: item.purchasePrice != null
                                ? Text(
                                    '¥${NumberFormat('#,###').format(item.purchasePrice)}',
                                    style: const TextStyle(fontSize: 13),
                                  )
                                : null,
                          ),
                        )),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
