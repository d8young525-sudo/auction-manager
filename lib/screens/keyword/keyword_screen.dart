import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/keyword_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_service.dart';

class KeywordScreen extends StatefulWidget {
  const KeywordScreen({super.key});

  @override
  State<KeywordScreen> createState() => _KeywordScreenState();
}

class _KeywordScreenState extends State<KeywordScreen> {
  final _uuid = const Uuid();
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 간단한 일본어-한국어 번역 맵 (상용 키워드 위주)
  final Map<String, String> _translationMap = {
    // 의류 관련
    'シャツ': '셔츠',
    'パンツ': '바지',
    'スカート': '스커트',
    'ジャケット': '재킷',
    'コート': '코트',
    'セーター': '스웨터',
    'ニット': '니트',
    'ワンピース': '원피스',
    'ドレス': '드레스',
    'スーツ': '슈트',
    'ジーンズ': '청바지',
    'Tシャツ': '티셔츠',
    
    // 신발/가방
    'スニーカー': '운동화',
    'ブーツ': '부츠',
    'サンダル': '샌들',
    'バッグ': '가방',
    'リュック': '백팩',
    '靴': '신발',
    
    // 액세서리
    '時計': '시계',
    '財布': '지갑',
    'ネックレス': '목걸이',
    'ピアス': '귀걸이',
    'イヤリング': '귀걸이',
    '指輪': '반지',
    'ブレスレット': '팔찌',
    
    // 브랜드/스타일
    'ヴィンテージ': '빈티지',
    'レトロ': '레트로',
    'モダン': '모던',
    'カジュアル': '캐주얼',
    'フォーマル': '정장',
    'スポーツ': '스포츠',
    
    // 색상
    '黒': '검정',
    '白': '흰색',
    '赤': '빨강',
    '青': '파랑',
    '緑': '초록',
    '黄': '노랑',
    'ピンク': '핑크',
    'グレー': '회색',
    'ベージュ': '베이지',
    'ブラウン': '갈색',
    
    // 상태/조건
    '新品': '새상품',
    '未使用': '미사용',
    '中古': '중고',
    '美品': '미품',
    'ダメージ': '손상',
    
    // 기타
    'セール': '세일',
    '限定': '한정',
    'コラボ': '콜라보',
    'レア': '희귀',
    '希少': '희소',
  };

  String _translateKeyword(String keyword) {
    // 정확한 매치 확인
    if (_translationMap.containsKey(keyword)) {
      return _translationMap[keyword]!;
    }
    
    // 부분 매치 확인 (포함 관계)
    for (final entry in _translationMap.entries) {
      if (keyword.contains(entry.key)) {
        return keyword.replaceAll(entry.key, entry.value);
      }
    }
    
    return keyword; // 번역 불가시 원문 그대로
  }

