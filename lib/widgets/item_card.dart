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
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 좌측: 즐겨찾기 버튼
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: Icon(
                        item.isFavorite ? Icons.star : Icons.star_border,
                        color: item.isFavorite ? Colors.amber : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () {
                        itemProvider.toggleFavorite(item.id);
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.thumbnailUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 20),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.shopping_bag, size: 20),
                          ),
                  ),
                  const SizedBox(width: 10),
                  
                  // 중앙: 메인 콘텐츠
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 제목
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        // 마감일 + 즉시결제 배지
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: item.isDeadlineSoon ? Colors.red : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${DateFormat('MM/dd HH:mm').format(item.deadline)} (${item.deadlineString})',
                              style: TextStyle(
                                fontSize: 11,
                                color: item.isDeadlineSoon ? Colors.red : Colors.grey.shade700,
                                fontWeight: item.isDeadlineSoon ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (item.instantPurchase) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: Colors.orange.shade300, width: 0.5),
                                ),
                                child: Text(
                                  '즉시결제',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        
                        // 사이즈 + 메모 한 줄에 배치
                        Row(
                          children: [
                            if (item.size != null && item.size!.isNotEmpty) ...[
                              Text(
                                '사이즈: ${item.size}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (item.memo != null && item.memo!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('•', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                ),
                            ],
                            if (item.memo != null && item.memo!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  '메모: ${item.memo}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 우측: 구매완료 버튼
                  SizedBox(
                    width: 75,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () {
                        itemProvider.togglePurchased(item.id);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: item.isPurchased 
                            ? Colors.green.shade50 
                            : Colors.transparent,
                        foregroundColor: item.isPurchased 
                            ? Colors.green.shade700 
                            : Colors.grey.shade700,
                        side: BorderSide(
                          color: item.isPurchased 
                              ? Colors.green.shade700 
                              : Colors.grey.shade400,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      child: Text(
                        item.isPurchased ? '구매완료✓' : '구매완료',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: item.isPurchased 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 하단 버튼 2개: [수정 | 삭제]
          if (showEditButtons)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
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
