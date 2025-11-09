import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import '../screens/home/item_detail_screen.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;

  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(item: item),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.shopping_bag),
                      ),
              ),
              const SizedBox(width: 12),

              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // 마감일
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: item.isDeadlineSoon
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '마감: ${DateFormat('yy.MM.dd HH:mm').format(item.deadline)} (${item.deadlineString})',
                          style: TextStyle(
                            fontSize: 12,
                            color: item.isDeadlineSoon
                                ? Colors.red
                                : Colors.grey.shade700,
                            fontWeight: item.isDeadlineSoon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 사이즈 / 가격
                    Row(
                      children: [
                        if (item.size != null) ...[
                          Text(
                            '사이즈: ${item.size}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (item.purchasePrice != null)
                            const Text(' / ',
                                style: TextStyle(color: Colors.grey)),
                        ],
                        if (item.purchasePrice != null)
                          Text(
                            '¥${NumberFormat('#,###').format(item.purchasePrice)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),

                    // 합배송 그룹
                    if (item.shippingGroupId != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '합배송',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 액션 버튼
              Column(
                children: [
                  // 즐겨찾기
                  IconButton(
                    icon: Icon(
                      item.isFavorite ? Icons.star : Icons.star_border,
                      color: item.isFavorite ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () {
                      itemProvider.toggleFavorite(item.id);
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),

                  // 구매완료
                  IconButton(
                    icon: Icon(
                      item.isPurchased
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: item.isPurchased ? Colors.green : Colors.grey,
                    ),
                    onPressed: () {
                      itemProvider.togglePurchased(item.id);
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
