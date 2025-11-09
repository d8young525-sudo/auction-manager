import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/item_model.dart';
import '../../providers/item_provider.dart';

class ItemDetailScreen extends StatelessWidget {
  final ItemModel item;

  const ItemDetailScreen({super.key, required this.item});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('아이템 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('삭제 확인'),
                  content: const Text('이 아이템을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await itemProvider.deleteItem(item.id);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 이미지
            if (item.thumbnailUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: item.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 80),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // 마감일 정보
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.isDeadlineSoon
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.isDeadlineSoon
                            ? Colors.red.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: item.isDeadlineSoon
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '마감일',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: item.isDeadlineSoon
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('yyyy년 M월 d일 HH:mm').format(item.deadline),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item.deadlineString,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 상세 정보
                  _buildInfoRow(
                    context,
                    '사이즈',
                    item.size ?? '-',
                  ),
                  if (item.purchasePrice != null)
                    _buildInfoRow(
                      context,
                      '구매가격',
                      '¥${NumberFormat('#,###').format(item.purchasePrice)}',
                    ),
                  _buildInfoRow(
                    context,
                    '등록일',
                    DateFormat('yyyy.MM.dd HH:mm').format(item.createdAt),
                  ),
                  _buildInfoRow(
                    context,
                    '상태',
                    item.isPurchased ? '구매완료' : '입찰중',
                  ),
                  const SizedBox(height: 16),

                  // 메모
                  if (item.memo != null && item.memo!.isNotEmpty) ...[
                    const Text(
                      '메모',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.memo!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 액션 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(
                            item.isFavorite ? Icons.star : Icons.star_border,
                          ),
                          label: Text(item.isFavorite ? '즐겨찾기됨' : '즐겨찾기'),
                          onPressed: () {
                            itemProvider.toggleFavorite(item.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(
                            item.isPurchased
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                          ),
                          label: Text(item.isPurchased ? '구매됨' : '구매완료'),
                          onPressed: () {
                            itemProvider.togglePurchased(item.id);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 옥션 페이지 보기
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('옥션 페이지 보기'),
                      onPressed: () => _launchUrl(item.url),
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

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
