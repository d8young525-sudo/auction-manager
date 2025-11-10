import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';
import '../providers/item_provider.dart';
import '../providers/user_provider.dart';
import '../services/firebase_service.dart';

class FeedItemCard extends StatefulWidget {
  final ItemModel item;

  const FeedItemCard({super.key, required this.item});

  @override
  State<FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<FeedItemCard> {
  UserModel? _author;
  bool _isLiked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) return;

    final author = await FirebaseService.getUserById(widget.item.userId);
    final isLiked = await FirebaseService.isLiked(currentUser.uid, widget.item.id);

    if (mounted) {
      setState(() {
        _author = author;
        _isLiked = isLiked;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _addToMyList() async {
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) return;

    try {
      await context.read<ItemProvider>().addItemToMyList(widget.item, currentUser.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내 목록에 추가되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추가 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null || _isLoading) {
      return const Card(
        margin: EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isPremium = _author?.isPremiumUser ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isPremium
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.amber.shade700,
                width: 2,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단: 이미지 + 정보 영역
          InkWell(
            onTap: () async {
              try {
                await _launchUrl(widget.item.url);
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
                    child: widget.item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.item.thumbnailUrl,
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
                        // 제목 + 좋아요
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // 좋아요 버튼 (컴팩트)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                icon: Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked ? Colors.red : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final currentUser = context.read<UserProvider>().currentUser;
                                  if (currentUser != null) {
                                    await context.read<ItemProvider>().toggleLike(
                                      currentUser.uid,
                                      widget.item.id,
                                    );
                                    setState(() {
                                      _isLiked = !_isLiked;
                                    });
                                  }
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
                              color: widget.item.isDeadlineSoon ? Colors.red : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${DateFormat('MM/dd HH:mm').format(widget.item.deadline)} (${widget.item.deadlineString})',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.item.isDeadlineSoon ? Colors.red : Colors.grey.shade700,
                                  fontWeight: widget.item.isDeadlineSoon ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.item.instantPurchase) ...[
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
                            if (widget.item.size != null && widget.item.size!.isNotEmpty) ...[
                              Text(
                                '사이즈: ${widget.item.size}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (widget.item.memo != null && widget.item.memo!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('•', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ),
                            ],
                            if (widget.item.memo != null && widget.item.memo!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  '메모: ${widget.item.memo}',
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
                        const SizedBox(height: 2),
                        
                        // 닉네임 배지 (맨 아래)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPremium ? Colors.amber.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: isPremium 
                                ? Border.all(color: Colors.amber.shade300, width: 0.5)
                                : null,
                          ),
                          child: Text(
                            '@${_author?.nickname ?? '?'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isPremium ? FontWeight.bold : FontWeight.w600,
                              color: isPremium ? Colors.amber.shade900 : Colors.grey.shade700,
                            ),
                          ),
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
          
          // 하단: 내 목록에 추가 버튼 (홈과 동일한 스타일)
          SizedBox(
            width: double.infinity,
            height: 38,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                '내 목록에 추가',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: _addToMyList,
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
