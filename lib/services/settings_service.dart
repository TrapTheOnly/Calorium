import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/fasting_settings.dart';

class SettingsService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _geminiModelKey = 'gemini_model';
  static const String _defaultGeminiModel = 'gemini-2.0-flash';
  static const String _themeKey = 'theme_mode';
  static const String _calorieTargetKey = 'calorie_target';
  static const String _ageKey = 'age';
  static const String _weightKey = 'weight';
  static const String _heightKey = 'height';
  static const String _sexKey = 'sex';
  static const String _activityLevelKey = 'activity_level';
  static const String _goalsKey = 'goals';
  static const String _proteinTargetKey = 'protein_target';
  static const String _fatTargetKey = 'fat_target';
  static const String _carbTargetKey = 'carb_target';
  static const String _dailyAiSuggestionsKey = 'daily_ai_suggestions';
  static const String _lastAiAnalysisDateKey = 'last_ai_analysis_date';
  static const String _aiQuoteKey = 'ai_quote';
  static const String _weeklyAnalysisKey = 'weekly_analysis';
  static const String _fastingNotificationsKey =
      'fasting_notifications_enabled';
  static const String _dailySummaryNotificationsKey =
      'daily_summary_notifications_enabled';
  static const String _dailySummaryTimeKey =
      'daily_summary_notification_minutes';
  static const String _weeklyAnalysisNotificationsKey =
      'weekly_analysis_notifications_enabled';
  static const String _weeklyAnalysisTimeKey =
      'weekly_analysis_notification_minutes';

  // API Key methods
  static Future<void> setGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  static Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  static Future<void> removeGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
  }

  static Future<bool> hasGeminiApiKey() async {
    final apiKey = await getGeminiApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  static String get defaultGeminiModel => _defaultGeminiModel;

  static Future<void> setGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiModelKey, normalizeGeminiModelName(model));
  }

  static Future<String> getGeminiModel({String? fallbackModel}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_geminiModelKey);
    if (stored != null && stored.isNotEmpty) {
      return normalizeGeminiModelName(stored);
    }
    return normalizeGeminiModelName(fallbackModel ?? _defaultGeminiModel);
  }

  static Future<String?> getSavedGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_geminiModelKey);
    if (stored == null) return null;
    return normalizeGeminiModelName(stored);
  }

  static String normalizeGeminiModelName(String model) {
    final trimmed = model.trim();
    if (trimmed.startsWith('models/')) {
      return trimmed.substring(7);
    }
    return trimmed;
  }

  // Theme methods
  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  // User profile methods
  static Future<void> setCalorieTarget(double target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_calorieTargetKey, target);
  }

  static Future<double?> getCalorieTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_calorieTargetKey);
  }

  static Future<void> setAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ageKey, age);
  }

  static Future<int?> getAge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ageKey);
  }

  static Future<void> setWeight(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_weightKey, weight);
  }

  static Future<double?> getWeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_weightKey);
  }

  static Future<void> setHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_heightKey, height);
  }

  static Future<double?> getHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_heightKey);
  }

  static Future<void> setSex(String sex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sexKey, sex);
  }

  static Future<String?> getSex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sexKey);
  }

  static Future<void> setActivityLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activityLevelKey, level);
  }

  static Future<String> getActivityLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activityLevelKey) ?? 'moderate';
  }

  static Future<void> setGoals(String goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalsKey, goals);
  }

  static Future<String> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_goalsKey) ?? 'maintenance';
  }

  // Manual macro targets (no AI calculation)
  static Future<void> setMacroTargets(
    double protein,
    double carbs,
    double fat,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_proteinTargetKey, protein);
    await prefs.setDouble(_carbTargetKey, carbs);
    await prefs.setDouble(_fatTargetKey, fat);

    // Calculate and set calorie target based on macros
    final calories = (protein * 4) + (carbs * 4) + (fat * 9);
    await prefs.setDouble(_calorieTargetKey, calories);
  }

  // Get stored macro targets
  static Future<Map<String, double>?> getMacroTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final protein = prefs.getDouble(_proteinTargetKey);
    final fat = prefs.getDouble(_fatTargetKey);
    final carbs = prefs.getDouble(_carbTargetKey);

    if (protein != null && fat != null && carbs != null) {
      return {'protein': protein, 'fat': fat, 'carbs': carbs};
    }

    return null;
  }

  // Notification preferences
  static Future<void> setFastingNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fastingNotificationsKey, enabled);
  }

  static Future<bool> getFastingNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fastingNotificationsKey) ?? false;
  }

  static Future<void> setDailySummaryNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailySummaryNotificationsKey, enabled);
  }

  static Future<bool> getDailySummaryNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dailySummaryNotificationsKey) ?? true;
  }

  static Future<void> setDailySummaryNotificationTimeMinutes(
    int minutes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _dailySummaryTimeKey,
      minutes.clamp(0, FastingSettings.minutesPerDay - 1),
    );
  }

  static Future<int> getDailySummaryNotificationTimeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailySummaryTimeKey) ?? (22 * 60); // 10:00 PM
  }

  static Future<void> setWeeklyAnalysisNotificationsEnabled(
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklyAnalysisNotificationsKey, enabled);
  }

  static Future<bool> getWeeklyAnalysisNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_weeklyAnalysisNotificationsKey) ?? false;
  }

  static Future<void> setWeeklyAnalysisNotificationTimeMinutes(
    int minutes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _weeklyAnalysisTimeKey,
      minutes.clamp(0, FastingSettings.minutesPerDay - 1),
    );
  }

  static Future<int> getWeeklyAnalysisNotificationTimeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_weeklyAnalysisTimeKey) ?? (18 * 60); // 6:00 PM
  }

  // Check if we have complete profile for AI analysis
  static Future<bool> hasCompleteProfile() async {
    final age = await getAge();
    final weight = await getWeight();
    final height = await getHeight();
    final sex = await getSex();

    return age != null && weight != null && height != null && sex != null;
  }

  // AI Nutrition Analysis methods
  static Future<void> setDailyAiSuggestions(
    String date,
    List<String> suggestions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_dailyAiSuggestionsKey}_$date',
      json.encode(suggestions),
    );
  }

  static Future<List<String>?> getDailyAiSuggestions(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final suggestionsString = prefs.getString(
      '${_dailyAiSuggestionsKey}_$date',
    );

    if (suggestionsString != null) {
      try {
        final List<dynamic> suggestionsList = json.decode(suggestionsString);
        return suggestionsList.cast<String>();
      } catch (e) {
        print('Error parsing daily AI suggestions: $e');
        return null;
      }
    }

    return null;
  }

  static Future<void> setLastAiAnalysisDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAiAnalysisDateKey, date);
  }

  static Future<String?> getLastAiAnalysisDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastAiAnalysisDateKey);
  }

  static Future<void> setAiQuote(String quote) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiQuoteKey, quote);
  }

  static Future<String?> getAiQuote() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiQuoteKey);
  }

  static Future<void> setWeeklyAnalysis(
    String weekKey,
    Map<String, dynamic> analysis,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_weeklyAnalysisKey}_$weekKey',
      json.encode(analysis),
    );
  }

  static Future<Map<String, dynamic>?> getWeeklyAnalysis(String weekKey) async {
    final prefs = await SharedPreferences.getInstance();
    final analysisString = prefs.getString('${_weeklyAnalysisKey}_$weekKey');

    if (analysisString != null) {
      try {
        return json.decode(analysisString) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing weekly analysis: $e');
        return null;
      }
    }

    return null;
  }
}
