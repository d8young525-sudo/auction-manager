import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:flutter/foundation.dart';

class MetadataService {
  // 링크에서 메타데이터 추출 (제목과 썸네일만)
  static Future<Map<String, String>> fetchMetadata(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to load page: ${response.statusCode}');
      }

      final document = html.parse(response.body);

      // Open Graph 태그 우선
      String? title = document
          .querySelector('meta[property="og:title"]')
          ?.attributes['content'];
      String? image = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];

      // 실패 시 일반 메타 태그
      title ??= document.querySelector('title')?.text;
      image ??= document
          .querySelector('meta[name="image"]')
          ?.attributes['content'];

      // Twitter Card 태그도 시도
      title ??= document
          .querySelector('meta[name="twitter:title"]')
          ?.attributes['content'];
      image ??= document
          .querySelector('meta[name="twitter:image"]')
          ?.attributes['content'];

      return {
        'title': title?.trim() ?? '제목 없음',
        'image': image?.trim() ?? '',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Metadata fetch error: $e');
      }
      return {
        'title': '제목 없음',
        'image': '',
      };
    }
  }

  // URL이 지원되는 옥션 사이트인지 확인
  static bool isSupportedAuctionSite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // 야후옥션 재팬
    if (uri.host.contains('yahoo.co.jp')) {
      return uri.path.contains('auction') || uri.host.contains('auctions');
    }

    return false;
  }

  // 빠른 마감일 생성 (오늘 + N일, 14:00)
  static DateTime getQuickDeadline(int daysFromNow) {
    final now = DateTime.now();
    final targetDate = DateTime(
      now.year,
      now.month,
      now.day + daysFromNow,
      14, // 오후 2시 기본값
      0,
    );
    return targetDate;
  }
}
