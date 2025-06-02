import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class IngredientScannerService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  /// Analyze image to identify available ingredients
  static Future<Map<String, dynamic>?> scanIngredients(File imageFile) async {
    try {
      final apiKey = await SettingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not set. Please configure your Gemini AI API key in settings.');
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
Analyze this image to identify all available ingredients that could be used for cooking. Look carefully for:

1. Fresh produce (fruits, vegetables, herbs)
2. Proteins (meat, fish, eggs, dairy, legumes)
3. Grains and starches (rice, pasta, bread, potatoes)
4. Pantry items (spices, oils, condiments, canned goods)
5. Dairy products (milk, cheese, yogurt)
6. Any other cooking ingredients visible

IMPORTANT: You must respond with ONLY a valid JSON object in this exact format:

{
  "ingredients": [
    {
      "name": "Ingredient name",
      "category": "produce|protein|grain|dairy|pantry|spice",
      "quantity": "estimated amount",
      "freshness": "fresh|good|questionable",
      "confidence": 0.95
    }
  ],
  "suggestions": [
    "General cooking suggestion based on ingredients visible",
    "Another helpful tip for using these ingredients"
  ],
  "totalIngredients": 8
}

GUIDELINES:
- Be specific with ingredient names (e.g., "Roma tomatoes" not just "tomatoes")
- Estimate quantities when possible (e.g., "3 large", "1 cup", "handful")
- Rate freshness based on visual appearance
- Confidence should be 0.0-1.0 based on how certain you are about the identification
- Only include ingredients you can clearly see and identify
- Categories: produce, protein, grain, dairy, pantry, spice
- Provide 2-3 helpful cooking suggestions based on what you see
- Don't make assumptions about ingredients not clearly visible

Focus on ingredients that would be useful for meal preparation. Ignore non-food items.
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
          "temperature": 0.3,
          "topK": 20,
          "topP": 0.9,
          "maxOutputTokens": 1000
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
            
            final scanResult = json.decode(cleanedText);
            
            // Validate the response structure
            if (scanResult['ingredients'] is List &&
                scanResult['suggestions'] is List &&
                scanResult['totalIngredients'] is int) {
              return scanResult;
            } else {
              throw Exception('Invalid response structure from AI');
            }
          } catch (e) {
            print('Error parsing ingredient scanner response: $e');
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
      print('Ingredient Scanner Service Error: $e');
      rethrow;
    }
  }

  /// Categorize ingredients by type for better organization
  static Map<String, List<Map<String, dynamic>>> categorizeIngredients(List<dynamic> ingredients) {
    final Map<String, List<Map<String, dynamic>>> categorized = {
      'produce': [],
      'protein': [],
      'grain': [],
      'dairy': [],
      'pantry': [],
      'spice': [],
    };

    for (var ingredient in ingredients) {
      final category = ingredient['category'] as String;
      if (categorized.containsKey(category)) {
        categorized[category]!.add(ingredient);
      }
    }

    return categorized;
  }

  /// Filter ingredients by freshness
  static List<Map<String, dynamic>> filterByFreshness(
    List<dynamic> ingredients, 
    List<String> acceptableFreshness
  ) {
    return ingredients
        .where((ingredient) => acceptableFreshness.contains(ingredient['freshness']))
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Get ingredients with high confidence only
  static List<Map<String, dynamic>> getHighConfidenceIngredients(
    List<dynamic> ingredients, 
    {double minConfidence = 0.7}
  ) {
    return ingredients
        .where((ingredient) => (ingredient['confidence'] as double) >= minConfidence)
        .cast<Map<String, dynamic>>()
        .toList();
  }
}