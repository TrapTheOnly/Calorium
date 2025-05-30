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
Analyze this food image and provide detailed nutritional information for a typical serving size. 

IMPORTANT: You must respond with ONLY a valid JSON object in this exact format, with no additional text or explanations:

{
  "name": "Food name",
  "calories": 250,
  "protein": 15.5,
  "carbs": 30.2,
  "fat": 8.7,
  "defaultPortionSize": 100,
  "portionDescription": "1 serving (100g)"
}

- All nutritional values should be per 100g
- Use decimal numbers for precision
- Provide a reasonable serving size in grams for defaultPortionSize
- Give a clear portion description
- Be specific with the food name based on what you see
- If you can't identify the food clearly, use "Unknown dish" as the name
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
} 