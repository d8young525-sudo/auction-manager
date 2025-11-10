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
  bool _isBookmarked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) return;

    // 작성자 정보 로드
    final author = await FirebaseService.getUserById(widget.item.userId);
    
    // 좋아요/북마크 상태 로드
    final isLiked = await FirebaseService.isLiked(currentUser.uid, widget.item.id);
    final isBookmarked = await FirebaseService.isBookmarked(currentUser.uid, widget.item.id);

    if (mounted) {
      setState(() {
        _author = author;
        _isLiked = isLiked;
        _isBookmarked = isBookmarked;
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

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
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

    // 열심 회원 여부 확인
    final isPremium = _author?.isPremiumUser ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // 열심 회원은 카드 테두리 강조
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 좌측: 북마크 버튼
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: IconButton(
                      icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: _isBookmarked ? Colors.blue : Colors.grey,
                        size: 36,
                      ),
                      onPressed: () async {
                        final currentUser = context.read<UserProvider>().currentUser;
                        if (currentUser != null) {
                          await context.read<ItemProvider>().toggleBookmark(
                            currentUser.uid,
                            widget.item.id,
                          );
                          setState(() {
                            _isBookmarked = !_isBookmarked;
                          });
                        }
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.item.thumbnailUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 3),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 40),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.shopping_bag, size: 40),
                          ),
                  ),
                  const SizedBox(width: 14),

                  // 중앙: 메인 콘텐츠
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 제목 + 작성자
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '@${_author?.nickname ?? '?'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isPremium 
                                    ? Colors.amber.shade900 
                                    : Colors.grey.shade600,
                                fontWeight: isPremium 
                                    ? FontWeight.bold 
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // 마감일 + 즉시결제 배지
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 15,
                              color: widget.item.isDeadlineSoon ? Colors.red : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${DateFormat('MM/dd HH:mm').format(widget.item.deadline)} (${widget.item.deadlineString})',
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.item.isDeadlineSoon ? Colors.red : Colors.grey.shade700,
                                fontWeight: widget.item.isDeadlineSoon ? FontWeight.bold : FontWeight.normal,
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
                        const SizedBox(height: 5),
                        
                        // 사이즈 + 메모 한 줄에 배치
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


                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 우측: 좋아요 버튼
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.grey,
                        size: 36,
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
            ),
          ),
        ],
      ),
    );
  }
}
