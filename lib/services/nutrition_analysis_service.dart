import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'log_service.dart';

class NutritionAnalysisService {
  static const String _apiHost = 'generativelanguage.googleapis.com';
  static const String _pathPrefix = '/v1beta/models/';
  static const String _generateContentSuffix = ':generateContent';
  static Never _handleEmptyCandidates(
    Map<String, dynamic> data,
    String context,
  ) {
    final promptFeedback = data['promptFeedback'];
    if (promptFeedback is Map<String, dynamic>) {
      print(
        'Gemini prompt feedback ($context): ${json.encode(promptFeedback)}',
      );
      final blockReason = promptFeedback['blockReason'];
      if (blockReason is String && blockReason.isNotEmpty) {
        throw Exception('Gemini blocked the request: $blockReason');
      }
    }
    throw Exception('No response from AI');
  }

  static String _extractResponseText(
    Map<String, dynamic> data,
    String context,
  ) {
    final candidates = data['candidates'];
    if (candidates == null || candidates is! List || candidates.isEmpty) {
      _handleEmptyCandidates(data, context);
    }

    final firstCandidate = candidates[0];
    if (firstCandidate == null || firstCandidate is! Map<String, dynamic>) {
      throw Exception('Invalid candidate structure');
    }

    final finishReason = firstCandidate['finishReason'];
    if (finishReason is String && finishReason.toUpperCase() == 'SAFETY') {
      _handleEmptyCandidates(data, context);
    }

    final content = firstCandidate['content'];
    if (content == null || content is! Map<String, dynamic>) {
      throw Exception('No content in candidate');
    }

    final parts = content['parts'];
    if (parts == null || parts is! List || parts.isEmpty) {
      if (finishReason == 'MAX_TOKENS') {
        throw Exception(
          'Gemini stopped before returning content because the response hit the maximum output token limit. Try increasing maxOutputTokens or shortening the prompt.',
        );
      }
      if (finishReason is String && finishReason.isNotEmpty) {
        throw Exception(
          'Gemini returned no content (finishReason: $finishReason)',
        );
      }
      throw Exception('No parts in content');
    }

    final firstPart = parts[0];
    if (firstPart == null || firstPart is! Map<String, dynamic>) {
      throw Exception('Invalid part structure');
    }

    final text = firstPart['text'];
    if (text == null || text is! String) {
      throw Exception('No text in response part');
    }

    if (finishReason == 'MAX_TOKENS') {
      print(
        'Gemini truncated the response for $context because it hit the maximum output token limit. Continuing with partial content.',
      );
    }

    return text;
  }

  static Future<Uri> _buildRequestUri(
    String apiKey, {
    String fallbackModel = 'gemini-2.0-flash',
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

      // Prepare the AI analysis request
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

FOODS CONSUMED TODAY:
${foodDetails.map((food) => '• ${food['name']}: ${food['amount']}g (${food['calories']}kcal, ${food['protein']}g protein, ${food['carbs']}g carbs, ${food['fat']}g fat)').join('\n')}

RECENT PERFORMANCE (last 3 days average):
${recentDaysData.isNotEmpty ? '- Average Calories: ${(recentDaysData.map((d) => d['calories']!).reduce((a, b) => a + b) / recentDaysData.length).round()}kcal\n- Average Protein: ${(recentDaysData.map((d) => d['protein']!).reduce((a, b) => a + b) / recentDaysData.length).round()}g\n- Average Carbs: ${(recentDaysData.map((d) => d['carbs']!).reduce((a, b) => a + b) / recentDaysData.length).round()}g\n- Average Fat: ${(recentDaysData.map((d) => d['fat']!).reduce((a, b) => a + b) / recentDaysData.length).round()}g' : 'No recent data available'}

TASK: Analyze this nutrition data and respond with ONLY a valid JSON object in this exact format:

{
  "suggestions": [
    "Specific actionable nutrition tip #1",
    "Specific actionable nutrition tip #2", 
    "Specific actionable nutrition tip #3",
    "Specific actionable nutrition tip #4",
    "Specific actionable nutrition tip #5"
  ],
  "motivationalQuote": "Personalized motivational quote based on their recent performance and goals"
}

GUIDELINES for suggestions:
1. Be specific and actionable (e.g., "Add 150g Greek yogurt for 20g more protein" not "eat more protein")
2. Consider their goals, activity level, and current intake vs targets
3. Address specific deficiencies or excesses you notice
4. Include food timing suggestions if relevant
5. Be encouraging but realistic
6. Focus on nutrition quality, not just quantities
7. Consider food variety and micronutrients
8. Each suggestion should be unique and valuable

GUIDELINES for motivational quote:
1. Make it personal to their recent performance 
2. Acknowledge their progress or effort
3. Keep it encouraging and forward-looking
4. Reference their specific goals
5. Keep it concise (1-2 sentences)
6. Make it feel genuine, not generic

Remember: Respond with ONLY the JSON object, no additional text.
""",
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1000,
        },
      };

      // Make the API request
      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-2.0-flash',
      );

      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = _extractResponseText(data, 'daily nutrition analysis');

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

          final analysisResult = json.decode(cleanedText);

          // Validate the response structure
          if (analysisResult['suggestions'] is List &&
              analysisResult['motivationalQuote'] is String &&
              (analysisResult['suggestions'] as List).length == 5) {
            // Store the suggestions and quote
            await SettingsService.setDailyAiSuggestions(
              date,
              (analysisResult['suggestions'] as List).cast<String>(),
            );
            await SettingsService.setAiQuote(
              analysisResult['motivationalQuote'],
            );
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

      // Prepare the weekly analysis request
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
You are a professional nutritionist providing a comprehensive weekly nutrition analysis.

USER PROFILE:
- Age: $age years
- Sex: $sex
- Weight: ${weight}kg
- Height: ${height}cm
- Activity Level: $activityLevel
- Goals: $goals
- Daily Targets: ${macroTargets != null ? 'Protein: ${macroTargets['protein']}g, Carbs: ${macroTargets['carbs']}g, Fat: ${macroTargets['fat']}g' : 'Not set'}

WEEKLY DATA ($weekStartDate to ${startDate.add(Duration(days: 6)).toString().split(' ')[0]}):
${weeklyData.map((day) => '${day['dayName']}: ${day['calories']}kcal, ${day['protein']}g protein, ${day['carbs']}g carbs, ${day['fat']}g fat (${day['foodsCount']} foods)').join('\n')}

TASK: Provide a comprehensive weekly analysis as a JSON object:

{
  "summary": {
    "averageCalories": 0,
    "averageProtein": 0,
    "averageCarbs": 0,
    "averageFat": 0,
    "consistency": "High/Medium/Low",
    "targetAdherence": "Excellent/Good/Needs Improvement"
  },
  "insights": [
    "Key insight about weekly patterns",
    "Observation about nutrition quality",
    "Comment on goal progress"
  ],
  "recommendations": [
    "Specific recommendation for next week #1",
    "Specific recommendation for next week #2",
    "Specific recommendation for next week #3"
  ],
  "weeklyQuote": "Motivational quote reflecting their weekly performance"
}

Calculate averages, assess consistency of intake, evaluate target adherence, and provide actionable insights and recommendations for the upcoming week.

Respond with ONLY the JSON object, no additional text.
""",
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1200,
        },
      };
      // Make the API request
      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-2.0-flash',
      );

      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = _extractResponseText(data, 'weekly nutrition analysis');

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
