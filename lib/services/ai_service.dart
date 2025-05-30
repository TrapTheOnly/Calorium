import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class AiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  
  static Future<Map<String, dynamic>?> analyzeFood(File imageFile) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not set. Please configure your Gemini AI API key in settings.');
      }
      
      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Prepare the request body
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
Analyze this food image and provide detailed nutritional information with accurate portion estimation.

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

NUTRITION CALCULATION:
- All nutritional values should be per 100g
- Use decimal numbers for precision
- Be specific with the food name based on what you see
- If you can't identify the food clearly, use "Unknown dish" as the name
- The defaultPortionSize should be your best estimate of the actual portion weight shown in the image
- Give a clear portion description that matches the estimated weight

EXAMPLE REASONING:
If you see pasta on a dinner plate that covers about half the plate (13cm diameter area), with a depth of about 2cm, that's roughly 265cm³. For pasta, that would be approximately 185g.
"""
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 1,
          "topP": 1,
          "maxOutputTokens": 256
        }
      };
      
      // Make the API request
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
              cleanedText = cleanedText.substring(0, cleanedText.length - 3); // Remove ending '```'
            }
            
            cleanedText = cleanedText.trim();
            
            final nutritionData = json.decode(cleanedText);
            return nutritionData;
          } catch (e) {
            print('Error parsing AI response: $e');
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
        throw Exception('API key not set. Please configure your Gemini AI API key in settings.');
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
          activityDescription = 'Moderately active (moderate exercise 3-5 days/week)';
          break;
        case 'very_active':
          activityDescription = 'Very active (hard exercise 6-7 days/week)';
          break;
        default:
          activityDescription = 'Moderately active (moderate exercise 3-5 days/week)';
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
- Daily Calorie Target: $calorieTarget kcal
- Age: $age years
- Weight: $weight kg
- Sex: $sex
- Activity Level: $activityDescription
- Goals: $goalsDescription

Please provide personalized macro recommendations with a 10% buffer for flexibility.

IMPORTANT CALORIE CALCULATION: 
Use this exact formula to verify your macro calculations:
Total Calories = (Fat in grams × 9) + (Carbohydrates in grams × 4) + (Protein in grams × 4)

Your calculated macros must add up to approximately the target calories using this formula.

IMPORTANT: Respond with ONLY a valid JSON object in this exact format:

{
  "calories": 2200,
  "protein": 132.0,
  "carbs": 275.0,
  "fat": 73.3,
  "explanation": "Based on your profile as a 25-year-old male weighing 70kg with moderate activity for weight maintenance, I calculated: Protein at 1.6g/kg (112g × 1.1 = 123g) for muscle maintenance, Fat at 25% of calories (550 kcal ÷ 9 = 61g × 1.1 = 67g) for hormone production, and Carbs to fill remaining calories (67g×9 + 123g×4 + 275g×4 = 2199 kcal). The 10% buffer provides flexibility while meeting your nutritional needs.",
  "tips": [
    "Focus on lean proteins like chicken, fish, and legumes",
    "Include complex carbs like oats, quinoa, and sweet potatoes", 
    "Add healthy fats from nuts, avocado, and olive oil"
  ]
}

Calculate based on:
- Protein: 1.2-2.0g per kg body weight (adjust for activity/goals)
- Fat: 20-35% of total calories
- Carbs: Fill remaining calories (minimum 130g for brain function)
- Add 10% buffer to all values for flexibility
- Consider sex differences in metabolism
- Adjust for age-related metabolic changes
- VERIFY your calculations using the calorie formula above

In your explanation, show your calculation process and why you chose these specific ratios for this individual. Include the calorie verification calculation.
"""
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.3,
          "topK": 1,
          "topP": 1,
          "maxOutputTokens": 1024
        }
      };
      
      print('Sending AI macro request with data: ${{
        'calories': calorieTarget,
        'age': age,
        'weight': weight,
        'sex': sex,
        'activity': activityDescription,
        'goals': goalsDescription
      }}');
      
      // Make the API request
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      print('AI macro response status: ${response.statusCode}');
      print('AI macro response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (text != null) {
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
              return macroData;
            } else {
              throw Exception('Invalid response structure from AI');
            }
          } catch (e) {
            print('Error parsing AI macro response: $e');
            print('AI Response: $text');
            throw Exception('Invalid response format from AI: $e');
          }
        } else {
          throw Exception('No response text from AI');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        print('AI API Error: $errorMessage');
        throw Exception('API Error: $errorMessage');
      }
    } catch (e) {
      print('AI Macro Service Error: $e');
      rethrow;
    }
  }
} 