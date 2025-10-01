import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class AiService {
  static const String _apiHost = 'generativelanguage.googleapis.com';
  static const String _generateContentPathPrefix = '/v1beta/models/';
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
    throw Exception('No candidates in API response');
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
        'Gemini truncated the response because it hit the maximum output token limit. Continuing with partial content.',
      );
    }

    return text;
  }

  static Uri _buildGenerateContentUri(String model, String apiKey) {
    final normalized = SettingsService.normalizeGeminiModelName(model);
    final path =
        '$_generateContentPathPrefix$normalized$_generateContentSuffix';
    return Uri.https(_apiHost, path, {'key': apiKey});
  }

  static Future<Uri> _buildRequestUri(
    String apiKey, {
    required String fallbackModel,
  }) async {
    final model = await SettingsService.getGeminiModel(
      fallbackModel: fallbackModel,
    );
    return _buildGenerateContentUri(model, apiKey);
  }

  static Future<Map<String, dynamic>?> analyzeFood(
    File imageFile, {
    String? userPrompt,
  }) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'API key not set. Please configure your Gemini AI API key in settings.',
        );
      }

      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-2.0-flash',
      );

      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Create the analysis prompt with optional user input
      String analysisPrompt = """
Analyze this food image and provide detailed nutritional information with accurate portion estimation.

${userPrompt != null && userPrompt.isNotEmpty ? 'USER CONTEXT: $userPrompt\n\nPlease take this context into account when analyzing the food.' : ''}

IMPORTANT: You must respond with ONLY a valid JSON object in this exact format, with no additional text or explanations:

{
  "name": "Food name",
  "calories": 250,
  "protein": 15.5,
  "carbs": 30.2,
  "fat": 8.7,
  "defaultPortionSize": 180,
  "portionDescription": "1 serving (180g)"
}

PORTION ESTIMATION GUIDELINES:
1. Look for reference objects in the image (plates, utensils, hands, cups, etc.)
2. Use these objects to estimate the actual size of the food:
   - Standard dinner plate: ~27cm diameter
   - Fork: ~20cm length
   - Spoon: ~15cm length
   - Adult hand: ~18cm length
   - Coffee mug: ~8cm diameter
   - Wine glass: ~7cm diameter

3. Calculate volume/weight using mathematical reasoning:
   - Dense foods (meat, cheese): ~1g per cm³
   - Light foods (bread, salad): ~0.3-0.5g per cm³
   - Liquid foods (soup, sauce): ~1g per ml
   - Rice/pasta: ~0.7g per cm³

4. Estimate the food dimensions relative to reference objects
5. Calculate approximate weight in grams for the actual portion shown

PORTION SIZE LOGIC FOR INDIVIDUAL ITEMS:
- For countable items (cherry tomatoes, grapes, nuts, berries, etc.): Base the portion on a SINGLE ITEM, not the total shown
- Example: If you see 3 cherry tomatoes, the portion should be "1 cherry tomato (15g)", not "3 cherry tomatoes (45g)"
- Example: If you see 5 grapes, the portion should be "1 grape (5g)", not "5 grapes (25g)"
- For dishes/meals: Base the portion on the total amount shown or a reasonable serving size
- Example: If you see a bowl of pasta, the portion should be "1 serving (200g)" representing the whole bowl

NUTRITION CALCULATION:
- All nutritional values should be per 100g
- Use decimal numbers for precision
- Be specific with the food name based on what you see
- If you can't identify the food clearly, use "Unknown dish" as the name
- The defaultPortionSize should reflect the portion logic above
- Give a clear portion description that matches the estimated weight

EXAMPLE REASONING:
- 3 cherry tomatoes visible: defaultPortionSize = 15 (weight of 1 tomato), portionDescription = "1 cherry tomato (15g)"
- Pasta on a dinner plate: defaultPortionSize = 185 (total serving), portionDescription = "1 serving (185g)"
- 2 cookies: defaultPortionSize = 25 (weight of 1 cookie), portionDescription = "1 cookie (25g)"
""";

      // Prepare the request body
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": analysisPrompt},
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 1,
          "topP": 1,
          "maxOutputTokens": 512,
        },
      };

      // Make the API request
      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('AI Food Analysis Response Status: ${response.statusCode}');
      print('AI Food Analysis Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Improved error handling and type safety
        if (data == null || data is! Map<String, dynamic>) {
          throw Exception('Invalid response structure from API');
        }

        final text = _extractResponseText(data, 'food analysis');

        // Parse the JSON response from Gemini
        try {
          // Clean the response by removing markdown code block formatting
          String cleanedText = text.trim();

          // Remove markdown code block markers if present
          if (cleanedText.startsWith('```json')) {
            cleanedText = cleanedText.substring(7); // Remove '```json'
          } else if (cleanedText.startsWith('```')) {
            cleanedText = cleanedText.substring(3); // Remove '```'
          }

          if (cleanedText.endsWith('```')) {
            cleanedText = cleanedText.substring(
              0,
              cleanedText.length - 3,
            ); // Remove ending '```'
          }

          cleanedText = cleanedText.trim();

          print('Cleaned AI Food Response: $cleanedText');

          final nutritionData = json.decode(cleanedText);

          // Validate the nutrition data structure
          if (nutritionData is! Map<String, dynamic>) {
            throw Exception('Nutrition data is not a valid object');
          }

          // Ensure required fields exist
          final requiredFields = [
            'name',
            'calories',
            'protein',
            'carbs',
            'fat',
            'defaultPortionSize',
            'portionDescription',
          ];
          for (String field in requiredFields) {
            if (!nutritionData.containsKey(field)) {
              throw Exception('Missing required field: $field');
            }
          }

          print('Successfully parsed nutrition data: $nutritionData');
          return nutritionData;
        } catch (e) {
          print('Error parsing AI food response: $e');
          print('AI Response Text: $text');
          throw Exception('Invalid response format from AI: $e');
        }
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('error')) {
            final error = errorData['error'];
            if (error is Map<String, dynamic> && error.containsKey('message')) {
              errorMessage = error['message'].toString();
            }
          }
        } catch (e) {
          errorMessage = 'Failed to parse error response: ${response.body}';
        }
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      print('AI Service Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> calculatePersonalizedTargets({
    required double calorieTarget,
    required int age,
    required double weight,
    required String sex,
    String activityLevel = 'moderate',
    String goals = 'maintenance',
  }) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'API key not set. Please configure your Gemini AI API key in settings.',
        );
      }

      // Map activity levels to descriptive text
      String activityDescription = '';
      switch (activityLevel) {
        case 'sedentary':
          activityDescription = 'Sedentary (little to no exercise)';
          break;
        case 'light':
          activityDescription = 'Lightly active (light exercise 1-3 days/week)';
          break;
        case 'moderate':
          activityDescription =
              'Moderately active (moderate exercise 3-5 days/week)';
          break;
        case 'very_active':
          activityDescription = 'Very active (hard exercise 6-7 days/week)';
          break;
        default:
          activityDescription =
              'Moderately active (moderate exercise 3-5 days/week)';
      }

      // Map goals to descriptive text
      String goalsDescription = '';
      switch (goals) {
        case 'maintenance':
          goalsDescription = 'Weight maintenance';
          break;
        case 'weight_loss':
          goalsDescription = 'Weight loss';
          break;
        case 'weight_gain':
          goalsDescription = 'Weight gain/muscle building';
          break;
        default:
          goalsDescription = 'Weight maintenance';
      }

      // Prepare the request body
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
As a professional nutritionist, calculate optimal daily macro targets for this person:

