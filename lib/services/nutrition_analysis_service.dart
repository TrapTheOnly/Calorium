import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'log_service.dart';

class NutritionAnalysisService {
  static const String _apiHost = 'generativelanguage.googleapis.com';
  static const String _pathPrefix = '/v1beta/models/';
  static const String _generateContentSuffix = ':generateContent';

  static Future<Uri> _buildRequestUri(
    String apiKey, {
    String fallbackModel = 'gemini-1.5-flash-latest',
  }) async {
    final model = await SettingsService.getGeminiModel(
      fallbackModel: fallbackModel,
    );
    final normalized = SettingsService.normalizeGeminiModelName(model);
    return Uri.https(
      _apiHost,
      '$_pathPrefix$normalized$_generateContentSuffix',
      {'key': apiKey},
    );
  }

  /// Analyzes daily nutrition intake and generates 5 personalized suggestions plus a motivational quote
  static Future<Map<String, dynamic>?> analyzeDailyNutrition(
    String date,
  ) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'API key not set. Please configure your Gemini AI API key in settings.',
        );
      }

      // Check if user has complete profile
      if (!await SettingsService.hasCompleteProfile()) {
        throw Exception(
          'Incomplete profile. Please fill in all profile information in settings.',
        );
      }

      // Get user profile data
      final age = await SettingsService.getAge();
      final weight = await SettingsService.getWeight();
      final height = await SettingsService.getHeight();
      final sex = await SettingsService.getSex();
      final activityLevel = await SettingsService.getActivityLevel();
      final goals = await SettingsService.getGoals();
      final macroTargets = await SettingsService.getMacroTargets();

      // Get nutrition data for the specified date
      final logService = LogService();
      final entries = await logService.getLogEntriesByDate(date);

      if (entries.isEmpty) {
        return null; // No data to analyze
      }

      // Calculate daily totals
      double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
      List<Map<String, dynamic>> foodDetails = [];

      for (var entry in entries) {
        final entryCalories = (entry.calories! * entry.amount / 100);
        final entryProtein = (entry.protein! * entry.amount / 100);
        final entryCarbs = (entry.carbs! * entry.amount / 100);
        final entryFat = (entry.fat! * entry.amount / 100);

        totalCalories += entryCalories;
        totalProtein += entryProtein;
        totalCarbs += entryCarbs;
        totalFat += entryFat;

        foodDetails.add({
          'name': entry.foodName,
          'amount': entry.amount,
          'calories': entryCalories.round(),
          'protein': entryProtein.round(),
          'carbs': entryCarbs.round(),
          'fat': entryFat.round(),
        });
      }

      // Get last few days data for performance context
      List<Map<String, double>> recentDaysData = [];
      final now = DateTime.parse(date);
      for (int i = 1; i <= 3; i++) {
        final pastDate = now.subtract(Duration(days: i));
        final pastDateString =
            '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-${pastDate.day.toString().padLeft(2, '0')}';
        final pastEntries = await logService.getLogEntriesByDate(
          pastDateString,
        );

        double pastCalories = 0, pastProtein = 0, pastCarbs = 0, pastFat = 0;
        for (var entry in pastEntries) {
          pastCalories += (entry.calories! * entry.amount / 100);
          pastProtein += (entry.protein! * entry.amount / 100);
          pastCarbs += (entry.carbs! * entry.amount / 100);
          pastFat += (entry.fat! * entry.amount / 100);
        }

        recentDaysData.add({
          'calories': pastCalories,
          'protein': pastProtein,
          'carbs': pastCarbs,
          'fat': pastFat,
        });
      }

      // Remaining vs targets — the most useful signal for actionable tips.
      final proteinTarget = macroTargets?['protein'];
      final carbsTarget = macroTargets?['carbs'];
      final fatTarget = macroTargets?['fat'];
      final calorieTargetD = macroTargets != null
          ? (proteinTarget! * 4 + carbsTarget! * 4 + fatTarget! * 9)
          : null;
      String remain(double target, double have) {
        final r = target - have;
        return r >= 0 ? '${r.round()}g left' : '${(-r).round()}g over';
      }

      final gapsSection = macroTargets != null
          ? 'REMAINING VS TARGET (today):\n'
              '- Calories: ${(calorieTargetD! - totalCalories).round()} kcal '
              '${calorieTargetD - totalCalories >= 0 ? 'left' : 'over'}\n'
              '- Protein: ${remain(proteinTarget!, totalProtein)}\n'
              '- Carbs: ${remain(carbsTarget!, totalCarbs)}\n'
              '- Fat: ${remain(fatTarget!, totalFat)}'
          : 'Daily targets not set.';

      final hourNow = DateTime.now().hour;
      final mealsLeft = hourNow < 11
          ? 'most of the day remains (breakfast/lunch/dinner ahead)'
          : hourNow < 15
              ? 'lunch and dinner likely remain'
              : hourNow < 20
                  ? 'dinner likely remains'
                  : 'the day is nearly over';

      // Prepare the AI analysis request
      final varietySeed = DateTime.now().millisecondsSinceEpoch;
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
You are a professional nutritionist analyzing a person's daily food intake. Provide personalized nutrition advice and motivation.

