import 'food.dart';

/// How a parsed recipe ingredient was resolved for nutrition.
enum IngredientMatchType { inventory, estimated, skipped, spice }

/// Per-100g (or per-100ml) macros for an ingredient that is not in inventory.
class EstimatedMacros {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const EstimatedMacros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toMap() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory EstimatedMacros.fromMap(Map<String, dynamic> map) {
    double n(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    return EstimatedMacros(
      calories: n(map['calories'] ?? map['estimatedCalories']),
      protein: n(map['protein'] ?? map['estimatedProtein']),
      carbs: n(map['carbs'] ?? map['estimatedCarbs']),
      fat: n(map['fat'] ?? map['estimatedFat']),
    );
  }
}

/// One original recipe line, kept after save so mappings can be edited later.
///
/// Estimates are recipe-only: they are never shown in inventory. Hidden
/// `type = 'estimate'` foods may be created so compound macros still recompute.
class ImportedIngredientLine {
  final int? id;
  final String parsedName;
  final String amountText;
  final double amountGrams;
  final String unit;
  final bool isSpice;
  final String? notes;
  final IngredientMatchType matchType;
  final Food? linkedFood;
  final EstimatedMacros? estimate;

  const ImportedIngredientLine({
    this.id,
    required this.parsedName,
    this.amountText = '',
    required this.amountGrams,
    this.unit = 'g',
    this.isSpice = false,
    this.notes,
    this.matchType = IngredientMatchType.skipped,
    this.linkedFood,
    this.estimate,
  });

  bool get countsTowardNutrition =>
      amountGrams > 0 &&
      (matchType == IngredientMatchType.inventory ||
          matchType == IngredientMatchType.estimated);

  String get displayName {
    final note = (notes != null && notes!.isNotEmpty) ? ' ($notes)' : '';
    final amount = amountText.isNotEmpty ? '$amountText ' : '';
    return '$amount$parsedName$note'.trim();
  }

  ImportedIngredientLine copyWith({
    int? id,
    String? parsedName,
    String? amountText,
    double? amountGrams,
    String? unit,
    bool? isSpice,
    String? notes,
    IngredientMatchType? matchType,
    Food? linkedFood,
    EstimatedMacros? estimate,
    bool clearLinkedFood = false,
    bool clearEstimate = false,
  }) {
    return ImportedIngredientLine(
      id: id ?? this.id,
      parsedName: parsedName ?? this.parsedName,
      amountText: amountText ?? this.amountText,
      amountGrams: amountGrams ?? this.amountGrams,
      unit: unit ?? this.unit,
      isSpice: isSpice ?? this.isSpice,
      notes: notes ?? this.notes,
      matchType: matchType ?? this.matchType,
      linkedFood: clearLinkedFood ? null : (linkedFood ?? this.linkedFood),
      estimate: clearEstimate ? null : (estimate ?? this.estimate),
    );
  }

  Map<String, dynamic> toMap({required int recipeFoodId, required int sortOrder}) {
    return {
      'recipeFoodId': recipeFoodId,
      'parsedName': parsedName,
      'amountText': amountText,
      'amountGrams': amountGrams,
      'unit': unit,
      'isSpice': isSpice ? 1 : 0,
      'notes': notes ?? '',
      'matchType': matchType.name,
      'linkedFoodId': linkedFood?.id,
      'estimatedCalories': estimate?.calories,
      'estimatedProtein': estimate?.protein,
      'estimatedCarbs': estimate?.carbs,
      'estimatedFat': estimate?.fat,
      'sortOrder': sortOrder,
    };
  }

  factory ImportedIngredientLine.fromMap(
    Map<String, dynamic> map, {
    Food? linkedFood,
  }) {
    final typeName = map['matchType']?.toString() ?? 'skipped';
    final matchType = IngredientMatchType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => IngredientMatchType.skipped,
    );

    EstimatedMacros? estimate;
    final cal = map['estimatedCalories'];
    if (cal is num) {
      estimate = EstimatedMacros(
        calories: cal.toDouble(),
        protein: (map['estimatedProtein'] as num?)?.toDouble() ?? 0,
        carbs: (map['estimatedCarbs'] as num?)?.toDouble() ?? 0,
        fat: (map['estimatedFat'] as num?)?.toDouble() ?? 0,
      );
    }

    final notesRaw = map['notes']?.toString() ?? '';
    return ImportedIngredientLine(
      id: map['id'] as int?,
      parsedName: map['parsedName']?.toString() ?? '',
      amountText: map['amountText']?.toString() ?? '',
      amountGrams: (map['amountGrams'] as num?)?.toDouble() ?? 0,
      unit: map['unit']?.toString() ?? 'g',
      isSpice: (map['isSpice'] as num?)?.toInt() == 1,
      notes: notesRaw.isEmpty ? null : notesRaw,
      matchType: matchType,
      linkedFood: linkedFood,
      estimate: estimate,
    );
  }
}