Profile:
- Daily Calorie Target: $calorieTarget kcal (MUST BE EXACT)
- Age: $age years
- Weight: $weight kg
- Sex: $sex
- Activity Level: $activityDescription
- Goals: $goalsDescription

CRITICAL REQUIREMENTS:
1. Your macro calculations MUST add up to EXACTLY $calorieTarget calories using this formula:
   Total Calories = (Protein × 4) + (Carbs × 4) + (Fat × 9)

2. Calculate macros that precisely hit the calorie target - NO rounding errors or approximations.

3. Use these evidence-based guidelines:
   - Protein: 0.8-2.2g per kg body weight (higher for active individuals, muscle building)
   - Fat: 20-35% of total calories (hormone production, vitamin absorption)
   - Carbs: Fill remaining calories after protein and fat (minimum 130g for brain function)

4. For activity level "$activityLevel" with goal "$goals":
   - Sedentary: Lower protein (0.8-1.2g/kg), moderate fat (25-30%)
   - Light: Moderate protein (1.0-1.4g/kg), balanced fat (25%)
   - Moderate: Higher protein (1.2-1.6g/kg), moderate fat (25%)
   - Very Active: High protein (1.6-2.2g/kg), slightly lower fat (20-25%)

CALCULATION PROCESS:
1. Calculate protein needs based on weight, activity, and goals
2. Calculate fat as percentage of total calories
3. Calculate carbs to fill remaining calories exactly
4. VERIFY: (Protein×4) + (Carbs×4) + (Fat×9) = $calorieTarget
5. Adjust values to hit EXACT calorie target

