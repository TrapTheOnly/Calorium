import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';
import 'dart:convert';

class SettingsService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _themeKey = 'theme_mode';
  static const String _calorieTargetKey = 'calorie_target';
  static const String _ageKey = 'age';
  static const String _weightKey = 'weight';
  static const String _sexKey = 'sex';
  static const String _activityLevelKey = 'activity_level';
  static const String _goalsKey = 'goals';
  static const String _proteinTargetKey = 'protein_target';
  static const String _fatTargetKey = 'fat_target';
  static const String _carbTargetKey = 'carb_target';
  static const String _lastAiResponseKey = 'last_ai_response';

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

  // AI-powered macro target calculation
  static Future<Map<String, double>?> calculateMacroTargets() async {
    try {
      final calorieTarget = await getCalorieTarget();
      final age = await getAge();
      final weight = await getWeight();
      final sex = await getSex();
      final activityLevel = await getActivityLevel();
      final goals = await getGoals();

      if (calorieTarget == null || age == null || weight == null || sex == null) {
        return null; // Missing required profile data
      }

      final aiResponse = await AiService.calculatePersonalizedTargets(
        calorieTarget: calorieTarget,
        age: age,
        weight: weight,
        sex: sex,
        activityLevel: activityLevel,
        goals: goals,
      );

      if (aiResponse != null) {
        // Store the AI-calculated targets
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_proteinTargetKey, aiResponse['protein']?.toDouble() ?? 0.0);
        await prefs.setDouble(_fatTargetKey, aiResponse['fat']?.toDouble() ?? 0.0);
        await prefs.setDouble(_carbTargetKey, aiResponse['carbs']?.toDouble() ?? 0.0);
        
        // Calculate actual calories from macros and update calorie target
        final protein = aiResponse['protein']?.toDouble() ?? 0.0;
        final fat = aiResponse['fat']?.toDouble() ?? 0.0;
        final carbs = aiResponse['carbs']?.toDouble() ?? 0.0;
        final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);
        
        // Update calorie target to match calculated macros
        await prefs.setDouble(_calorieTargetKey, calculatedCalories);
        
        // Store the full AI response for display
        await prefs.setString(_lastAiResponseKey, json.encode(aiResponse));

        return {
          'protein': protein,
          'fat': fat,
          'carbs': carbs,
        };
      }
    } catch (e) {
      print('Error calculating AI macro targets: $e');
    }

    return null;
  }

  // Get stored macro targets
  static Future<Map<String, double>?> getMacroTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final protein = prefs.getDouble(_proteinTargetKey);
    final fat = prefs.getDouble(_fatTargetKey);
    final carbs = prefs.getDouble(_carbTargetKey);

    if (protein != null && fat != null && carbs != null) {
      return {
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      };
    }

    return null;
  }

  // Set custom macro targets (for manual override)
  static Future<void> setCustomMacroTargets(double protein, double carbs, double fat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_proteinTargetKey, protein);
    await prefs.setDouble(_carbTargetKey, carbs);
    await prefs.setDouble(_fatTargetKey, fat);
  }

  // Check if we have complete profile for macro calculation
  static Future<bool> hasCompleteProfile() async {
    final calorieTarget = await getCalorieTarget();
    final age = await getAge();
    final weight = await getWeight();
    final sex = await getSex();

    return calorieTarget != null && age != null && weight != null && sex != null;
  }

  // Get stored AI response for justification display
  static Future<Map<String, dynamic>?> getLastAiResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final responseString = prefs.getString(_lastAiResponseKey);
    
    if (responseString != null) {
      try {
        return json.decode(responseString) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing stored AI response: $e');
        return null;
      }
    }
    
    return null;
  }
} 