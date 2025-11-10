import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/item_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  /// 알림 서비스 초기화
  static Future<void> initialize() async {
    if (_initialized) return;

    // 타임존 초기화
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
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
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// 알림 클릭 시 처리
  static void _onNotificationTapped(NotificationResponse response) {
    // TODO: 알림 클릭 시 해당 아이템 화면으로 이동
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.payload}');
    }
  }

  /// 알림 권한 요청 (Android 13+)
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    }
    
    if (Platform.isIOS) {
      final iosImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    
    return true;
  }

  /// 즐겨찾기한 아이템의 마감일 알림 예약
  static Future<void> scheduleDeadlineNotification({
    required ItemModel item,
    required Duration beforeDeadline,
    bool enableSound = true,
    bool enableVibration = true,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final notificationTime = item.deadline.subtract(beforeDeadline);
    
    // 과거 시간이면 알림 예약하지 않음
    if (notificationTime.isBefore(DateTime.now())) {
      return;
    }

    final notificationId = _getNotificationId(item.id, beforeDeadline);

    // Android 알림 상세 설정
    final androidDetails = AndroidNotificationDetails(
      'deadline_reminders',
      '마감일 알림',
      channelDescription: '즐겨찾기한 아이템의 마감일 알림',
      importance: Importance.high,
      priority: Priority.high,
      playSound: enableSound,
      enableVibration: enableVibration,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    // iOS 알림 상세 설정
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: enableSound,
      sound: enableSound ? 'default' : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 알림 예약
    await _notifications.zonedSchedule(
      notificationId,
      '⏰ ${_getTimeLabel(beforeDeadline)} 남았습니다!',
      '${item.title}\n마감: ${_formatDeadline(item.deadline)}',
      tz.TZDateTime.from(notificationTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: item.id,
    );
  }

  /// 특정 아이템의 모든 알림 취소
  static Future<void> cancelNotificationsForItem(String itemId) async {
    final durations = [
      const Duration(hours: 3),
      const Duration(hours: 1),
      const Duration(minutes: 15),
      const Duration(minutes: 10),
    ];

    for (final duration in durations) {
      final notificationId = _getNotificationId(itemId, duration);
      await _notifications.cancel(notificationId);
    }
  }

  /// 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 대기 중인 알림 목록 조회
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// 아이템 ID와 시간으로 고유한 알림 ID 생성
  static int _getNotificationId(String itemId, Duration beforeDeadline) {
    // itemId 해시코드 + 시간(분 단위)로 고유 ID 생성
    final timeMinutes = beforeDeadline.inMinutes;
    return itemId.hashCode + timeMinutes;
  }

  /// 시간 라벨 생성
  static String _getTimeLabel(Duration duration) {
    if (duration.inHours >= 1) {
      return '${duration.inHours}시간';
    } else {
      return '${duration.inMinutes}분';
    }
  }

  /// 마감일 포맷팅
  static String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 ${difference.inHours % 24}시간 후';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 ${difference.inMinutes % 60}분 후';
    } else {
      return '${difference.inMinutes}분 후';
    }
  }
}
