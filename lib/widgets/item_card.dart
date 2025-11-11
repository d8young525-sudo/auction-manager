import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/item_model.dart';
import '../providers/item_provider.dart';
import '../screens/add/add_item_screen.dart';

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

    return Slidable(
      key: Key(item.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (slidableContext) {
              // 수정 화면으로 이동 (아이템 정보 전달)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddItemScreen(editItem: item),
                ),
              );
            },
            backgroundColor: Colors.blue.shade400,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '수정',
          ),
          SlidableAction(
            onPressed: (slidableContext) async {
              // BuildContext를 미리 저장
              final scaffoldContext = context;
              
              final confirmed = await showDialog<bool>(
                context: scaffoldContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('아이템 삭제'),
                  content: const Text('정말 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('삭제', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                try {
                  // 삭제 실행
                  await itemProvider.deleteItem(item.id);
                  
                  // SnackBar 표시
                  if (scaffoldContext.mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      const SnackBar(
                        content: Text('아이템이 삭제되었습니다'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  // 에러 처리
                  if (scaffoldContext.mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: Text('삭제 실패: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            },
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '삭제',
          ),
        ],
      ),
      child: Card(
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 100x100 썸네일
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.thumbnailUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported, size: 36),
                              ),
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.shopping_bag, size: 36),
                            ),
                    ),
                    
                    // 세로 구분선
                    Container(
                      width: 1,
                      height: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.grey.shade300,
                    ),
                    
                    // 우측 정보 영역
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 제목 + 즐겨찾기
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  icon: Icon(
                                    item.isFavorite ? Icons.star : Icons.star_border,
                                    color: item.isFavorite ? Colors.amber : Colors.grey,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    itemProvider.toggleFavorite(item.id);
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          
                          // 마감일 + 즉시결제 배지
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 15,
                                color: item.isDeadlineSoon ? Colors.red : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MM/dd HH:mm').format(item.deadline)} (${item.deadlineString})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: item.isDeadlineSoon ? Colors.red : Colors.grey.shade700,
                                    fontWeight: item.isDeadlineSoon ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.instantPurchase) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.shade300, width: 0.5),
                                  ),
                                  child: Text(
                                    '즉시결제',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          
                          // 사이즈 / 메모
                          Row(
                            children: [
                              if (item.size != null && item.size!.isNotEmpty) ...[
                                Text(
                                  '사이즈: ${item.size}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (item.memo != null && item.memo!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text('•', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                  ),
                              ],
                              if (item.memo != null && item.memo!.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    '메모: ${item.memo}',
                                    style: TextStyle(
                                      fontSize: 13,
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
                  ],
                ),
              ),
            ),
            
            // 하단 구분선
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            
            // 하단: 구매완료 버튼
            SizedBox(
              width: double.infinity,
              height: 38,
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
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                ),
                child: Text(
                  item.isPurchased ? '구매완료 ✓' : '구매완료',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: item.isPurchased 
                        ? FontWeight.bold 
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
