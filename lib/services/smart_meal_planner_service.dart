 import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'log_service.dart';
import '../models/custom_recipe.dart';

class SmartMealPlannerService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  /// Generate a personalized meal recommendation based on available ingredients and user context
  static Future<Map<String, dynamic>?> generateMealRecommendation({
    required List<Map<String, dynamic>> availableIngredients,
    required Map<String, String> userPreferences,
    String? currentDate,
  }) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not set. Please configure your Gemini AI API key in settings.');
      }

      // Check if user has complete profile
      if (!await SettingsService.hasCompleteProfile()) {
        throw Exception('Incomplete profile. Please fill in all profile information in settings.');
      }

      // Get user profile data
      final age = await SettingsService.getAge();
      final weight = await SettingsService.getWeight();
      final height = await SettingsService.getHeight();
      final sex = await SettingsService.getSex();
      final activityLevel = await SettingsService.getActivityLevel();
      final goals = await SettingsService.getGoals();
      final macroTargets = await SettingsService.getMacroTargets();

      // Get current day's nutrition data
      currentDate ??= DateTime.now().toIso8601String().split('T')[0];
      final logService = LogService();
      final entries = await logService.getLogEntriesByDate(currentDate);

      // Calculate current intake
      double currentCalories = 0, currentProtein = 0, currentCarbs = 0, currentFat = 0;
      for (var entry in entries) {
        currentCalories += (entry.calories! * entry.amount / 100);
        currentProtein += (entry.protein! * entry.amount / 100);
        currentCarbs += (entry.carbs! * entry.amount / 100);
        currentFat += (entry.fat! * entry.amount / 100);
      }

      // Determine time of day context
      final now = DateTime.now();
      final hour = now.hour;
      String mealTime;
      String timeContext;
      
      if (hour >= 5 && hour < 11) {
        mealTime = 'breakfast';
        timeContext = 'morning energy and metabolism boost';
      } else if (hour >= 11 && hour < 16) {
        mealTime = 'lunch';
        timeContext = 'midday sustenance and afternoon energy';
      } else if (hour >= 16 && hour < 20) {
        mealTime = 'dinner';
        timeContext = 'evening nutrition and recovery';
      } else {
        mealTime = 'snack';
        timeContext = 'light meal or healthy snack';
      }

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
You are a professional chef and nutritionist. Create a personalized meal recommendation based on the available ingredients and user's nutritional needs.

USER PROFILE:
- Age: $age years, Sex: $sex, Weight: ${weight}kg, Height: ${height}cm
- Activity Level: $activityLevel
- Goals: $goals
- Daily Macro Targets: ${macroTargets != null ? 'Protein: ${macroTargets['protein']}g, Carbs: ${macroTargets['carbs']}g, Fat: ${macroTargets['fat']}g' : 'Not set'}

CURRENT DAILY INTAKE ($currentDate):
- Calories: ${currentCalories.round()}kcal
- Protein: ${currentProtein.round()}g
- Carbs: ${currentCarbs.round()}g
- Fat: ${currentFat.round()}g

TIME CONTEXT:
- Current time: ${hour}:00 (suggesting $mealTime)
- Focus: $timeContext

AVAILABLE INGREDIENTS:
${availableIngredients.map((ing) => '• ${ing['name']} (${ing['quantity']}) - ${ing['category']} - ${ing['freshness']} condition').join('\n')}

USER PREFERENCES:
- Available time: ${userPreferences['timeAvailable'] ?? 'Not specified'}
- Cooking skill: ${userPreferences['cookingSkill'] ?? 'Not specified'}
- Dietary restrictions: ${userPreferences['dietaryRestrictions'] ?? 'None'}
- Cuisine preference: ${userPreferences['cuisinePreference'] ?? 'Any'}
- Meal type preference: ${userPreferences['mealTypePreference'] ?? 'Balanced'}

TASK: Create a meal recommendation that:
1. Uses primarily the available ingredients
2. Fits the time of day and available cooking time
3. Complements current nutrition intake to reach daily targets
4. Matches user preferences and skill level
5. Provides a complete recipe with instructions

Respond with ONLY a valid JSON object in this exact format:

{
  "recipeName": "Creative recipe name",
  "description": "Brief description of the dish and why it's perfect for this person right now",
  "difficulty": "easy|medium|hard",
  "prepTime": 15,
  "cookTime": 25,
  "servings": 2,
  "tags": ["breakfast", "high-protein", "quick"],
  "ingredients": [
    {
      "name": "Ingredient name",
      "amount": "2 cups",
      "notes": "preparation notes if needed"
    }
  ],
  "instructions": [
    "Step 1: Detailed instruction",
    "Step 2: Another step",
    "Step 3: Continue..."
  ],
  "nutrition": {
    "calories": 450,
    "protein": 25.5,
    "carbs": 35.2,
    "fat": 18.7
  },
  "tips": [
    "Helpful cooking tip",
    "Substitution suggestion"
  ],
  "whyThisRecipe": "Explanation of why this recipe fits their current nutritional needs and context"
}

