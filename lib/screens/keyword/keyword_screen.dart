import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/keyword_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/translation_service.dart';

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



  Future<void> _addKeywords() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (context) => const _AddKeywordsDialog(),
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
            final translation = keyword.translation ?? keyword.keyword;
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
                          // 편집 버튼 (번역본만 수정)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.green),
                            tooltip: '번역 수정',
                            onPressed: () async {
                              final controller = TextEditingController(
                                text: keyword.translation ?? keyword.keyword,
                              );
                              
                              final newTranslation = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('번역 수정'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '원문: ${keyword.keyword}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                          labelText: '한국어 번역',
                                          hintText: '번역을 입력하세요',
                                          border: OutlineInputBorder(),
                                        ),
                                        autofocus: true,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        if (controller.text.isNotEmpty) {
                                          Navigator.pop(context, controller.text);
                                        }
                                      },
                                      child: const Text('저장'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (newTranslation != null && newTranslation.isNotEmpty) {
                                final updated = keyword.copyWith(
                                  translation: newTranslation,
                                );
                                await FirebaseService.updateKeyword(updated);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('번역이 수정되었습니다'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
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
  const _AddKeywordsDialog();

  @override
  State<_AddKeywordsDialog> createState() => _AddKeywordsDialogState();
}

class _AddKeywordsDialogState extends State<_AddKeywordsDialog> {
  final _textController = TextEditingController();
  final List<Map<String, String>> _extractedKeywords = [];
  bool _isTranslating = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _extractKeywords() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _extractedKeywords.clear();
    });

    try {
      // 공백, 쉼표, 줄바꿈으로 분리
      final words = text
          .split(RegExp(r'[\s,、\n]+'))
          .where((word) => word.isNotEmpty)
          .toSet() // 중복 제거
          .toList();

      // Google Translate API로 일괄 번역
      final translated = await TranslationService.translateMultiple(words);

      setState(() {
        _extractedKeywords.addAll(translated);
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('번역 중 오류가 발생했습니다: $e')),
        );
      }
    }
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
                    '• Google AI 번역으로 모든 일본어 번역 가능\n'
                    '• 번역된 결과는 자동 저장됩니다',
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
                onPressed: _isTranslating ? null : _extractKeywords,
                icon: _isTranslating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isTranslating ? '번역 중...' : '키워드 자동 추출 (AI 번역)'),
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
