import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import '../screens/home/item_detail_screen.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final bool showEditButtons;

  const ItemCard({
    super.key,
    required this.item,
    this.showEditButtons = true,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _showPriceDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: item.purchasePrice?.toString() ?? '',
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구매가격 입력'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '가격 (엔)',
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
            onPressed: () async {
              final price = int.tryParse(controller.text.replaceAll(',', ''));
              if (price != null) {
                await context.read<ItemProvider>().updateItemPrice(item.id, price);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('가격이 저장되었습니다')),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              try {
                await _launchUrl(item.url);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('링크를 열 수 없습니다: $e')),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 즐겨찾기 (좌측)
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
                  const SizedBox(width: 8),

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
                            Flexible(
                              child: Text(
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 사이즈
                        if (item.size != null && item.size!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '사이즈: ${item.size}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),

                        // 메모
                        if (item.memo != null && item.memo!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '메모: ${item.memo}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // 코멘트
                        if (item.curatorComment != null && item.curatorComment!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '💬 ${item.curatorComment}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                ],
              ),
            ),
          ),
          
          // 하단 버튼 (홈탭에서만 표시)
          if (showEditButtons)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  // 구매완료 버튼
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        itemProvider.togglePurchased(item.id);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: item.isPurchased 
                            ? Colors.green.shade50 
                            : Colors.transparent,
                        foregroundColor: item.isPurchased 
                            ? Colors.green.shade700 
                            : Colors.grey.shade700,
                      ),
                      child: Text(
                        '구매완료',
                        style: TextStyle(
                          fontWeight: item.isPurchased 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                  // 구매금액입력 버튼
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.attach_money, size: 16),
                      label: Text(
                        item.purchasePrice != null 
                            ? '¥${NumberFormat('#,###').format(item.purchasePrice)}'
                            : '구매금액',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () => _showPriceDialog(context),
                      style: TextButton.styleFrom(
                        foregroundColor: item.purchasePrice != null 
                            ? Colors.blue.shade700 
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                  // 수정하기 버튼
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('수정', style: TextStyle(fontSize: 13)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(item: item),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                  // 삭제하기 버튼
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('삭제', style: TextStyle(color: Colors.red, fontSize: 13)),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('아이템 삭제'),
                            content: const Text('정말 삭제하시겠습니까?'),
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
                        
                        if (confirmed == true && context.mounted) {
                          await itemProvider.deleteItem(item.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('아이템이 삭제되었습니다')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
