import '../models/imported_ingredient_line.dart';
import 'ai_service.dart';
import 'recipe_import_prompts.dart';
import 'recipe_import_service.dart';

/// Recipe-only USDA-style macro estimates. Never writes foods to inventory.
class IngredientEstimateService {
  /// Estimates per-100g (or per-100ml) macros for a single ingredient.
  static Future<EstimatedMacros> estimate(
    String name, {
    String unit = 'g',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Cannot estimate nutrition for an empty ingredient name.');
    }
    final results = await estimateMany([trimmed], unit: unit);
    final macros = results[trimmed] ?? _lookupIgnoreCase(results, trimmed);
    if (macros == null) {
      throw Exception('No nutrition estimate returned for "$trimmed".');
    }
    return macros;
  }

  /// Batches [names] into one Gemini request. Skips blank names.
  static Future<Map<String, EstimatedMacros>> estimateMany(
    List<String> names, {
    String unit = 'g',
  }) async {
    final unique = <String>[];
    final seen = <String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) unique.add(name);
    }
    if (unique.isEmpty) return {};

    final namesText = unique.map((n) => '- $n ($unit)').join('\n');
    final prompt = RecipeImportPrompts.nutritionEstimate(namesText: namesText);

    final text = await AiService.generateText(
      prompt: prompt,
      temperature: 0.1,
      topK: 1,
      topP: 1,
      maxOutputTokens: 2048,
      context: 'ingredient estimate',
    );

    final map = RecipeImportService.decodeJsonObject(text);
    if (map == null) {
      throw Exception('The AI returned an unexpected format. Please try again.');
    }

    final result = <String, EstimatedMacros>{};
    for (final name in unique) {
      final raw = map[name] ?? _lookupMapIgnoreCase(map, name);
      if (raw is! Map) {
        throw Exception('No nutrition estimate returned for "$name".');
      }
      result[name] = EstimatedMacros.fromMap(
        Map<String, dynamic>.from(raw),
      );
    }
    return result;
  }

  static EstimatedMacros? _lookupIgnoreCase(
    Map<String, EstimatedMacros> results,
    String name,
  ) {
    final needle = name.toLowerCase();
    for (final entry in results.entries) {
      if (entry.key.toLowerCase() == needle) return entry.value;
    }
    return null;
  }

  static dynamic _lookupMapIgnoreCase(Map<String, dynamic> map, String name) {
    final needle = name.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == needle) return entry.value;
    }
    return null;
  }
}
