import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parsed_recipe.dart';
import 'settings_service.dart';
import 'video_resolvers/video_resolver.dart';
import 'video_resolvers/youtube_resolver.dart';
import 'video_resolvers/instagram_resolver.dart';

/// Orchestrates importing a recipe from a shared video link:
///  1. resolve the link (download video + extract caption/description),
///  2. ask Gemini to turn the text metadata into a structured recipe,
///  3. (separately) pick the nearest inventory item for unmatched ingredients
///     from a small pruned shortlist — never sending the full inventory.
class RecipeImportService {
  static const String _apiHost = 'generativelanguage.googleapis.com';
  static const String _pathPrefix = '/v1beta/models/';
  static const String _generateContentSuffix = ':generateContent';

  static final List<VideoResolver> _resolvers = [
    YouTubeResolver(),
    InstagramResolver(),
  ];

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

  /// Resolves the shared [url] to downloaded media + text metadata.
  static Future<ResolvedVideo> resolveLink(
    String url, {
    void Function(String status)? onProgress,
  }) async {
    for (final resolver in _resolvers) {
      if (resolver.canHandle(url)) {
        return resolver.resolve(url, onProgress: onProgress);
      }
    }
    return ResolvedVideo(platform: VideoPlatform.unknown, sourceUrl: url);
  }

  /// Sends only the video's text metadata to Gemini and returns a structured
  /// recipe. Throws with a friendly message when the API key is missing or the
  /// response can't be parsed.
  static Future<ParsedRecipe> parseRecipe(ResolvedVideo resolved) async {
    final apiKey = await SettingsService.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'API key not set. Please configure your Gemini AI API key in settings.',
      );
    }

    if (!resolved.hasUsableText) {
      throw Exception(
        'Could not read a caption or description from this link. The post may '
        'be private, or the platform blocked access.',
      );
    }

    final prompt = _buildRecipePrompt(resolved);
    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.3,
        "topK": 40,
        "topP": 0.95,
        "maxOutputTokens": 2048,
      },
    };

    final uri = await _buildRequestUri(apiKey);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    if (response.statusCode != 200) {
      final errorData = _tryDecode(response.body);
      final message = errorData?['error']?['message'] ?? 'Unknown error';
      throw Exception('API Error (${response.statusCode}): $message');
    }

    final data = json.decode(response.body);
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (text is! String) {
      throw Exception('No response from AI.');
    }

    final map = _decodeJsonObject(text);
    if (map == null) {
      throw Exception('The AI returned an unexpected format. Please try again.');
    }

    final recipe = ParsedRecipe.fromMap(map);
    if (!recipe.isRecipe || recipe.ingredients.isEmpty) {
      throw Exception(
        'This link does not look like a recipe we can import. Try a video whose '
        'caption or pinned comment lists the ingredients and steps.',
      );
    }
    return recipe;
  }

  /// For the handful of ingredients the local matcher could not confidently
  /// match, ask the AI to pick the nearest option from a SHORT candidate list.
  ///
  /// [candidatesByIngredient] maps an ingredient name to a small list of
  /// inventory item names (the local matcher's top guesses). Returns a map from
  /// ingredient name to the chosen inventory name (absent when none fit).
  static Future<Map<String, String>> suggestNearest(
    Map<String, List<String>> candidatesByIngredient,
  ) async {
    final filtered = <String, List<String>>{
      for (final entry in candidatesByIngredient.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
    if (filtered.isEmpty) return {};

    final apiKey = await SettingsService.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) return {};

    final itemsText = filtered.entries
        .map(
          (e) =>
              '- "${e.key}": candidates = [${e.value.map((c) => '"$c"').join(', ')}]',
        )
        .join('\n');

    final prompt = '''
You match recipe ingredients to a user's pantry. For each ingredient below,
choose the SINGLE closest option from its candidate list (a reasonable
substitute is fine). If none of the candidates is a sensible match, use null.

INGREDIENTS AND CANDIDATES:
$itemsText

Respond with ONLY a valid JSON object mapping each ingredient name to the chosen
candidate string (exactly as written) or null. Example:
{"tomato": "Cherry tomatoes", "saffron": null}
''';

    try {
      final uri = await _buildRequestUri(apiKey);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {
            "temperature": 0.1,
            "topK": 1,
            "topP": 1,
            "maxOutputTokens": 512,
          },
        }),
      );

      if (response.statusCode != 200) return {};
      final data = json.decode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text is! String) return {};

      final map = _decodeJsonObject(text);
      if (map == null) return {};

      final result = <String, String>{};
      map.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          result[key] = value.trim();
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static String _buildRecipePrompt(ResolvedVideo resolved) {
    return '''
You are a careful recipe parser. Below is the text (title, caption/description,
and possibly a pinned comment) from a cooking video shared by a user.

SOURCE TEXT:
"""
${resolved.combinedText}
"""

TASK:
1. Decide whether this text describes a cookable food recipe. If it clearly does
   NOT (e.g. it is a vlog, a product ad, or has no ingredients), set
   "isRecipe": false and leave the other fields empty.
2. If it IS a recipe, extract it. Infer sensible ingredient amounts when the
   text is vague, and write clear step-by-step instructions even if the caption
   only implies them.
3. For EACH ingredient also estimate "amountGrams": the quantity in grams (or
   millilitres for liquids) as a plain number, so nutrition can be computed.
4. Mark spices/seasonings (salt, pepper, dried herbs, small flavourings) with
   "isSpice": true. These are assumed always available.

Respond with ONLY a valid JSON object in EXACTLY this shape, no extra text:

{
  "isRecipe": true,
  "recipeName": "A short, appetising name",
  "description": "One or two sentences describing the dish",
  "servings": 2,
  "prepTimeMinutes": 10,
  "cookTimeMinutes": 20,
  "difficulty": "easy|medium|hard",
  "tags": ["dinner", "high-protein"],
  "ingredients": [
    {
      "name": "chicken breast",
      "amount": "200 g",
      "amountGrams": 200,
      "unit": "g",
      "isSpice": false,
      "notes": "diced"
    }
  ],
  "instructions": ["Step 1 ...", "Step 2 ..."]
}

Rules:
- "unit" must be "g" for solids or "ml" for liquids.
- "amountGrams" must be a positive number (never a string).
- Keep ingredient "name" short and generic (e.g. "olive oil", not "extra virgin
  Italian olive oil"), so it is easy to match to a pantry.
''';
  }

  static Map<String, dynamic>? _decodeJsonObject(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // Be forgiving: pull out the outermost {...} if there's surrounding prose.
    if (!cleaned.startsWith('{')) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
    }

    try {
      final decoded = json.decode(cleaned);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = json.decode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