USER PROFILE:
- Age: $age years
- Sex: $sex
- Weight: ${weight}kg
- Height: ${height}cm  
- Activity Level: $activityLevel
- Goals: $goals
- Daily Targets: ${macroTargets != null ? 'Protein: ${macroTargets['protein']}g, Carbs: ${macroTargets['carbs']}g, Fat: ${macroTargets['fat']}g' : 'Not set'}

TODAY'S INTAKE ($date):
- Total Calories: ${totalCalories.round()}kcal
- Protein: ${totalProtein.round()}g
- Carbohydrates: ${totalCarbs.round()}g  
- Fat: ${totalFat.round()}g

$gapsSection

TIME CONTEXT: It is ${hourNow}:00 — $mealsLeft.

FOODS CONSUMED TODAY:
${foodDetails.map((food) => '• ${food['name']}: ${food['amount']}g (${food['calories']}kcal, ${food['protein']}g protein, ${food['carbs']}g carbs, ${food['fat']}g fat)').join('\n')}

RECENT PERFORMANCE (last 3 days average):
${recentDaysData.isNotEmpty ? '- Average Calories: ${(recentDaysData.map((d) => d['calories']!).reduce((a, b) => a + b) / recentDaysData.length).round()}kcal\n- Average Protein: ${(recentDaysData.map((d) => d['protein']!).reduce((a, b) => a + b) / recentDaysData.length).round()}g\n- Average Carbs: ${(recentDaysData.map((d) => d['carbs']!).reduce((a, b) => a + b) / recentDaysData.length).round()}g\n- Average Fat: ${(recentDaysData.map((d) => d['fat']!).reduce((a, b) => a + b) / recentDaysData.length).round()}g' : 'No recent data available'}

TASK: Respond with ONLY a valid JSON object in this exact format:

{
  "headline": "One short line summarizing where today's intake stands vs targets.",
  "focus": "The single most important thing to fix right now, specific and grounded in the remaining-vs-target numbers and the time of day.",
  "tips": [
    "Specific, quantified tip #1 (e.g. 'Add 150g Greek yogurt for +15g protein').",
    "Specific, quantified tip #2.",
    "Specific, quantified tip #3."
  ],
  "action": {
    "title": "One concrete food to add now, with amount and its macro effect (e.g. '2 eggs → +12g protein, 140 kcal')."
  },
  "quote": "Short, personal, encouraging line referencing their actual day/goals."
}