  Future<void> _addKeywords() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (context) => _AddKeywordsDialog(
        translationMap: _translationMap,
        translateFunction: _translateKeyword,
      ),
    );

    if (result != null && result.isNotEmpty) {
      // 키워드들을 Firestore에 추가
      for (final keywordData in result) {
        final keyword = KeywordModel(
          id: _uuid.v4(),
          userId: currentUser.uid,
          keyword: keywordData['original']!,
          translation: keywordData['translation'],
          notificationEnabled: true,
          createdAt: DateTime.now(),
        );

        await FirebaseService.addKeyword(keyword);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.length}개의 키워드가 추가되었습니다')),
        );
      }
    }
  }

  Future<void> _deleteKeyword(String keywordId) async {
    await FirebaseService.deleteKeyword(keywordId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('키워드가 삭제되었습니다')),
      );
    }
  }

  Future<void> _toggleNotification(KeywordModel keyword) async {
    final updated = keyword.copyWith(
      notificationEnabled: !keyword.notificationEnabled,
    );
    await FirebaseService.updateKeyword(updated);
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
      body: SafeArea(
        child: StreamBuilder<List<KeywordModel>>(
        stream: FirebaseService.getKeywordsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류: ${snapshot.error}'),
                ],
              ),
            );
          }

          final keywords = snapshot.data ?? [];
          
          // 검색 필터링 (한국어 번역 기준)
          final filteredKeywords = keywords.where((keyword) {
            if (_searchQuery.isEmpty) return true;
            final translation = keyword.translation ?? _translateKeyword(keyword.keyword);
            return translation.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (keywords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 키워드가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addKeywords,
                    icon: const Icon(Icons.add),
                    label: const Text('키워드 추가하기'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 검색 바
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '한국어로 키워드 검색...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // 검색 결과 카운트
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${filteredKeywords.length}개의 키워드 검색됨',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              
              Expanded(
                child: filteredKeywords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '검색 결과가 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 안내 카드
                          Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.blue.shade700),
                                      const SizedBox(width: 8),
                                      Text(
                                        '키워드 관리',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '옥션 검색에 사용할 키워드를 저장하고 관리하세요. 복사 버튼으로 쉽게 붙여넣을 수 있습니다.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 키워드 목록
                          ...filteredKeywords.map((keyword) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.label,
                        color: keyword.notificationEnabled
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      title: Row(
                        children: [
                          Text(
                            keyword.keyword,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (keyword.translation != null &&
                              keyword.translation != keyword.keyword) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(${keyword.translation})',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 복사 버튼
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.blue),
                            tooltip: '복사',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: keyword.keyword),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('\'${keyword.keyword}\' 복사되었습니다'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                          // 삭제 버튼
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '삭제',
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('키워드 삭제'),
                                  content: Text(
                                      '\'${keyword.keyword}\' 키워드를 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await _deleteKeyword(keyword.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )),
                        ],
                      ),
              ),
            ],
          );
        },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addKeywords,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// 키워드 추가 다이얼로그
class _AddKeywordsDialog extends StatefulWidget {
  final Map<String, String> translationMap;
  final String Function(String) translateFunction;

  const _AddKeywordsDialog({
    required this.translationMap,
    required this.translateFunction,
  });

  @override
  State<_AddKeywordsDialog> createState() => _AddKeywordsDialogState();
}

class _AddKeywordsDialogState extends State<_AddKeywordsDialog> {
  final _textController = TextEditingController();
  final List<Map<String, String>> _extractedKeywords = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _extractKeywords() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _extractedKeywords.clear();

      // 공백, 쉼표, 줄바꿈으로 분리
      final words = text
          .split(RegExp(r'[\s,、\n]+'))
          .where((word) => word.isNotEmpty)
          .toSet(); // 중복 제거

      for (final word in words) {
        _extractedKeywords.add({
          'original': word,
          'translation': widget.translateFunction(word),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('키워드 추가'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 텍스트
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '사용 팁',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 여러 키워드를 한번에 붙여넣으세요\n'
                    '• 자동으로 단어별로 분리됩니다\n'
                    '• 일본어는 자동 번역됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 텍스트 입력 필드
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: '키워드 입력 또는 붙여넣기',
                hintText: 'ヴィンテージ レトロ シャツ\n또는\n빈티지, 레트로, 셔츠',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  tooltip: '붙여넣기',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data != null && data.text != null) {
                      _textController.text = data.text!;
                    }
                  },
                ),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // 추출 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _extractKeywords,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('키워드 자동 추출'),
              ),
            ),
            const SizedBox(height: 16),

            // 추출된 키워드 미리보기
            if (_extractedKeywords.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '추출된 키워드 (${_extractedKeywords.length}개)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _extractedKeywords.length,
                  itemBuilder: (context, index) {
                    final keyword = _extractedKeywords[index];
                    final hasTranslation =
                        keyword['translation'] != keyword['original'];

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle, size: 20, color: Colors.green),
                      title: Row(
                        children: [
                          Text(
                            keyword['original']!,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (hasTranslation) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              keyword['translation']!,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _extractedKeywords.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _extractedKeywords.isEmpty
              ? null
              : () => Navigator.pop(context, _extractedKeywords),
          child: Text('추가 (${_extractedKeywords.length})'),
        ),
      ],
    );
  }
}