GUIDELINES:
- Prioritize fresh ingredients first, then good condition ones
- Consider cooking time vs available time
- Balance flavors and textures
- Ensure nutritional value complements daily targets
- Include specific amounts and clear instructions
- Make it appealing and achievable
- Consider the time of day for appropriate meal types
- If missing key ingredients, suggest simple substitutions
- Nutrition values should be per total recipe (all servings combined)
"""
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 2000
        }
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
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
            
            final mealRecommendation = json.decode(cleanedText);
            
            // Validate response structure
            if (_validateMealRecommendation(mealRecommendation)) {
              return mealRecommendation;
            } else {
              throw Exception('Invalid meal recommendation structure');
            }
          } catch (e) {
            print('Error parsing meal recommendation: $e');
            print('AI Response: $text');
            throw Exception('Invalid response format from AI');
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
      print('Smart Meal Planner Service Error: $e');
      rethrow;
    }
  }

  /// Generate follow-up questions to refine meal recommendations
  static Map<String, List<String>> getCustomizationQuestions() {
    return {
      'timeAvailable': [
        '15 minutes or less',
        '15-30 minutes',
        '30-60 minutes',
        'Over 1 hour',
        'I have all day'
      ],
      'cookingSkill': [
        'Beginner (simple recipes)',
        'Intermediate (moderate techniques)',
        'Advanced (complex cooking)',
        'Professional level'
      ],
      'mealTypePreference': [
        'Light and fresh',
        'Hearty and filling',
        'Balanced and nutritious',
        'Comfort food',
        'Gourmet experience'
      ],
      'cuisinePreference': [
        'Mediterranean',
        'Asian',
        'American/Western',
        'Mexican/Latin',
        'Italian',
        'Indian',
        'Middle Eastern',
        'No preference'
      ],
      'dietaryRestrictions': [
        'None',
        'Vegetarian',
        'Vegan',
        'Gluten-free',
        'Dairy-free',
        'Low-carb/Keto',
        'Paleo',
        'Other (specify)'
      ]
    };
  }

  /// Convert meal recommendation to CustomRecipe object
  static CustomRecipe convertToCustomRecipe(
    Map<String, dynamic> mealRecommendation,
    String aiPrompt
  ) {
    final ingredients = (mealRecommendation['ingredients'] as List)
        .map((ing) => '${ing['amount']} ${ing['name']}${ing['notes'] != null ? ' (${ing['notes']})' : ''}')
        .toList()
        .cast<String>();

    final instructions = (mealRecommendation['instructions'] as List)
        .cast<String>();

    final nutrition = mealRecommendation['nutrition'];
    final tags = (mealRecommendation['tags'] as List?)?.cast<String>() ?? [];

    return CustomRecipe(
      name: mealRecommendation['recipeName'],
      description: mealRecommendation['description'],
      ingredients: ingredients,
      instructions: instructions,
      calories: (nutrition['calories'] as num).toDouble(),
      fat: (nutrition['fat'] as num).toDouble(),
      carbs: (nutrition['carbs'] as num).toDouble(),
      protein: (nutrition['protein'] as num).toDouble(),
      prepTimeMinutes: mealRecommendation['prepTime'],
      cookTimeMinutes: mealRecommendation['cookTime'],
      servings: mealRecommendation['servings'],
      difficulty: mealRecommendation['difficulty'],
      tags: tags,
      aiGeneratedPrompt: aiPrompt,
      defaultPortionSize: (nutrition['calories'] as num).toDouble() / (mealRecommendation['servings'] as int) * 100 / 100, // Rough estimate for portion size
      portionDescription: '1 serving',
    );
  }

  /// Validate meal recommendation structure
  static bool _validateMealRecommendation(Map<String, dynamic> recommendation) {
    final requiredKeys = [
      'recipeName',
      'description', 
      'difficulty',
      'prepTime',
      'cookTime',
      'servings',
      'ingredients',
      'instructions',
      'nutrition'
    ];

    for (String key in requiredKeys) {
      if (!recommendation.containsKey(key)) {
        print('Missing required key: $key');
        return false;
      }
    }

    if (recommendation['ingredients'] is! List ||
        recommendation['instructions'] is! List ||
        recommendation['nutrition'] is! Map) {
      return false;
    }

    final nutrition = recommendation['nutrition'] as Map<String, dynamic>;
    final requiredNutritionKeys = ['calories', 'protein', 'carbs', 'fat'];
    
    for (String key in requiredNutritionKeys) {
      if (!nutrition.containsKey(key) || nutrition[key] is! num) {
        print('Missing or invalid nutrition key: $key');
        return false;
      }
    }

    return true;
  }
}