GUIDELINES:
1. Ground EVERYTHING in the remaining-vs-target numbers and the time of day — if protein is short and dinner remains, say so.
2. Be specific and quantified (amounts + macro deltas), never generic ("eat more protein" is banned).
3. If they are over on calories, focus tips on lighter choices instead of adding food.
4. "focus" must be the ONE highest-impact change; "action" must be a single realistic food to add (or a swap if they're over).
5. Vary the angle day to day: rotate protein timing, fibre, micronutrients, hydration, meal composition. (variety seed: $varietySeed)
6. Keep each field concise. Respond with ONLY the JSON object, no extra text.
""",
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 1.0,
          "topK": 64,
          "topP": 0.95,
          "maxOutputTokens": 1000,
        },
      };

      // Make the API request
      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-1.5-flash-latest',
      );

      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null) {
          try {
            // Clean the response
            String cleanedText = text.trim();

            // Remove markdown code block markers if present
            if (cleanedText.startsWith('```json')) {
              cleanedText = cleanedText.substring(7);
            } else if (cleanedText.startsWith('```')) {
              cleanedText = cleanedText.substring(3);
            }

            if (cleanedText.endsWith('```')) {
              cleanedText = cleanedText.substring(0, cleanedText.length - 3);
            }

            cleanedText = cleanedText.trim();

            final analysisResult =
                json.decode(cleanedText) as Map<String, dynamic>;

            // Accept the new typed schema (headline/focus/tips/action/quote)
            // and gracefully fall back to the legacy suggestions/quote shape.
            final tips = (analysisResult['tips'] as List?)?.cast<String>() ??
                (analysisResult['suggestions'] as List?)?.cast<String>();
            final quote = (analysisResult['quote'] ??
                analysisResult['motivationalQuote']) as String?;

            if (tips != null && tips.isNotEmpty) {
              // Persist the full typed payload plus back-compat fields.
              await SettingsService.setDailyAiInsights(date, analysisResult);
              await SettingsService.setDailyAiSuggestions(date, tips);
              if (quote != null) await SettingsService.setAiQuote(quote);
              await SettingsService.setLastAiAnalysisDate(date);

              return analysisResult;
            } else {
              throw Exception('Invalid response structure from AI');
            }
          } catch (e) {
            print('Error parsing AI analysis response: $e');
            print('AI Response: $text');
            throw Exception('Invalid response format from AI: $e');
          }
        } else {
          throw Exception('No response from AI');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('API Error: $errorMessage');
      }
    } catch (e) {
      print('Nutrition Analysis Service Error: $e');
      rethrow;
    }
  }

  /// Generates a weekly nutrition summary and analysis
  static Future<Map<String, dynamic>?> generateWeeklySummary(
    String weekStartDate,
  ) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'API key not set. Please configure your Gemini AI API key in settings.',
        );
      }

      // Get user profile data
      final age = await SettingsService.getAge();
      final weight = await SettingsService.getWeight();
      final height = await SettingsService.getHeight();
      final sex = await SettingsService.getSex();
      final activityLevel = await SettingsService.getActivityLevel();
      final goals = await SettingsService.getGoals();
      final macroTargets = await SettingsService.getMacroTargets();

      final logService = LogService();
      final startDate = DateTime.parse(weekStartDate);

      List<Map<String, dynamic>> weeklyData = [];

      // Collect 7 days of data
      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final entries = await logService.getLogEntriesByDate(dateString);

        double dayCalories = 0, dayProtein = 0, dayCarbs = 0, dayFat = 0;
        List<String> foods = [];

        for (var entry in entries) {
          dayCalories += (entry.calories! * entry.amount / 100);
          dayProtein += (entry.protein! * entry.amount / 100);
          dayCarbs += (entry.carbs! * entry.amount / 100);
          dayFat += (entry.fat! * entry.amount / 100);
          foods.add(entry.foodName!);
        }

        weeklyData.add({
          'date': dateString,
          'dayName':
              [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ][date.weekday - 1],
          'calories': dayCalories.round(),
          'protein': dayProtein.round(),
          'carbs': dayCarbs.round(),
          'fat': dayFat.round(),
          'foodsCount': foods.length,
          'foods': foods,
        });
      }

      // Compute deterministic stats here so the model only INTERPRETS them
      // (it must never invent the numbers — that made the old report feel
      // random). Averages are over logged days only.
      final logged =
          weeklyData.where((d) => (d['foodsCount'] as int) > 0).toList();
      final loggedN = logged.length;
      double avgOf(String key) => loggedN == 0
          ? 0
          : logged.map((d) => (d[key] as num).toDouble()).reduce((a, b) => a + b) /
              loggedN;
      final avgCal = avgOf('calories');
      final avgProt = avgOf('protein');
      final avgCarb = avgOf('carbs');
      final avgFat = avgOf('fat');

      final proteinTarget = macroTargets?['protein'];
      final calorieTarget = macroTargets != null
          ? (macroTargets['protein']! * 4 +
              macroTargets['carbs']! * 4 +
              macroTargets['fat']! * 9)
          : null;
      final proteinHits = proteinTarget == null
          ? 0
          : logged.where((d) => (d['protein'] as num) >= proteinTarget).length;
      final calorieOnTarget = calorieTarget == null
          ? 0
          : logged
              .where((d) =>
                  (d['calories'] as num) >= calorieTarget * 0.9 &&
                  (d['calories'] as num) <= calorieTarget * 1.1)
              .length;

      final pK = logged.fold<double>(0, (s, d) => s + (d['protein'] as num) * 4);
      final cK = logged.fold<double>(0, (s, d) => s + (d['carbs'] as num) * 4);
      final fK = logged.fold<double>(0, (s, d) => s + (d['fat'] as num) * 9);
      final tK = pK + cK + fK;
      String macroPct(double x) => tK <= 0 ? '0' : ((x / tK) * 100).round().toString();

      final foodCounts = <String, int>{};
      for (final d in weeklyData) {
        for (final f in (d['foods'] as List)) {
          foodCounts[f as String] = (foodCounts[f] ?? 0) + 1;
        }
      }
      final topFoods = (foodCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(6)
          .map((e) => '${e.key} (${e.value}x)')
          .join(', ');

      // Prepare the weekly analysis request
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
You are a sharp, supportive nutrition coach. You are given ALREADY-COMPUTED weekly statistics. Do NOT recompute or contradict them — interpret them and give grounded, specific advice.

USER PROFILE:
- Age: $age, Sex: $sex, Weight: ${weight}kg, Height: ${height}cm
- Activity: $activityLevel, Goals: $goals
- Daily targets: ${macroTargets != null ? 'Protein ${macroTargets['protein']}g, Carbs ${macroTargets['carbs']}g, Fat ${macroTargets['fat']}g${calorieTarget != null ? ' (~${calorieTarget.round()} kcal)' : ''}' : 'Not set'}

COMPUTED WEEKLY STATS ($weekStartDate to ${startDate.add(Duration(days: 6)).toString().split(' ')[0]}):
- Days logged: $loggedN of 7
- Average per logged day: ${avgCal.round()} kcal, ${avgProt.round()}g protein, ${avgCarb.round()}g carbs, ${avgFat.round()}g fat
- Protein target hit on $proteinHits of $loggedN logged days${calorieTarget != null ? '; calories within +/-10% of target on $calorieOnTarget of $loggedN days' : ''}
- Macro split by calories: ${macroPct(pK)}% protein, ${macroPct(cK)}% carbs, ${macroPct(fK)}% fat
- Most-logged foods: ${topFoods.isEmpty ? 'n/a' : topFoods}
- Per-day intake: ${weeklyData.map((day) => '${(day['dayName'] as String).substring(0, 3)} ${day['calories']}kcal/${day['protein']}gP').join(', ')}

TASK: Respond with ONLY this JSON object:

{
  "pattern": "The single most important, specific pattern this week in one sentence, grounded in the stats above (e.g. 'Protein fell ~30g below target every weekend').",
  "swaps": [
    {"title": "Concrete food B instead of food A (use their most-logged foods when relevant)", "detail": "quantified macro change, e.g. '+18g protein, -70 kcal'"},
    {"title": "Second realistic swap targeting their biggest gap", "detail": "quantified change"}
  ],
  "insights": ["Grounded observation #1", "Grounded observation #2", "Grounded observation #3"],
  "recommendations": ["Actionable next-week step #1", "step #2", "step #3"],
  "quote": "One short, personal, encouraging line referencing their actual week."
}

Rules: be specific and numeric; tie every point to the stats; target the biggest gap (usually the macro furthest from target); no generic filler. Respond with ONLY the JSON object.
""",
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.8,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1200,
        },
      };
      // Make the API request
      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-1.5-flash-latest',
      );

      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null) {
          try {
            String cleanedText = text.trim();

            if (cleanedText.startsWith('```json')) {
              cleanedText = cleanedText.substring(7);
            } else if (cleanedText.startsWith('```')) {
              cleanedText = cleanedText.substring(3);
            }

            if (cleanedText.endsWith('```')) {
              cleanedText = cleanedText.substring(0, cleanedText.length - 3);
            }

            cleanedText = cleanedText.trim();

            final weeklyAnalysis = json.decode(cleanedText);

            // Store the weekly analysis
            final weekKey =
                '${startDate.year}-W${((startDate.difference(DateTime(startDate.year, 1, 1)).inDays) / 7).ceil()}';
            await SettingsService.setWeeklyAnalysis(weekKey, weeklyAnalysis);

            return weeklyAnalysis;
          } catch (e) {
            print('Error parsing weekly analysis response: $e');
            print('AI Response: $text');
            throw Exception('Invalid response format from AI: $e');
          }
        } else {
          throw Exception('No response from AI');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('API Error: $errorMessage');
      }
    } catch (e) {
      print('Weekly Analysis Service Error: $e');
      rethrow;
    }
  }

  /// Checks if user has enough data for AI analysis (3+ days of entries)
  static Future<bool> hasEnoughDataForAnalysis() async {
    final logService = LogService();
    final now = DateTime.now();
    int daysWithData = 0;

    // Check last 7 days for at least 3 days with entries
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final entries = await logService.getLogEntriesByDate(dateString);

      if (entries.isNotEmpty) {
        daysWithData++;
      }
    }

    return daysWithData >= 3;
  }
}
