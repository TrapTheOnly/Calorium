import 'package:flutter/foundation.dart';
import 'scheduler_service.dart';
import 'nutrition_analysis_service.dart';
import 'settings_service.dart';

/// Debug Service for AI Nutrition Analysis Testing
///
/// This service provides easy-to-use debug commands that can be called
/// from the Flutter console during development and testing.
///
/// All methods are only available in debug mode and include comprehensive
/// logging to help track the testing process.

class DebugService {
  /// ==========================================
  /// QUICK COMMAND METHODS FOR FLUTTER CONSOLE
  /// ==========================================

  /// Quick command: Test basic notification
  /// Usage in Flutter console: DebugService.n()
  static Future<void> n() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Basic Notification');
    await SchedulerService.showTestNotification();
  }

  /// Quick command: Test daily notification
  /// Usage in Flutter console: DebugService.nd()
  static Future<void> nd() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Daily Notification');
    await SchedulerService.debugTriggerDailyNotification();
  }

  /// Quick command: Test weekly notification
  /// Usage in Flutter console: DebugService.nw()
  static Future<void> nw() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Weekly Notification');
    await SchedulerService.debugTriggerWeeklyNotification();
  }

  /// Quick command: Test daily summary notification
  /// Usage in Flutter console: DebugService.ns()
  static Future<void> ns() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Daily Summary Notification');
    await SchedulerService.debugTriggerDailySummaryNotification();
  }

  /// Quick command: Refresh fasting notification schedule
  /// Usage in Flutter console: DebugService.nf()
  static Future<void> nf() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Fasting Notifications Refresh');
    await SchedulerService.debugTriggerFastingNotifications();
  }

  /// Quick command: Perform daily analysis
  /// Usage in Flutter console: DebugService.ad()
  static Future<void> ad() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Daily Analysis');
    await SchedulerService.debugPerformDailyAnalysis(force: true);
  }

  /// Quick command: Perform weekly analysis
  /// Usage in Flutter console: DebugService.aw()
  static Future<void> aw() async {
    if (!kDebugMode) return;
    print('🚀 Quick Test: Weekly Analysis');
    await SchedulerService.debugPerformWeeklyAnalysis();
  }

  /// Quick command: Run full test suite
  /// Usage in Flutter console: DebugService.all()
  static Future<void> all() async {
    if (!kDebugMode) return;
    await SchedulerService.debugFullTestSuite();
  }

  /// Quick command: Check system status
  /// Usage in Flutter console: DebugService.status()
  static Future<void> status() async {
    if (!kDebugMode) return;
    await _checkSystemStatus();
  }

  /// ==========================================
  /// DETAILED COMMAND METHODS
  /// ==========================================

  /// Test all notifications in sequence
  static Future<void> testAllNotifications() async {
    if (!kDebugMode) return;

    print('\n🔔 Testing All Notifications...\n');

    print('1️⃣  Sending basic test notification...');
    await SchedulerService.showTestNotification();
    await Future.delayed(const Duration(seconds: 2));

    print('2️⃣  Running daily analysis notification pathway...');
    await SchedulerService.debugTriggerDailyNotification();
    await Future.delayed(const Duration(seconds: 2));

    print('3️⃣  Running weekly analysis notification pathway...');
    await SchedulerService.debugTriggerWeeklyNotification();
    await Future.delayed(const Duration(seconds: 2));

    print('4️⃣  Showing daily summary notification...');
    await SchedulerService.debugTriggerDailySummaryNotification();
    await Future.delayed(const Duration(seconds: 2));

    print('5️⃣  Refreshing fasting notification schedule...');
    await SchedulerService.debugTriggerFastingNotifications();

    print('✅ Notification tests complete!\n');
  }

  /// Test all AI analysis functions
  static Future<void> testAllAnalysis() async {
    if (!kDebugMode) return;

    print('\n🧠 Testing All AI Analysis Functions...\n');

    // Check prerequisites
    final hasApiKey = await SettingsService.hasGeminiApiKey();
    final hasProfile = await SettingsService.hasCompleteProfile();

    if (!hasApiKey) {
      print('❌ No API key configured. Please add Gemini API key in settings.');
      return;
    }

    if (!hasProfile) {
      print('❌ Incomplete profile. Please complete profile in settings.');
      return;
    }

    print('1️⃣  Performing daily analysis...');
    await SchedulerService.debugPerformDailyAnalysis(force: true);
    await Future.delayed(Duration(seconds: 3));

    print('2️⃣  Performing weekly analysis...');
    await SchedulerService.debugPerformWeeklyAnalysis();

    print('✅ All analysis tests completed!\n');
  }

  /// Check complete system status
  static Future<void> _checkSystemStatus() async {
    print('\n📊 AI Nutrition System Status Report\n');
    print('=' * 50);

    // API Configuration
    final hasApiKey = await SettingsService.hasGeminiApiKey();
    print('🔑 API Key Configured: ${hasApiKey ? '✅ Yes' : '❌ No'}');

    // Profile Completeness
    final hasProfile = await SettingsService.hasCompleteProfile();
    print('👤 Profile Complete: ${hasProfile ? '✅ Yes' : '❌ No'}');

    if (hasProfile) {
      final age = await SettingsService.getAge();
      final weight = await SettingsService.getWeight();
      final height = await SettingsService.getHeight();
      final sex = await SettingsService.getSex();
      final activityLevel = await SettingsService.getActivityLevel();
      final goals = await SettingsService.getGoals();

      print('   • Age: ${age ?? 'Not set'}');
      print('   • Weight: ${weight ?? 'Not set'}kg');
      print('   • Height: ${height ?? 'Not set'}cm');
      print('   • Sex: ${sex ?? 'Not set'}');
      print('   • Activity: $activityLevel');
      print('   • Goals: $goals');
    }

    // Data Availability
    final hasData = await NutritionAnalysisService.hasEnoughDataForAnalysis();
    print('📈 Enough Data (3+ days): ${hasData ? '✅ Yes' : '❌ No'}');

    // Macro Targets
    final macroTargets = await SettingsService.getMacroTargets();
    if (macroTargets != null) {
      print('🎯 Macro Targets Set: ✅ Yes');
      print('   • Protein: ${macroTargets['protein']}g');
      print('   • Carbs: ${macroTargets['carbs']}g');
      print('   • Fat: ${macroTargets['fat']}g');
    } else {
      print('🎯 Macro Targets Set: ❌ No');
    }

    // Last Analysis Dates
    final lastAnalysisDate = await SettingsService.getLastAiAnalysisDate();
    print('📅 Last Daily Analysis: ${lastAnalysisDate ?? 'Never'}');

    // System Readiness
    final isReady = hasApiKey && hasProfile && hasData;
    print('\n🚀 System Ready for AI Analysis: ${isReady ? '✅ YES' : '❌ NO'}');

    if (!isReady) {
      print('\n⚠️  Setup Required:');
      if (!hasApiKey) print('   • Add Gemini AI API key in Settings');
      if (!hasProfile) print('   • Complete user profile in Settings');
      if (!hasData) print('   • Add food entries for at least 3 days');
    }

    print('=' * 50 + '\n');
  }

  /// ==========================================
  /// SCENARIO-SPECIFIC TESTING
  /// ==========================================

  /// Test specific date analysis
  static Future<void> testDateAnalysis(String date) async {
    if (!kDebugMode) return;

    print('\n📅 Testing Analysis for Specific Date: $date\n');

    try {
      final result = await NutritionAnalysisService.analyzeDailyNutrition(date);

      if (result != null) {
        print('✅ Analysis successful for $date');
        print('💡 Suggestions: ${result['suggestions']?.length ?? 0}');
        print('🎯 Quote: ${result['motivationalQuote'] ?? 'None'}');

        if (result['suggestions'] != null) {
          final suggestions = result['suggestions'] as List;
          for (int i = 0; i < suggestions.length; i++) {
            print('   ${i + 1}. ${suggestions[i]}');
          }
        }
      } else {
        print('❌ Analysis failed for $date - no data available');
      }
    } catch (e) {
      print('❌ Error analyzing $date: $e');
    }

    print('');
  }

  /// Test weekly analysis for specific week
  static Future<void> testWeekAnalysis(String weekStartDate) async {
    if (!kDebugMode) return;

    print('\n📊 Testing Weekly Analysis for Week: $weekStartDate\n');

    try {
      final result = await NutritionAnalysisService.generateWeeklySummary(
        weekStartDate,
      );

      if (result != null) {
        print('✅ Weekly analysis successful');
        print('📈 Summary: ${result['summary']}');
        print('💡 Insights: ${result['insights']?.length ?? 0}');
        print('🎯 Recommendations: ${result['recommendations']?.length ?? 0}');
        print('📝 Quote: ${result['weeklyQuote'] ?? 'None'}');
      } else {
        print('❌ Weekly analysis failed');
      }
    } catch (e) {
      print('❌ Error in weekly analysis: $e');
    }

    print('');
  }

  /// ==========================================
  /// HELPER METHODS FOR CONSOLE USAGE
  /// ==========================================

  /// Show all available debug commands
  static void help() {
    if (!kDebugMode) return;

    print('\n${'=' * 60}');
    print('🧪 DEBUG SERVICE - Available Commands');
    print('=' * 60);
    print('\n📱 QUICK NOTIFICATIONS:');
    print('  DebugService.n()   - Test basic notification');
    print('  DebugService.nd()  - Test daily notification');
    print('  DebugService.nw()  - Test weekly notification');
    print('\n🧠 QUICK AI ANALYSIS:');
    print('  DebugService.ad()  - Perform daily analysis');
    print('  DebugService.aw()  - Perform weekly analysis');
    print('\n🔍 SYSTEM STATUS:');
    print('  DebugService.status() - Check system status');
    print('  DebugService.all()    - Run full test suite');
    print('\n📅 SPECIFIC TESTING:');
    print('  DebugService.testDateAnalysis("2024-01-15")');
    print('  DebugService.testWeekAnalysis("2024-01-08")');
    print('\n🔧 COMPREHENSIVE TESTS:');
    print('  DebugService.testAllNotifications()');
    print('  DebugService.testAllAnalysis()');
    print(
      '\n💡 TIP: Use short commands (n, nd, nw, ad, aw) for quick testing!',
    );
    print('=' * 60 + '\n');
  }

  /// Get today's date string for convenience
  static String get today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get this week's Monday date string for convenience
  static String get thisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}
