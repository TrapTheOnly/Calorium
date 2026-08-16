import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/parsed_recipe.dart';
import 'ai_service.dart';
import 'recipe_import_prompts.dart';
import 'settings_service.dart';
import 'video_resolvers/video_resolver.dart';
import 'video_resolvers/youtube_resolver.dart';
import 'video_resolvers/instagram_resolver.dart';

/// Orchestrates importing a recipe from a shared video link:
///  1. resolve the link (caption/description + thumbnail),
///  2. ask Gemini to turn the text metadata into a structured recipe,
///  3. (separately) pick the nearest inventory item for unmatched ingredients
///     from a small pruned shortlist — never sending the full inventory.
class RecipeImportService {
  static final List<VideoResolver> _resolvers = [
    YouTubeResolver(),
    InstagramResolver(),
  ];

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
  ///
  /// When [captionOverride] is non-empty, that text (plus any title already on
  /// [resolved]) is parsed even if [ResolvedVideo.hasUsableText] is false.
  static Future<ParsedRecipe> parseRecipe(
    ResolvedVideo resolved, {
    String? captionOverride,
  }) async {
    if (resolved.platform == VideoPlatform.unknown) {
      throw Exception(
        'This link is not a supported Instagram or YouTube recipe.',
      );
    }

    final override = captionOverride?.trim() ?? '';
    final toParse = override.isNotEmpty
        ? resolved.copyWith(caption: override)
        : resolved;

    if (override.isEmpty && !toParse.hasUsableText) {
      throw Exception(
        'Could not read a caption or description from this link. The post may '
        'be private, or the platform blocked access.',
      );
    }

    final prompt = RecipeImportPrompts.recipeParser(
      sourceText: toParse.combinedText,
    );
    final text = await AiService.generateText(
      prompt: prompt,
      temperature: 0.3,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 2048,
      context: 'recipe import',
    );

    final map = decodeJsonObject(text);
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
  ///
  /// Returns `{}` when the API key is missing or the network is down so the
  /// import review can still appear. Safety / API / structure errors are not
  /// swallowed silently.
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

    final prompt = RecipeImportPrompts.nearestMatch(itemsText: itemsText);

    try {
      final text = await AiService.generateText(
        prompt: prompt,
        temperature: 0.1,
        topK: 1,
        topP: 1,
        maxOutputTokens: 512,
        context: 'nearest match',
      );

      final map = decodeJsonObject(text);
      if (map == null) {
        print('suggestNearest: AI returned an unexpected format');
        throw Exception(
          'The AI returned an unexpected format for ingredient matches.',
        );
      }

      final result = <String, String>{};
      map.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          result[key] = value.trim();
        }
      });
      return result;
    } catch (e) {
      if (_isTransientNetworkError(e)) {
        print('suggestNearest network error: $e');
        return {};
      }
      print('suggestNearest failed: $e');
      rethrow;
    }
  }

  /// Strips markdown fences and surrounding prose, then decodes a JSON object.
  static Map<String, dynamic>? decodeJsonObject(String text) {
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

  static bool _isTransientNetworkError(Object error) {
    if (error is SocketException ||
        error is HandshakeException ||
        error is HttpException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network is unreachable') ||
        text.contains('timed out') ||
        text.contains('timeout');
  }
}
