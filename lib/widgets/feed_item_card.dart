import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null || _isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 열심 회원 여부 확인
    final isPremium = _author?.isPremiumUser ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
          // 작성자 정보
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isPremium
                      ? Colors.amber.shade700
                      : Theme.of(context).colorScheme.primary,
                  child: Text(
                    _author?.nickname[0].toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '@${_author?.nickname ?? 'Unknown'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPremium ? Colors.amber.shade900 : null,
                  ),
                ),
                if (isPremium) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '⭐',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${_author?.nickname} 추천템',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 썸네일 이미지
          if (widget.item.thumbnailUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: widget.item.thumbnailUrl,
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

          // 정보
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // 큐레이터 코멘트
                if (widget.item.curatorComment != null &&
                    widget.item.curatorComment!.isNotEmpty) ...[
                  Text(
                    widget.item.curatorComment!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],

                // 마감일
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: widget.item.isDeadlineSoon
                          ? Colors.red
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '마감: ${widget.item.deadlineString}',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.item.isDeadlineSoon
                            ? Colors.red
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 액션 버튼
                Row(
                  children: [
                    // 좋아요
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.grey,
                      ),
                      onPressed: () async {
                        await itemProvider.toggleLike(
                            currentUser.uid, widget.item.id);
                        setState(() {
                          _isLiked = !_isLiked;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.likeCount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 16),

                    // 북마크
                    IconButton(
                      icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: _isBookmarked ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () async {
                        await itemProvider.toggleBookmark(
                            currentUser.uid, widget.item.id);
                        setState(() {
                          _isBookmarked = !_isBookmarked;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.bookmarkCount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),

                    // 내 목록에 추가
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('내 목록에 추가'),
                      onPressed: () async {
                        await itemProvider.addToMyList(widget.item, currentUser.uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('내 목록에 추가되었습니다'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