IMPORTANT: Respond with ONLY a valid JSON object in this exact format:

{
  "calories": $calorieTarget,
  "protein": 125.0,
  "carbs": 275.0,
  "fat": 73.0,
  "tips": [
    "Focus on lean proteins like chicken, fish, and legumes",
    "Include complex carbs like oats, quinoa, and sweet potatoes", 
    "Add healthy fats from nuts, avocado, and olive oil",
    "Stay hydrated and eat plenty of vegetables"
  ]
}

The macro values must be precise decimals that add up to exactly $calorieTarget calories.
Do not include any explanation field - only macros and tips.
Ensure your activity level interpretation matches "$activityDescription" exactly.
""",
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 1,
          "topP": 1,
          "maxOutputTokens": 512,
        },
      };

      print(
        'Sending AI macro request with data: ${{'calories': calorieTarget, 'age': age, 'weight': weight, 'sex': sex, 'activity': activityDescription, 'goals': goalsDescription}}',
      );

      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-2.0-flash',
      );

      // Make the API request
      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('AI macro response status: ${response.statusCode}');
      print('AI macro response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Improved error handling and type safety for macro calculation
        if (data == null || data is! Map<String, dynamic>) {
          throw Exception('Invalid response structure from API');
        }

        final text = _extractResponseText(data, 'personalized macro targets');

        print('AI macro response text: $text');

        // Parse the JSON response from Gemini
        try {
          // Clean the response by removing markdown code block formatting
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
          print('Cleaned AI macro response: $cleanedText');

          final macroData = json.decode(cleanedText);
          print('Parsed macro data: $macroData');

          // Validate the response structure
          if (macroData is Map<String, dynamic> &&
              macroData.containsKey('calories') &&
              macroData.containsKey('protein') &&
              macroData.containsKey('carbs') &&
              macroData.containsKey('fat')) {
            // Ensure the calculated calories match the target within a small tolerance
            final protein = (macroData['protein'] as num).toDouble();
            final carbs = (macroData['carbs'] as num).toDouble();
            final fat = (macroData['fat'] as num).toDouble();
            final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);

            print('AI provided macros: P:$protein C:$carbs F:$fat');
            print(
              'Calculated calories: $calculatedCalories, Target: $calorieTarget',
            );

            // Allow small rounding tolerance (within 5 calories)
            if ((calculatedCalories - calorieTarget).abs() <= 5.0) {
              return macroData;
            } else {
              print(
                'WARNING: AI macro calculations do not match calorie target',
              );
              // Still return the data but log the discrepancy
              return macroData;
            }
          } else {
            throw Exception('Invalid response structure from AI');
          }
        } catch (e) {
          print('Error parsing AI macro response: $e');
          print('AI Response: $text');
          throw Exception('Invalid response format from AI: $e');
        }
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('error')) {
            final error = errorData['error'];
            if (error is Map<String, dynamic> && error.containsKey('message')) {
              errorMessage = error['message'].toString();
            }
          }
        } catch (e) {
          errorMessage = 'Failed to parse error response: ${response.body}';
        }
        print('AI API Error: $errorMessage');
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      print('AI Macro Service Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> correctFoodAnalysis({
    required File imageFile,
    required Map<String, dynamic> originalAnalysis,
    required String userCorrection,
  }) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'API key not set. Please configure your Gemini AI API key in settings.',
        );
      }

      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Extract original portion info to preserve it
      final originalPortionSize = originalAnalysis['defaultPortionSize'] ?? 100;
      final originalPortionDescription =
          originalAnalysis['portionDescription'] ?? '1 serving';

      // Prepare the request body
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
You previously analyzed this food image and gave the following result:
${json.encode(originalAnalysis)}

The user has provided this correction/clarification:
"$userCorrection"

Please re-analyze the image taking into account the user's feedback and provide corrected nutritional values.

CRITICAL REQUIREMENTS:
1. Keep the EXACT SAME portion size and description: defaultPortionSize = $originalPortionSize, portionDescription = "$originalPortionDescription"
2. Only adjust the nutritional values (calories, protein, carbs, fat) per 100g based on the user's correction
3. Do NOT change the portion size or portion description - these must remain identical to the original analysis

IMPORTANT: You must respond with ONLY a valid JSON object in this exact format, with no additional text or explanations:

{
  "name": "Corrected food name",
  "calories": 250,
  "protein": 15.5,
  "carbs": 30.2,
  "fat": 8.7,
  "defaultPortionSize": $originalPortionSize,
  "portionDescription": "$originalPortionDescription"
}

Apply the user's correction to adjust the nutritional values per 100g (calories, protein, carbs, fat) but keep the portion size and description exactly the same as the original analysis. If they're mentioning modifications like "diet/low-fat" or "without rice", estimate the nutritional impact per 100g while maintaining the same portion weight.
""",
              },
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 1,
          "topP": 1,
          "maxOutputTokens": 512,
        },
      };

      final requestUri = await _buildRequestUri(
        apiKey,
        fallbackModel: 'gemini-2.0-flash',
      );

      // Make the API request
      final response = await http.post(
        requestUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('AI Food Correction Response Status: ${response.statusCode}');
      print('AI Food Correction Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Similar parsing logic as the original method
        if (data == null || data is! Map<String, dynamic>) {
          throw Exception('Invalid response structure from API');
        }

        final text = _extractResponseText(data, 'food correction');

        // Parse the JSON response from Gemini
        try {
          // Clean the response by removing markdown code block formatting
          String cleanedText = text.trim();

          // Remove markdown code block markers if present
          if (cleanedText.startsWith('```json')) {
            cleanedText = cleanedText.substring(7); // Remove '```json'
          } else if (cleanedText.startsWith('```')) {
            cleanedText = cleanedText.substring(3); // Remove '```'
          }

          if (cleanedText.endsWith('```')) {
            cleanedText = cleanedText.substring(
              0,
              cleanedText.length - 3,
            ); // Remove ending '```'
          }

          cleanedText = cleanedText.trim();

          print('Cleaned AI Food Correction Response: $cleanedText');

          final nutritionData = json.decode(cleanedText);

          // Validate the nutrition data structure
          if (nutritionData is! Map<String, dynamic>) {
            throw Exception('Nutrition data is not a valid object');
          }

          // Ensure required fields exist
          final requiredFields = [
            'name',
            'calories',
            'protein',
            'carbs',
            'fat',
            'defaultPortionSize',
            'portionDescription',
          ];
          for (String field in requiredFields) {
            if (!nutritionData.containsKey(field)) {
              throw Exception('Missing required field: $field');
            }
          }

          print('Successfully parsed corrected nutrition data: $nutritionData');
          return nutritionData;
        } catch (e) {
          print('Error parsing AI correction response: $e');
          print('AI Response Text: $text');
          throw Exception('Invalid response format from AI: $e');
        }
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('error')) {
            final error = errorData['error'];
            if (error is Map<String, dynamic> && error.containsKey('message')) {
              errorMessage = error['message'].toString();
            }
          }
        } catch (e) {
          errorMessage = 'Failed to parse error response: ${response.body}';
        }
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      print('AI Correction Service Error: $e');
      rethrow;
    }
  }
}
