import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'nutrition_analysis_service.dart';
import 'settings_service.dart';

class SchedulerService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize the notification system
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
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

      await _notifications.initialize(initSettings);

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

  /// Schedule daily AI analysis at 10 PM
  static Future<void> scheduleDailyAnalysis() async {
    try {
      if (!_isInitialized) await initialize();

      // Cancel existing daily notifications with error handling
      try {
        await _notifications.cancel(1000);
      } catch (e) {
        print('Warning: Could not cancel existing notification: $e');
      }

      // Check if user has API key and complete profile
      final hasApiKey = await SettingsService.hasGeminiApiKey();
      final hasCompleteProfile = await SettingsService.hasCompleteProfile();

      if (!hasApiKey || !hasCompleteProfile) {
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

      try {
        await _notifications.zonedSchedule(
          1000, // Unique ID for daily analysis
          'Daily Nutrition Analysis Ready',
          'Your AI nutrition insights are ready! Tap to view personalized suggestions.',
          tz.TZDateTime.from(scheduledDate, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_analysis',
              'Daily Nutrition Analysis',
              channelDescription: 'Daily AI nutrition analysis notifications',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_calorium',
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'daily_analysis',
            ),
          ),
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
            1000, // Unique ID for daily analysis
            'Daily Nutrition Analysis Ready',
            'Your AI nutrition insights are ready! Tap to view personalized suggestions.',
            tz.TZDateTime.from(scheduledDate, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'daily_analysis',
                'Daily Nutrition Analysis',
                channelDescription: 'Daily AI nutrition analysis notifications',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_calorium',
                largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              ),
              iOS: DarwinNotificationDetails(
                categoryIdentifier: 'daily_analysis',
              ),
            ),
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

  /// Schedule weekly analysis notification (Sundays at 8 PM)
  static Future<void> scheduleWeeklyAnalysis() async {
    try {
      if (!_isInitialized) await initialize();

      // Cancel existing weekly notifications with error handling
      try {
        await _notifications.cancel(2000);
      } catch (e) {
        print('Warning: Could not cancel existing weekly notification: $e');
      }

      // Check if user has API key and complete profile
      final hasApiKey = await SettingsService.hasGeminiApiKey();
      final hasCompleteProfile = await SettingsService.hasCompleteProfile();

      if (!hasApiKey || !hasCompleteProfile) {
        return; // Don't schedule if requirements not met
      }

      // Schedule for next Sunday at 8 PM
      final now = DateTime.now();
      var nextSunday = now.add(Duration(days: 7 - now.weekday));
      nextSunday = DateTime(
        nextSunday.year,
        nextSunday.month,
        nextSunday.day,
        20,
        0,
      ); // 8 PM Sunday

      try {
        await _notifications.zonedSchedule(
          2000, // Unique ID for weekly analysis
          'Weekly Nutrition Summary Ready',
          'Your weekly nutrition report is ready! See how you\'ve been doing.',
          tz.TZDateTime.from(nextSunday, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'weekly_analysis',
              'Weekly Nutrition Summary',
              channelDescription: 'Weekly nutrition summary notifications',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_calorium',
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
            iOS: DarwinNotificationDetails(
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
            2000, // Unique ID for weekly analysis
            'Weekly Nutrition Summary Ready',
            'Your weekly nutrition report is ready! See how you\'ve been doing.',
            tz.TZDateTime.from(nextSunday, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'weekly_analysis',
                'Weekly Nutrition Summary',
                channelDescription: 'Weekly nutrition summary notifications',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_calorium',
                largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              ),
              iOS: DarwinNotificationDetails(
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
        await _sendAnalysisCompletedNotification();
      } else {
        print('Daily analysis failed - no data for today');
      }
    } catch (e) {
      print('Error performing daily analysis: $e');
    }
  }

  /// Send notification when analysis is completed
  static Future<void> _sendAnalysisCompletedNotification() async {
    if (!_isInitialized) await initialize();

    await _notifications.show(
      3000, // Unique ID for completion notification
      'Nutrition Insights Ready! 🎯',
      'Your personalized AI suggestions and motivation are waiting for you.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'analysis_completed',
          'Analysis Completed',
          channelDescription: 'Notifications when AI analysis is completed',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'analysis_completed',
        ),
      ),
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
        await _sendWeeklyAnalysisCompletedNotification();
      } else {
        print('Weekly analysis failed');
      }
    } catch (e) {
      print('Error performing weekly analysis: $e');
    }
  }

  /// Send notification when weekly analysis is completed
  static Future<void> _sendWeeklyAnalysisCompletedNotification() async {
    if (!_isInitialized) await initialize();

    await _notifications.show(
      4000, // Unique ID for weekly completion notification
      'Weekly Report Ready! 📊',
      'Your comprehensive nutrition summary and insights for this week are ready.',
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
        print('Notifications scheduled successfully');
      } else {
        print('Skipping notification setup - requirements not met');
      }
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

  /// Show/update a persistent notification while the eating window is active
  static Future<void> showEatingWindowNotification({
    required Duration timeRemaining,
    required bool isActive,
  }) async {
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
      print('Error showing eating window notification: $e');
    }
  }

  /// Show a test notification (for debugging)
  static Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();

    await _notifications.show(
      9999,
      'Test Notification',
      'This is a test notification from Calorie Tracker',
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
    );
  }

  // ========================================
  // DEBUG METHODS FOR MANUAL TESTING
  // ========================================

  /// Manual trigger for daily analysis notification (DEBUG ONLY)
  static Future<void> debugTriggerDailyNotification() async {
    if (!_isInitialized) await initialize();

    print('🐛 DEBUG: Manually triggering daily analysis notification...');

    await _notifications.show(
      1001, // Different ID from scheduled notification
      'Daily Nutrition Analysis Ready (DEBUG)',
      'Manual trigger: Your AI nutrition insights are ready! Tap to view personalized suggestions.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_daily_analysis',
          'Debug Daily Analysis',
          channelDescription: 'Debug daily AI nutrition analysis notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'debug_daily_analysis',
        ),
      ),
    );

    print('✅ DEBUG: Daily notification sent');
  }

  /// Manual trigger for weekly analysis notification (DEBUG ONLY)
  static Future<void> debugTriggerWeeklyNotification() async {
    if (!_isInitialized) await initialize();

    print('🐛 DEBUG: Manually triggering weekly analysis notification...');

    await _notifications.show(
      2001, // Different ID from scheduled notification
      'Weekly Nutrition Summary Ready (DEBUG)',
      'Manual trigger: Your weekly nutrition report is ready! See how you\'ve been doing.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_weekly_analysis',
          'Debug Weekly Analysis',
          channelDescription: 'Debug weekly nutrition summary notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_calorium',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'debug_weekly_analysis',
        ),
      ),
    );

    print('✅ DEBUG: Weekly notification sent');
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
        await _sendAnalysisCompletedNotification();
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
        await _sendWeeklyAnalysisCompletedNotification();
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
    await Future.delayed(Duration(seconds: 1));
    await debugTriggerWeeklyNotification();
    await Future.delayed(Duration(seconds: 1));
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
