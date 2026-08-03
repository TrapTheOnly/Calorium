import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../utils/app_navigator.dart';
import 'nutrition_analysis_service.dart';
import 'settings_service.dart';

class SchedulerService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static const String payloadDaily = 'daily_reminder';
  static const String payloadWeekly = 'weekly_reminder';
  static const String payloadAnalysisDone = 'analysis_completed';

  /// flutter_local_notifications only supports mobile here. On Windows/web the
  /// plugin has no implementation, so every call must be skipped to avoid
  /// UnimplementedError / LateInitializationError crashes during desktop dev.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Initialize the notification system (plugin + timezone). Does not schedule.
  static Future<void> initialize({
    bool requestPermissionsOnInit = false,
  }) async {
    if (_isInitialized) return;
    if (!isSupported) {
      _isInitialized = true;
      debugPrint('Notifications not supported on this platform - skipping init');
      return;
    }

    try {
      tz_data.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (e) {
        debugPrint('Warning: could not set local timezone: $e');
      }

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      if (requestPermissionsOnInit) {
        await requestNotificationPermissions();
      }

      _isInitialized = true;
      debugPrint('Notification system initialized successfully');
    } catch (e) {
      debugPrint('Warning: Failed to initialize notification system: $e');
      _isInitialized = true;
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Notification tapped: $payload');

    // Switch to Insights so the user can open analysis tools.
    openInsightsTab();

    if (payload == payloadDaily || payload == payloadAnalysisDone) {
      // Run analysis when the app is opened from the reminder (not while killed).
      unawaited(performDailyAnalysis());
    } else if (payload == payloadWeekly) {
      unawaited(performWeeklyAnalysis());
    }
  }

  static Future<bool> requestNotificationPermissions() async {
    if (!isSupported) return false;
    try {
      final android =
          _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();

      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return granted ?? true;
    } catch (e) {
      debugPrint('Warning: Failed to request notification permissions: $e');
      return false;
    }
  }

  static Future<void> _requestExactAlarmsIfNeeded() async {
    if (!isSupported) return;
    try {
      final android =
          _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canSchedule = await android?.canScheduleExactNotifications();
      if (canSchedule == false) {
        await android?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('Warning: exact alarm permission request failed: $e');
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    if (!isSupported) return false;
    try {
      final android =
          _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextSundayAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    // DateTime.sunday == 7
    var daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday < 0) {
      daysUntilSunday += 7;
    }
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(days: daysUntilSunday));
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  static Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required DateTimeComponents matchComponents,
    required String payload,
  }) async {
    await _requestExactAlarmsIfNeeded();

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
      debugPrint('Scheduled notification $id at $when (exact)');
    } catch (e) {
      debugPrint('Exact scheduling failed for $id, trying inexact: $e');
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
      debugPrint('Scheduled notification $id at $when (inexact)');
    }
  }

  /// Schedule daily reminder at 10 PM local time.
  static Future<void> scheduleDailyAnalysis() async {
    if (!isSupported) return;
    try {
      if (!_isInitialized) await initialize();

      await _notifications.cancel(1000);

      final enabled = await SettingsService.isDailyReminderEnabled();
      if (!enabled) {
        debugPrint('Daily reminder disabled');
        return;
      }

      final when = _nextInstanceOfTime(22, 0);
      await _zonedScheduleWithFallback(
        id: 1000,
        title: 'Evening nutrition check-in',
        body: 'Review today\'s log and open Insights for AI suggestions.',
        when: when,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_analysis',
            'Daily Nutrition Reminders',
            channelDescription: 'Daily nutrition reminder notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_calorium',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: 'daily_analysis'),
        ),
        matchComponents: DateTimeComponents.time,
        payload: payloadDaily,
      );
    } catch (e) {
      debugPrint('Error in scheduleDailyAnalysis: $e');
    }
  }

  /// Schedule weekly reminder (Sundays at 8 PM local time).
  static Future<void> scheduleWeeklyAnalysis() async {
    if (!isSupported) return;
    try {
      if (!_isInitialized) await initialize();

      await _notifications.cancel(2000);

      final enabled = await SettingsService.isWeeklyReminderEnabled();
      if (!enabled) {
        debugPrint('Weekly reminder disabled');
        return;
      }

      final when = _nextSundayAt(20, 0);
      await _zonedScheduleWithFallback(
        id: 2000,
        title: 'Weekly nutrition review',
        body: 'Open Insights to review your week and generate a summary.',
        when: when,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_analysis',
            'Weekly Nutrition Reminders',
            channelDescription: 'Weekly nutrition reminder notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_calorium',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'weekly_analysis',
          ),
        ),
        matchComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payloadWeekly,
      );
    } catch (e) {
      debugPrint('Error in scheduleWeeklyAnalysis: $e');
    }
  }

  /// Perform daily analysis when the app is open (e.g. after a reminder tap).
  static Future<void> performDailyAnalysis() async {
    try {
      final hasEnoughData =
          await NutritionAnalysisService.hasEnoughDataForAnalysis();
      if (!hasEnoughData) {
        debugPrint('Not enough data for AI analysis');
        return;
      }

      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final lastAnalysisDate = await SettingsService.getLastAiAnalysisDate();
      if (lastAnalysisDate == dateString) {
        debugPrint('Analysis already completed for today');
        return;
      }

      final result = await NutritionAnalysisService.analyzeDailyNutrition(
        dateString,
      );

      if (result != null) {
        debugPrint('Daily analysis completed successfully');
        await _sendAnalysisCompletedNotification();
      }
    } catch (e) {
      debugPrint('Error performing daily analysis: $e');
    }
  }

  static Future<void> _sendAnalysisCompletedNotification() async {
    if (!isSupported) return;
    if (!_isInitialized) await initialize();

    await _notifications.show(
      3000,
      'Nutrition insights ready',
      'Your personalized AI suggestions are available in Insights.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'analysis_completed',
          'Analysis Completed',
          channelDescription: 'Notifications when AI analysis is completed',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'analysis_completed',
        ),
      ),
      payload: payloadAnalysisDone,
    );
  }

  static Future<void> performWeeklyAnalysis() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final weekStartString =
          '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';

      final result = await NutritionAnalysisService.generateWeeklySummary(
        weekStartString,
      );

      if (result != null) {
        debugPrint('Weekly analysis completed successfully');
        await _sendWeeklyAnalysisCompletedNotification();
      }
    } catch (e) {
      debugPrint('Error performing weekly analysis: $e');
    }
  }

  static Future<void> _sendWeeklyAnalysisCompletedNotification() async {
    if (!isSupported) return;
    if (!_isInitialized) await initialize();

    await _notifications.show(
      4000,
      'Weekly report ready',
      'Your weekly nutrition summary is ready in Insights.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_completed',
          'Weekly Report Completed',
          channelDescription: 'Notifications when weekly analysis is completed',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'weekly_completed'),
      ),
      payload: payloadWeekly,
    );
  }

  /// Apply reminder preferences and (re)schedule.
  static Future<void> setupScheduledNotifications() async {
    if (!isSupported) return;
    try {
      if (!_isInitialized) await initialize();

      final daily = await SettingsService.isDailyReminderEnabled();
      final weekly = await SettingsService.isWeeklyReminderEnabled();

      if (daily) {
        await scheduleDailyAnalysis();
      } else {
        await _notifications.cancel(1000);
      }

      if (weekly) {
        await scheduleWeeklyAnalysis();
      } else {
        await _notifications.cancel(2000);
      }

      debugPrint(
        'Reminder setup complete (daily=$daily, weekly=$weekly)',
      );
    } catch (e) {
      debugPrint('Error in setupScheduledNotifications: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    if (!isSupported) return;
    try {
      if (!_isInitialized) await initialize();
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  static Future<void> showEatingWindowNotification({
    required Duration timeRemaining,
    required bool isActive,
  }) async {
    if (!isSupported) return;
    if (!_isInitialized) await initialize();

    const notificationId = 5010;

    if (!isActive) {
      await _notifications.cancel(notificationId);
      return;
    }

    final hours = timeRemaining.inHours;
    final minutes = timeRemaining.inMinutes % 60;
    final formatted =
        '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m left';

    try {
      await _notifications.show(
        notificationId,
        'Eating window in progress',
        formatted,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_eating_window',
            'Eating Window Status',
            channelDescription: 'Updates while your eating window is active',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            playSound: false,
            icon: 'ic_stat_calorium',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            interruptionLevel: InterruptionLevel.passive,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing eating window notification: $e');
    }
  }

  static Future<void> showTestNotification() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Notifications are only available on Android and iOS.',
      );
    }
    if (!_isInitialized) await initialize();
    await requestNotificationPermissions();

    await _notifications.show(
      9999,
      'Test notification',
      'Calorium notifications are working.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          'Test Notifications',
          channelDescription: 'Test notifications for debugging',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'test'),
      ),
      payload: payloadDaily,
    );
  }

  /// Debug helper: schedule a notification a few seconds from now.
  static Future<void> scheduleShortDelayTest({
    Duration delay = const Duration(seconds: 15),
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Scheduled notifications are only available on Android and iOS.',
      );
    }
    if (!_isInitialized) await initialize();
    await requestNotificationPermissions();
    await _requestExactAlarmsIfNeeded();

    final when = tz.TZDateTime.now(tz.local).add(delay);
    try {
      await _notifications.zonedSchedule(
        9998,
        'Scheduled test',
        'If you see this, scheduled notifications work.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test',
            'Test Notifications',
            channelDescription: 'Test notifications for debugging',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_calorium',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: 'test'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payloadDaily,
      );
    } catch (e) {
      await _notifications.zonedSchedule(
        9998,
        'Scheduled test',
        'If you see this, scheduled notifications work.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test',
            'Test Notifications',
            channelDescription: 'Test notifications for debugging',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_calorium',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: 'test'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payloadDaily,
      );
    }
  }

  // ========================================
  // DEBUG METHODS
  // ========================================

  static Future<void> debugTriggerDailyNotification() async {
    if (!isSupported) return;
    if (!_isInitialized) await initialize();
    await _notifications.show(
      1001,
      'Evening nutrition check-in (DEBUG)',
      'Manual trigger: open Insights for AI suggestions.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_daily_analysis',
          'Debug Daily Analysis',
          channelDescription: 'Debug daily reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'debug_daily_analysis',
        ),
      ),
      payload: payloadDaily,
    );
  }

  static Future<void> debugTriggerWeeklyNotification() async {
    if (!isSupported) return;
    if (!_isInitialized) await initialize();
    await _notifications.show(
      2001,
      'Weekly nutrition review (DEBUG)',
      'Manual trigger: open Insights for your weekly summary.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_weekly_analysis',
          'Debug Weekly Analysis',
          channelDescription: 'Debug weekly reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'debug_weekly_analysis',
        ),
      ),
      payload: payloadWeekly,
    );
  }

  static Future<void> debugPerformDailyAnalysis({bool force = false}) async {
    try {
      final hasEnoughData =
          await NutritionAnalysisService.hasEnoughDataForAnalysis();
      if (!hasEnoughData && !force) return;

      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      if (!force) {
        final lastAnalysisDate = await SettingsService.getLastAiAnalysisDate();
        if (lastAnalysisDate == dateString) return;
      }

      final result = await NutritionAnalysisService.analyzeDailyNutrition(
        dateString,
      );
      if (result != null) {
        await _sendAnalysisCompletedNotification();
      }
    } catch (e) {
      debugPrint('DEBUG daily analysis error: $e');
    }
  }

  static Future<void> debugPerformWeeklyAnalysis({
    String? customWeekStart,
  }) async {
    try {
      String weekStartString;
      if (customWeekStart != null) {
        weekStartString = customWeekStart;
      } else {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        weekStartString =
            '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
      }

      final result = await NutritionAnalysisService.generateWeeklySummary(
        weekStartString,
      );
      if (result != null) {
        await _sendWeeklyAnalysisCompletedNotification();
      }
    } catch (e) {
      debugPrint('DEBUG weekly analysis error: $e');
    }
  }

  static Future<void> debugShowScheduledNotifications() async {
    if (!isSupported) return;
    if (!_isInitialized) await initialize();
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('Pending notifications: ${pending.length}');
    for (final n in pending) {
      debugPrint('  id=${n.id} title=${n.title}');
    }
  }

  static Future<void> debugFullTestSuite() async {
    await showTestNotification();
    await debugTriggerDailyNotification();
    await debugTriggerWeeklyNotification();
    await debugShowScheduledNotifications();
  }

  // This build folds the daily summary into the daily analysis check-in and
  // does not schedule a separate summary notification, so the debug hook
  // reuses that pathway to keep the console command working.
  static Future<void> debugTriggerDailySummaryNotification() async {
    await debugTriggerDailyNotification();
  }

  // Fasting reminders are driven by the eating-window schedule; this debug
  // hook simply rebuilds the scheduled notifications so the refresh can be
  // verified from the console.
  static Future<void> debugTriggerFastingNotifications() async {
    await setupScheduledNotifications();
  }
}
