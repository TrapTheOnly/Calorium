import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/fasting_settings.dart';
import '../screens/daily_log_screen.dart';
import '../screens/weekly_analysis_screen.dart';
import 'database_service.dart';
import 'fasting_service.dart';
import 'nutrition_analysis_service.dart';
import 'settings_service.dart';

class SchedulerService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static final DateFormat _timeFormatter = DateFormat.jm();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static const int _dailyAnalysisNotificationId = 1000;
  static const int _weeklyAnalysisNotificationId = 2000;
  static const int _analysisCompletedNotificationId = 3000;
  static const int _weeklyCompletedNotificationId = 4000;
  static const int _persistentEatingWindowNotificationId = 5010;
  static const int _fastingStartNotificationId = 5100;
  static const int _fastingEndNotificationId = 5101;
  static const int _dailySummaryNotificationId = 5200;
  static const String _payloadDailyAnalysisPrefix = 'navigate:daily_analysis:';
  static const String _payloadWeeklyAnalysisPrefix =
      'navigate:weekly_analysis:';

  /// Initialize the notification system
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_notification_calorium',
      );
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
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      print('Notification system initialized successfully');
    } catch (e) {
      print('Warning: Failed to initialize notification system: $e');
      // Mark as initialized to prevent repeated failed attempts
      _isInitialized = true;
    }
  }

  /// Provide navigator access for notification taps
  static void configureNavigator(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  static Future<void> _requestPermissions() async {
    try {
      // For Android 13+ (API level 33+), request notification permission
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      print('Warning: Failed to request notification permissions: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfMinutes(
    int minutesOfDay,
    tz.TZDateTime reference,
  ) {
    final hours = minutesOfDay ~/ 60;
    final minutes = minutesOfDay % 60;
    var scheduled = tz.TZDateTime(
      tz.local,
      reference.year,
      reference.month,
      reference.day,
      hours,
      minutes,
    );
    if (!scheduled.isAfter(reference)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _formatTime(tz.TZDateTime time) {
    return _timeFormatter.format(time.toLocal());
  }

  static double _percentage(double value, double? target) {
    if (target == null || target <= 0) {
      return 0;
    }
    return (value / target * 100).clamp(0, 999);
  }

  static String _formatMacroProgress(
    String label,
    double consumed,
    double? target,
  ) {
    final percent = _percentage(consumed, target);
    final roundedPercent = percent.toStringAsFixed(percent >= 100 ? 0 : 1);
    final valueString = consumed.toStringAsFixed(consumed >= 100 ? 0 : 1);
    final targetString =
        target != null && target > 0 ? target.toStringAsFixed(0) : '—';
    return '$label: $valueString${label == 'Calories' ? ' kcal' : 'g'}'
        ' / $targetString (${roundedPercent}%)';
  }

  static String _percentLabel(String label, double value, double? target) {
    if (target == null || target <= 0) {
      return '$label —';
    }
    final pct = _percentage(value, target).round();
    return '$label ${pct.toInt()}%';
  }

  static Future<Map<String, double>> _loadDailyTotals(String date) async {
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(f.calories * l.amount * l.portions / 100) as totalCalories,
        SUM(f.fat * l.amount * l.portions / 100) as totalFat,
        SUM(f.carbs * l.amount * l.portions / 100) as totalCarbs,
        SUM(f.protein * l.amount * l.portions / 100) as totalProtein
      FROM logs l
      JOIN foods f ON l.foodId = f.id
      WHERE l.date = ?
    ''',
      [date],
    );

    final row = result.isNotEmpty ? result.first : <String, Object?>{};

    double _toDouble(String key) {
      final value = row[key];
      if (value is num) {
        return value.toDouble();
      }
      return 0;
    }

    return {
      'calories': _toDouble('totalCalories'),
      'fat': _toDouble('totalFat'),
      'carbs': _toDouble('totalCarbs'),
      'protein': _toDouble('totalProtein'),
    };
  }

  /// Schedule daily AI analysis at 10 PM
  static Future<void> scheduleDailyAnalysis() async {
    try {
      if (!_isInitialized) await initialize();

      // Cancel existing daily notifications with error handling
      try {
        await _notifications.cancel(_dailyAnalysisNotificationId);
      } catch (e) {
        print('Warning: Could not cancel existing notification: $e');
      }

      // Check if user has API key and complete profile
      final hasApiKey = await SettingsService.hasGeminiApiKey();
      final hasCompleteProfile = await SettingsService.hasCompleteProfile();
      final weeklyOptIn =
          await SettingsService.getWeeklyAnalysisNotificationsEnabled();

      if (!hasApiKey || !hasCompleteProfile || !weeklyOptIn) {
        return; // Don't schedule if requirements not met
      }

      // Schedule for 10 PM today
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        22,
        0,
      ); // 10 PM

      // If it's already past 10 PM today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final notificationDetails = NotificationDetails(
        android: const AndroidNotificationDetails(
          'daily_analysis',
          'Daily Nutrition Analysis',
          channelDescription: 'Daily AI nutrition analysis notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'daily_analysis',
        ),
      );

      try {
        await _notifications.zonedSchedule(
          _dailyAnalysisNotificationId,
          'Daily Nutrition Analysis Ready',
          'Your AI nutrition insights are ready! Tap to view personalized suggestions.',
          tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              DateTimeComponents.time, // Repeat daily at this time
        );

        print(
          'Daily analysis scheduled for ${scheduledDate.toString()} (exact timing)',
        );
      } catch (e) {
        // If exact scheduling fails, fall back to inexact scheduling
        print(
          'Exact scheduling failed, falling back to inexact scheduling: $e',
        );

        try {
          await _notifications.zonedSchedule(
            _dailyAnalysisNotificationId,
            'Daily Nutrition Analysis Ready',
            'Your AI nutrition insights are ready! Tap to view personalized suggestions.',
            tz.TZDateTime.from(scheduledDate, tz.local),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents:
                DateTimeComponents.time, // Repeat daily at this time
          );

          print(
            'Daily analysis scheduled for ${scheduledDate.toString()} (inexact timing)',
          );
        } catch (fallbackError) {
          print('Failed to schedule daily analysis: $fallbackError');
        }
      }
    } catch (e) {
      print('Error in scheduleDailyAnalysis: $e');
      // Don't rethrow - notifications are not critical
    }
  }

  /// Schedule weekly analysis notification for Sundays at the configured time
  static Future<void> scheduleWeeklyAnalysis() async {
    try {
      if (!_isInitialized) await initialize();

      // Cancel existing weekly notifications with error handling
      try {
        await _notifications.cancel(_weeklyAnalysisNotificationId);
      } catch (e) {
        print('Warning: Could not cancel existing weekly notification: $e');
      }

      // Check if user has API key and complete profile
      final hasApiKey = await SettingsService.hasGeminiApiKey();
      final hasCompleteProfile = await SettingsService.hasCompleteProfile();

      final weeklyOptIn =
          await SettingsService.getWeeklyAnalysisNotificationsEnabled();

      if (!hasApiKey || !hasCompleteProfile || !weeklyOptIn) {
        return; // Don't schedule if requirements not met
      }

      // Schedule for next Sunday at 8 PM
      final now = DateTime.now();
      var nextSunday = now.add(Duration(days: 7 - now.weekday));
      final weeklyMinutes =
          await SettingsService.getWeeklyAnalysisNotificationTimeMinutes();
      nextSunday = DateTime(
        nextSunday.year,
        nextSunday.month,
        nextSunday.day,
        weeklyMinutes ~/ 60,
        weeklyMinutes % 60,
      );

      if (nextSunday.isBefore(now)) {
        nextSunday = nextSunday.add(const Duration(days: 7));
      }

      try {
        await _notifications.zonedSchedule(
          _weeklyAnalysisNotificationId,
          'Weekly Nutrition Summary Ready',
          'Your weekly nutrition report is ready! See how you\'ve been doing.',
          tz.TZDateTime.from(nextSunday, tz.local),
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'weekly_analysis',
              'Weekly Nutrition Summary',
              channelDescription: 'Weekly nutrition summary notifications',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/ic_notification_calorium',
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'weekly_analysis',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
        );

        print(
          'Weekly analysis scheduled for ${nextSunday.toString()} (exact timing)',
        );
      } catch (e) {
        // If exact scheduling fails, fall back to inexact scheduling
        print('Exact weekly scheduling failed, falling back to inexact: $e');

        try {
          await _notifications.zonedSchedule(
            _weeklyAnalysisNotificationId,
            'Weekly Nutrition Summary Ready',
            'Your weekly nutrition report is ready! See how you\'ve been doing.',
            tz.TZDateTime.from(nextSunday, tz.local),
            NotificationDetails(
              android: const AndroidNotificationDetails(
                'weekly_analysis',
                'Weekly Nutrition Summary',
                channelDescription: 'Weekly nutrition summary notifications',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@drawable/ic_notification_calorium',
                largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              ),
              iOS: const DarwinNotificationDetails(
                categoryIdentifier: 'weekly_analysis',
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents:
                DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
          );

          print(
            'Weekly analysis scheduled for ${nextSunday.toString()} (inexact timing)',
          );
        } catch (fallbackError) {
          print('Failed to schedule weekly analysis: $fallbackError');
        }
      }
    } catch (e) {
      print('Error in scheduleWeeklyAnalysis: $e');
      // Don't rethrow - notifications are not critical
    }
  }

  static Future<_DailySummaryNotificationData> _buildDailySummaryData(
    tz.TZDateTime scheduledTime,
  ) async {
    final summaryDate = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
    );
    final dateString = DateFormat('yyyy-MM-dd').format(summaryDate);

    final totals = await _loadDailyTotals(dateString);
    final calories = totals['calories'] ?? 0.0;
    final protein = totals['protein'] ?? 0.0;
    final carbs = totals['carbs'] ?? 0.0;
    final fat = totals['fat'] ?? 0.0;

    final macroTargets = await SettingsService.getMacroTargets();
    final calorieTarget = await SettingsService.getCalorieTarget();
    final proteinTarget = macroTargets?['protein'];
    final carbsTarget = macroTargets?['carbs'];
    final fatTarget = macroTargets?['fat'];

    final bigText = [
      _formatMacroProgress('Calories', calories, calorieTarget),
      _formatMacroProgress('Protein', protein, proteinTarget),
      _formatMacroProgress('Carbs', carbs, carbsTarget),
      _formatMacroProgress('Fat', fat, fatTarget),
    ].join('\n');

    final compactSummary = [
      _percentLabel('Calories', calories, calorieTarget),
      _percentLabel('Protein', protein, proteinTarget),
      _percentLabel('Carbs', carbs, carbsTarget),
      _percentLabel('Fat', fat, fatTarget),
    ].join(' • ');

    return _DailySummaryNotificationData(
      scheduledTime: scheduledTime,
      summaryDateString: dateString,
      compactSummary: compactSummary,
      bigText: bigText,
    );
  }

  static NotificationDetails _dailySummaryNotificationDetails(
    _DailySummaryNotificationData data,
  ) {
    final subtitle = _formatTime(data.scheduledTime);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_summary',
        'Daily Summary',
        channelDescription:
            'Daily summaries of your calories and macros compared to targets',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification_calorium',
        styleInformation: BigTextStyleInformation(
          data.bigText,
          summaryText: subtitle,
        ),
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'daily_summary',
        subtitle: subtitle,
      ),
    );
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType !=
            NotificationResponseType.selectedNotification &&
        response.notificationResponseType !=
            NotificationResponseType.selectedNotificationAction) {
      return;
    }

    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    if (payload.startsWith(_payloadDailyAnalysisPrefix)) {
      final dateString = payload.substring(_payloadDailyAnalysisPrefix.length);
      Future.microtask(() {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => DailyLogScreen(date: dateString),
            settings: const RouteSettings(
              name: 'DailyLogScreenFromNotification',
            ),
          ),
        );
      });
    } else if (payload.startsWith(_payloadWeeklyAnalysisPrefix)) {
      final weekStart = payload.substring(_payloadWeeklyAnalysisPrefix.length);
      Future.microtask(() {
        navigator.push(
          MaterialPageRoute(
            builder:
                (context) => WeeklyAnalysisScreen(weekStartDate: weekStart),
            settings: const RouteSettings(
              name: 'WeeklyAnalysisScreenFromNotification',
            ),
          ),
        );
      });
    }
  }

  /// Schedule the end-of-day nutrition summary notification
  static Future<void> scheduleDailySummaryNotification() async {
    try {
      if (!_isInitialized) await initialize();

      await _notifications.cancel(_dailySummaryNotificationId);

      final enabled =
          await SettingsService.getDailySummaryNotificationsEnabled();
      if (!enabled) {
        return;
      }

      final tzNow = tz.TZDateTime.now(tz.local);
      final targetMinutes =
          await SettingsService.getDailySummaryNotificationTimeMinutes();
      final scheduledTime = _nextInstanceOfMinutes(targetMinutes, tzNow);

      final data = await _buildDailySummaryData(scheduledTime);

      await _notifications.zonedSchedule(
        _dailySummaryNotificationId,
        'Daily nutrition summary',
        data.compactSummary,
        scheduledTime,
        _dailySummaryNotificationDetails(data),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print(
        'Daily summary scheduled for ${scheduledTime.toString()} with totals for ${data.summaryDateString}',
      );
    } catch (e) {
      print('Error scheduling daily summary notification: $e');
    }
  }

  /// Perform daily analysis (called when notification is triggered or manually)
  static Future<void> performDailyAnalysis() async {
    try {
      // Check if user has enough data for analysis
      final hasEnoughData =
          await NutritionAnalysisService.hasEnoughDataForAnalysis();
      if (!hasEnoughData) {
        print('Not enough data for AI analysis');
        return;
      }

      // Get today's date
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check if analysis already done today
      final lastAnalysisDate = await SettingsService.getLastAiAnalysisDate();
      if (lastAnalysisDate == dateString) {
        print('Analysis already completed for today');
        return;
      }

      // Perform the analysis
      final result = await NutritionAnalysisService.analyzeDailyNutrition(
        dateString,
      );

      if (result != null) {
        print('Daily analysis completed successfully');

        // Send completion notification
        await _sendAnalysisCompletedNotification(dateString);
      } else {
        print('Daily analysis failed - no data for today');
      }
    } catch (e) {
      print('Error performing daily analysis: $e');
    }
  }

  /// Send notification when analysis is completed
  static Future<void> _sendAnalysisCompletedNotification(
    String dateString,
  ) async {
    if (!_isInitialized) await initialize();

    await _notifications.show(
      _analysisCompletedNotificationId,
      'Nutrition Insights Ready! 🎯',
      'Your personalized AI suggestions and motivation are waiting for you.',
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'analysis_completed',
          'Analysis Completed',
          channelDescription: 'Notifications when AI analysis is completed',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification_calorium',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'analysis_completed',
        ),
      ),
      payload: '$_payloadDailyAnalysisPrefix$dateString',
    );
  }

  /// Perform weekly analysis
  static Future<void> performWeeklyAnalysis() async {
    try {
      // Get the start of this week (Monday)
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final weekStartString =
          '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';

      // Perform the weekly analysis
      final result = await NutritionAnalysisService.generateWeeklySummary(
        weekStartString,
      );

      if (result != null) {
        print('Weekly analysis completed successfully');

        // Send completion notification
        await _sendWeeklyAnalysisCompletedNotification(weekStartString);
      } else {
        print('Weekly analysis failed');
      }
    } catch (e) {
      print('Error performing weekly analysis: $e');
    }
  }

  /// Send notification when weekly analysis is completed
  static Future<void> _sendWeeklyAnalysisCompletedNotification(
    String weekStart,
  ) async {
    if (!_isInitialized) await initialize();

    await _notifications.show(
      _weeklyCompletedNotificationId,
      'Weekly Report Ready! 📊',
      'Your comprehensive nutrition summary and insights for this week are ready.',
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'weekly_completed',
          'Weekly Report Completed',
          channelDescription: 'Notifications when weekly analysis is completed',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification_calorium',
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'weekly_completed'),
      ),
      payload: '$_payloadWeeklyAnalysisPrefix$weekStart',
    );
  }

  /// Check and schedule notifications if needed (call this on app start)
  static Future<void> setupScheduledNotifications() async {
    try {
      final hasApiKey = await SettingsService.hasGeminiApiKey();
      final hasCompleteProfile = await SettingsService.hasCompleteProfile();

      if (hasApiKey && hasCompleteProfile) {
        await scheduleDailyAnalysis();
        await scheduleWeeklyAnalysis();
      } else {
        print('Skipping AI notification setup - requirements not met');
      }

      await scheduleDailySummaryNotification();
      await updateFastingWindowNotifications();

      print('Notifications scheduled successfully');
    } catch (e) {
      print('Error in setupScheduledNotifications: $e');
      // Don't rethrow - let the app continue without notifications
    }
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllNotifications() async {
    try {
      if (!_isInitialized) await initialize();

      await _notifications.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error cancelling notifications: $e');
    }
  }

  /// Schedule intermittent fasting start/end notifications and the persistent banner
  static Future<void> updateFastingWindowNotifications() async {
    try {
      if (!_isInitialized) await initialize();

      await _notifications.cancel(_fastingStartNotificationId);
      await _notifications.cancel(_fastingEndNotificationId);
      await _notifications.cancel(_persistentEatingWindowNotificationId);

      final notificationsEnabled =
          await SettingsService.getFastingNotificationsEnabled();
      if (!notificationsEnabled) {
        return;
      }

      final settings = await FastingService.getSettings();
      if (!settings.enabled) {
        return;
      }

      final tzNow = tz.TZDateTime.now(tz.local);
      final startMinutes = settings.eatingStartMinutes;
      final endMinutes =
          (settings.eatingStartMinutes + settings.eatingDurationMinutes) %
          FastingSettings.minutesPerDay;

      final startTime = _nextInstanceOfMinutes(startMinutes, tzNow);
      var endTime = _nextInstanceOfMinutes(endMinutes, startTime);
      if (!endTime.isAfter(startTime)) {
        endTime = endTime.add(const Duration(days: 1));
      }
      final nextStartTime = _nextInstanceOfMinutes(startMinutes, endTime);
      final eatingDuration = Duration(minutes: settings.eatingDurationMinutes);

      final startBody =
          'Your eating window is open until ${_formatTime(endTime)}.';
      await _notifications.zonedSchedule(
        _fastingStartNotificationId,
        'Eating window started',
        startBody,
        startTime,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'fasting_window_start',
            'Fasting Window Alerts',
            channelDescription:
                'Reminders when your intermittent fasting eating window starts and ends',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification_calorium',
          ),
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: 'fasting_window_start',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      await _notifications.zonedSchedule(
        _persistentEatingWindowNotificationId,
        'Eating window in progress',
        'Ends at ${_formatTime(endTime)}',
        startTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_eating_window',
            'Eating Window Status',
            channelDescription: 'Updates while your eating window is active',
            importance: Importance.low,
            priority: Priority.low,
            icon: '@drawable/ic_notification_calorium',
            ongoing: true,
            playSound: false,
            usesChronometer: true,
            chronometerCountDown: true,
            when: endTime.millisecondsSinceEpoch,
            showWhen: false,
            timeoutAfter: eatingDuration.inMilliseconds,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'fasting_eating_window',
            interruptionLevel: InterruptionLevel.passive,
            presentSound: false,
            subtitle: 'Ends at ${_formatTime(endTime)}',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      final endBody =
          'Eating window closed. Next window opens at ${_formatTime(nextStartTime)}.';
      await _notifications.zonedSchedule(
        _fastingEndNotificationId,
        'Eating window finished',
        endBody,
        endTime,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'fasting_window_end',
            'Fasting Window Alerts',
            channelDescription:
                'Reminders when your intermittent fasting eating window starts and ends',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification_calorium',
          ),
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: 'fasting_window_end',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print(
        'Fasting notifications scheduled: start ${startTime.toString()}, end ${endTime.toString()}',
      );
    } catch (e) {
      print('Error scheduling fasting notifications: $e');
    }
  }

  /// Show/update a persistent notification while the eating window is active
  static Future<void> showEatingWindowNotification({
    required Duration timeRemaining,
    required bool isActive,
  }) async {
    if (!_isInitialized) await initialize();

    const notificationId = _persistentEatingWindowNotificationId;

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
            icon: '@drawable/ic_notification_calorium',
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            interruptionLevel: InterruptionLevel.passive,
          ),
        ),
      );
    } catch (e) {
      print('Error showing eating window notification: $e');
    }
  }

  /// Show a test notification (for debugging)
  static Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();

    await _notifications.show(
      9999,
      'Test Notification',
      'This is a test notification from Calorium.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          'Test Notifications',
          channelDescription: 'Test notifications for debugging',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'test'),
      ),
    );
  }

  // ========================================
  // DEBUG METHODS FOR MANUAL TESTING
  // ========================================

  /// Manually run the daily analysis so the real notification pathway is exercised (DEBUG ONLY)
  static Future<void> debugTriggerDailyNotification() async {
    print('🐛 DEBUG: Running daily analysis to trigger notification...');
    await debugPerformDailyAnalysis(force: true);
  }

  /// Manually run the weekly analysis so the real notification pathway is exercised (DEBUG ONLY)
  static Future<void> debugTriggerWeeklyNotification() async {
    print('🐛 DEBUG: Running weekly analysis to trigger notification...');
    await debugPerformWeeklyAnalysis();
  }

  /// Generate the daily summary notification immediately using live data (DEBUG ONLY)
  static Future<void> debugTriggerDailySummaryNotification() async {
    if (!_isInitialized) await initialize();

    print('🐛 DEBUG: Showing daily summary notification...');
    final scheduled = tz.TZDateTime.now(tz.local);
    final data = await _buildDailySummaryData(scheduled);
    await _notifications.show(
      _dailySummaryNotificationId,
      'Daily nutrition summary',
      data.compactSummary,
      _dailySummaryNotificationDetails(data),
    );
    print('✅ DEBUG: Daily summary notification displayed');
  }

  /// Refresh fasting notifications with the latest settings (DEBUG ONLY)
  static Future<void> debugTriggerFastingNotifications() async {
    print(
      '🐛 DEBUG: Scheduling fasting notifications with current settings...',
    );
    await updateFastingWindowNotifications();
    print('✅ DEBUG: Fasting notifications refreshed');
  }

  /// Manual trigger for daily AI analysis with force option (DEBUG ONLY)
  static Future<void> debugPerformDailyAnalysis({bool force = false}) async {
    print('🐛 DEBUG: Manually performing daily analysis (force: $force)...');

    try {
      // Check if user has enough data for analysis
      final hasEnoughData =
          await NutritionAnalysisService.hasEnoughDataForAnalysis();
      if (!hasEnoughData && !force) {
        print('❌ DEBUG: Not enough data for AI analysis');
        return;
      }

      // Get today's date
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check if analysis already done today (skip if force = true)
      if (!force) {
        final lastAnalysisDate = await SettingsService.getLastAiAnalysisDate();
        if (lastAnalysisDate == dateString) {
          print(
            '⚠️  DEBUG: Analysis already completed for today (use force=true to override)',
          );
          return;
        }
      }

      print('📊 DEBUG: Analyzing nutrition data for $dateString...');

      // Perform the analysis
      final result = await NutritionAnalysisService.analyzeDailyNutrition(
        dateString,
      );

      if (result != null) {
        print('✅ DEBUG: Daily analysis completed successfully');
        print(
          '💡 DEBUG: Generated ${result['suggestions']?.length ?? 0} suggestions',
        );
        print(
          '🎯 DEBUG: Motivational quote: ${result['motivationalQuote'] ?? 'None'}',
        );

        // Send completion notification
        await _sendAnalysisCompletedNotification(dateString);
        print('📱 DEBUG: Analysis completion notification sent');
      } else {
        print('❌ DEBUG: Daily analysis failed - no data for today');
      }
    } catch (e) {
      print('❌ DEBUG: Error performing daily analysis: $e');
    }
  }

  /// Manual trigger for weekly AI analysis (DEBUG ONLY)
  static Future<void> debugPerformWeeklyAnalysis({
    String? customWeekStart,
  }) async {
    print('🐛 DEBUG: Manually performing weekly analysis...');

    try {
      // Get the start of this week (Monday) or use custom date
      String weekStartString;
      if (customWeekStart != null) {
        weekStartString = customWeekStart;
        print('📅 DEBUG: Using custom week start: $customWeekStart');
      } else {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        weekStartString =
            '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
        print('📅 DEBUG: Using current week start: $weekStartString');
      }

      print('📊 DEBUG: Generating weekly summary...');

      // Perform the weekly analysis
      final result = await NutritionAnalysisService.generateWeeklySummary(
        weekStartString,
      );

      if (result != null) {
        print('✅ DEBUG: Weekly analysis completed successfully');
        print('📈 DEBUG: Summary data: ${result['summary']}');
        print(
          '💡 DEBUG: Generated ${result['insights']?.length ?? 0} insights',
        );
        print(
          '🎯 DEBUG: Generated ${result['recommendations']?.length ?? 0} recommendations',
        );

        // Send completion notification
        await _sendWeeklyAnalysisCompletedNotification(weekStartString);
        print('📱 DEBUG: Weekly analysis completion notification sent');
      } else {
        print('❌ DEBUG: Weekly analysis failed');
      }
    } catch (e) {
      print('❌ DEBUG: Error performing weekly analysis: $e');
    }
  }

  /// Show all scheduled notifications (DEBUG ONLY)
  static Future<void> debugShowScheduledNotifications() async {
    if (!_isInitialized) await initialize();

    print('🐛 DEBUG: Checking scheduled notifications...');

    try {
      final pendingNotifications =
          await _notifications.pendingNotificationRequests();

      if (pendingNotifications.isEmpty) {
        print('📱 DEBUG: No pending notifications found');
      } else {
        print(
          '📱 DEBUG: Found ${pendingNotifications.length} pending notifications:',
        );
        for (var notification in pendingNotifications) {
          print('   - ID: ${notification.id}, Title: ${notification.title}');
        }
      }
    } catch (e) {
      print('❌ DEBUG: Error checking notifications: $e');
    }
  }

  /// Complete debug test suite (DEBUG ONLY)
  static Future<void> debugFullTestSuite() async {
    print('\n${'=' * 60}');
    print('🧪 DEBUG: Starting full AI nutrition test suite...');
    print('=' * 60);

    // Test 1: Check system readiness
    print('\n1️⃣  Testing system readiness...');
    final hasApiKey = await SettingsService.hasGeminiApiKey();
    final hasProfile = await SettingsService.hasCompleteProfile();
    final hasData = await NutritionAnalysisService.hasEnoughDataForAnalysis();

    print('   API Key: ${hasApiKey ? '✅' : '❌'}');
    print('   Complete Profile: ${hasProfile ? '✅' : '❌'}');
    print('   Enough Data: ${hasData ? '✅' : '❌'}');

    // Test 2: Send test notifications
    print('\n2️⃣  Testing notifications...');
    await debugTriggerDailyNotification();
    await Future.delayed(const Duration(seconds: 1));
    await debugTriggerWeeklyNotification();
    await Future.delayed(const Duration(seconds: 1));
    await debugTriggerDailySummaryNotification();
    await Future.delayed(const Duration(seconds: 1));
    await debugTriggerFastingNotifications();
    await showTestNotification();

    // Test 3: Perform analysis if possible
    if (hasApiKey && hasProfile) {
      print('\n3️⃣  Testing AI analysis...');
      await debugPerformDailyAnalysis(force: true);
      await Future.delayed(Duration(seconds: 2));
      await debugPerformWeeklyAnalysis();
    } else {
      print('\n3️⃣  Skipping AI analysis - requirements not met');
    }

    // Test 4: Check scheduled notifications
    print('\n4️⃣  Checking scheduled notifications...');
    await debugShowScheduledNotifications();

    print('\n${'=' * 60}');
    print('🎉 DEBUG: Test suite completed!');
    print('=' * 60 + '\n');
  }
}

class _DailySummaryNotificationData {
  const _DailySummaryNotificationData({
    required this.scheduledTime,
    required this.summaryDateString,
    required this.compactSummary,
    required this.bigText,
  });

  final tz.TZDateTime scheduledTime;
  final String summaryDateString;
  final String compactSummary;
  final String bigText;
}
