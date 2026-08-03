/// A single ingredient parsed out of a shared recipe's text by the AI.
///
/// [amountGrams] is the AI's best estimate of the quantity in the ingredient's
/// base unit (grams for solids, millilitres for liquids) so it can be plugged
/// straight into the app's `macro_per_100 * amount / 100` nutrition model.
class ParsedIngredient {
  final String name;

  /// Human-readable amount as written in the source (e.g. "2 cups").
  final String amountText;

  /// Estimated quantity in base units (g or ml).
  final double amountGrams;

  /// Base unit for [amountGrams]: 'g' or 'ml'.
  final String unit;

  /// Whether this is a spice/seasoning (assumed always on hand, never matched
  /// to inventory and excluded from nutrition).
  final bool isSpice;

  final String? notes;

  const ParsedIngredient({
    required this.name,
    required this.amountText,
    required this.amountGrams,
    this.unit = 'g',
    this.isSpice = false,
    this.notes,
  });

  factory ParsedIngredient.fromMap(Map<String, dynamic> map) {
    final unitRaw = (map['unit'] ?? 'g').toString().toLowerCase();
    return ParsedIngredient(
      name: (map['name'] ?? '').toString().trim(),
      amountText: (map['amount'] ?? '').toString().trim(),
      amountGrams: (map['amountGrams'] is num)
          ? (map['amountGrams'] as num).toDouble()
          : 0.0,
      unit: unitRaw == 'ml' ? 'ml' : 'g',
      isSpice: map['isSpice'] == true,
      notes: (map['notes'] == null || map['notes'].toString().trim().isEmpty)
          ? null
          : map['notes'].toString().trim(),
    );
  }

  /// A display string like "2 cups flour (sifted)".
  String get display {
    final amount = amountText.isNotEmpty ? '$amountText ' : '';
    final note = (notes != null && notes!.isNotEmpty) ? ' ($notes)' : '';
    return '$amount$name$note'.trim();
  }
}

/// A structured recipe extracted from a shared video's text metadata.
class ParsedRecipe {
  final bool isRecipe;
  final String name;
  final String description;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final List<String> tags;
  final List<ParsedIngredient> ingredients;
  final List<String> instructions;

  const ParsedRecipe({
    required this.isRecipe,
    required this.name,
    this.description = '',
    this.servings = 1,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    this.difficulty = 'medium',
    this.tags = const [],
    this.ingredients = const [],
    this.instructions = const [],
  });

  factory ParsedRecipe.fromMap(Map<String, dynamic> map) {
    final ingredientsRaw = (map['ingredients'] as List?) ?? const [];
    final instructionsRaw = (map['instructions'] as List?) ?? const [];
    final tagsRaw = (map['tags'] as List?) ?? const [];

    int asInt(dynamic v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return ParsedRecipe(
      isRecipe: map['isRecipe'] != false,
      name: (map['recipeName'] ?? map['name'] ?? 'Imported recipe')
          .toString()
          .trim(),
      description: (map['description'] ?? '').toString().trim(),
      servings: asInt(map['servings'], 1).clamp(1, 99),
      prepTimeMinutes: asInt(map['prepTimeMinutes'] ?? map['prepTime']),
      cookTimeMinutes: asInt(map['cookTimeMinutes'] ?? map['cookTime']),
      difficulty: (map['difficulty'] ?? 'medium').toString().toLowerCase(),
      tags: tagsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(),
      ingredients: ingredientsRaw
          .whereType<Map>()
          .map((e) => ParsedIngredient.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList(),
      instructions: instructionsRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
