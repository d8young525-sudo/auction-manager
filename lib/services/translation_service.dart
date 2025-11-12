import 'package:translator/translator.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  
  // 번역 캐시 (동일한 단어 재번역 방지)
  static final Map<String, String> _cache = {};
  
  // 자주 사용하는 키워드 로컬 사전 (빠른 응답용)
  static final Map<String, String> _localDictionary = {
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
    'デニム': '데님',
    'レザー': '가죽',
    
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
    '未開封': '미개봉',
    '新作': '신상',
    
    // 기타
    'セール': '세일',
    '限定': '한정',
    'コラボ': '콜라보',
    'レア': '희귀',
    '希少': '희소',
  };

  /// 일본어 → 한국어 번역 (하이브리드 방식)
  /// 1. 로컬 사전 확인 (즉시 응답)
  /// 2. 캐시 확인 (즉시 응답)
  /// 3. Google Translate API 호출 (1-2초)
  static Future<String> translateJaToKo(String text) async {
    if (text.isEmpty) return text;
    
    // 1. 로컬 사전에서 찾기 (가장 빠름)
    if (_localDictionary.containsKey(text)) {
      if (kDebugMode) {
        debugPrint('✅ Translation from local dictionary: $text → ${_localDictionary[text]}');
      }
      return _localDictionary[text]!;
    }
    
    // 2. 부분 매치 확인 (복합 키워드용)
    for (final entry in _localDictionary.entries) {
      if (text.contains(entry.key)) {
        final translated = text.replaceAll(entry.key, entry.value);
        if (kDebugMode) {
          debugPrint('✅ Translation from partial match: $text → $translated');
        }
        return translated;
      }
    }
    
    // 3. 캐시에서 찾기
    if (_cache.containsKey(text)) {
      if (kDebugMode) {
        debugPrint('✅ Translation from cache: $text → ${_cache[text]}');
      }
      return _cache[text]!;
    }
    
    // 4. Google Translate API 호출
    try {
      if (kDebugMode) {
        debugPrint('🌐 Calling Google Translate API for: $text');
      }
      
      final translation = await _translator.translate(
        text,
        from: 'ja',  // 일본어
        to: 'ko',    // 한국어
      );
      
      final result = translation.text;
      
      // 캐시에 저장 (다음번엔 API 안 씀)
      _cache[text] = result;
      
      if (kDebugMode) {
        debugPrint('✅ Google Translate result: $text → $result');
      }
      
      return result;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Translation failed: $e');
      }
      // 번역 실패 시 원문 반환
      return text;
    }
  }
  
  /// 여러 키워드 일괄 번역
  static Future<List<Map<String, String>>> translateMultiple(List<String> keywords) async {
    final results = <Map<String, String>>[];
    
    for (final keyword in keywords) {
      final translation = await translateJaToKo(keyword);
      results.add({
        'original': keyword,
        'translation': translation,
      });
    }
    
    return results;
  }
  
  /// 캐시 초기화 (메모리 관리용)
  static void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      debugPrint('🗑️ Translation cache cleared');
    }
  }
  
  /// 캐시 크기 확인
  static int getCacheSize() {
    return _cache.length;
  }
}
