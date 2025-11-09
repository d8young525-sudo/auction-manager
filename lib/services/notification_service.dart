import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';
import '../models/item_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 초기화
  static Future<void> init() async {
    try {
      // 타임존 데이터 초기화
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo')); // 일본 시간 기준

      // Android 설정
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 설정
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Android 13+ 알림 권한 요청
      await _requestPermissions();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Notification init error: $e');
      }
    }
  }

  // 알림 권한 요청
  static Future<void> _requestPermissions() async {
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // 알림 탭 처리
  static void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.payload}');
    }
    // TODO: 알림 탭 시 해당 아이템 상세 화면으로 이동
  }

  // 아이템에 대한 마감 알림 예약
  static Future<void> scheduleItemDeadlineNotifications(
      ItemModel item) async {
    try {
      // 마감 24시간 전 알림
      final deadline24h = item.deadline.subtract(const Duration(hours: 24));
      if (deadline24h.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: item.id.hashCode,
          title: '⏰ 마감 24시간 전!',
          body: '${item.title}\n마감: ${_formatDeadline(item.deadline)}',
          scheduledDate: deadline24h,
          payload: item.id,
        );
      }

      // 즐겨찾기 아이템은 72시간 전에도 알림
      if (item.isFavorite) {
        final deadline72h = item.deadline.subtract(const Duration(hours: 72));
        if (deadline72h.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: item.id.hashCode + 1000, // 다른 ID 사용
            title: '⭐ 즐겨찾기 아이템 마감 3일 전!',
            body: '${item.title}\n마감: ${_formatDeadline(item.deadline)}',
            scheduledDate: deadline72h,
            payload: item.id,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
  }

  // 알림 예약 (내부 메서드)
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'auction_deadlines',
      '옥션 마감 알림',
      channelDescription: '옥션 아이템의 마감 시간을 알려드립니다',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // 특정 아이템의 알림 취소
  static Future<void> cancelItemNotifications(String itemId) async {
    await _notifications.cancel(itemId.hashCode);
    await _notifications.cancel(itemId.hashCode + 1000); // 72시간 전 알림도 취소
  }

  // 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // 마감일 포맷팅
  static String _formatDeadline(DateTime deadline) {
    return '${deadline.year}.${deadline.month.toString().padLeft(2, '0')}.${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
  }

  // 즉시 테스트 알림 보내기 (개발용)
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      '테스트 알림',
      channelDescription: '알림 테스트용',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999,
      '테스트 알림',
      '알림이 정상적으로 작동합니다!',
      details,
    );
  }
}
