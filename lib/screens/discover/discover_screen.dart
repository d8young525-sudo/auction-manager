import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/item_provider.dart';
import '../../widgets/feed_item_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _sortBy = 'latest'; // 'latest' or 'popular'

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final items = itemProvider.getPublicItems(sortBy: _sortBy);

    return Scaffold(
      appBar: AppBar(
        title: const Text('발견'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'latest',
                child: Text('최신순'),
              ),
              const PopupMenuItem(
                value: 'popular',
                child: Text('인기순'),
              ),
            ],
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '공개된 아이템이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아이템을 공개로 설정하여 다른 사용자와 공유해보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return FeedItemCard(item: items[index]);
              },
            ),
    );
  }
}
