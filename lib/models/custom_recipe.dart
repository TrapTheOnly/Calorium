import 'food.dart';

class CustomRecipe {
  final int? id;
  final int? foodId; // ID of the corresponding food entry
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final double calories;
  final double fat;
  final double carbs;
  final double protein;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty; // 'easy', 'medium', 'hard'
  final List<String> tags; // 'breakfast', 'dinner', 'low-carb', etc.
  final String aiGeneratedPrompt;
  final DateTime createdAt;
  final bool isFavorite;
  final double defaultPortionSize;
  final String portionDescription;

  CustomRecipe({
    this.id,
    this.foodId,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    this.difficulty = 'medium',
    this.tags = const [],
    this.aiGeneratedPrompt = '',
    DateTime? createdAt,
    this.isFavorite = false,
    this.defaultPortionSize = 100.0,
    this.portionDescription = "1 serving",
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodId': foodId,
      'name': name,
      'description': description,
      'ingredients': ingredients.join('|'), // Store as pipe-separated string
      'instructions': instructions.join('|'),
      'calories': calories,
      'fat': fat,
      'carbs': carbs,
      'protein': protein,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'servings': servings,
      'difficulty': difficulty,
      'tags': tags.join('|'),
      'aiGeneratedPrompt': aiGeneratedPrompt,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isFavorite': isFavorite ? 1 : 0,
      'defaultPortionSize': defaultPortionSize,
      'portionDescription': portionDescription,
    };
  }

  factory CustomRecipe.fromMap(Map<String, dynamic> map) {
    return CustomRecipe(
      id: map['id'],
      foodId: map['foodId'],
      name: map['name'],
      description: map['description'],
      ingredients: (map['ingredients'] as String).split('|').where((s) => s.isNotEmpty).toList(),
      instructions: (map['instructions'] as String).split('|').where((s) => s.isNotEmpty).toList(),
      calories: map['calories'],
      fat: map['fat'],
      carbs: map['carbs'],
      protein: map['protein'],
      prepTimeMinutes: map['prepTimeMinutes'],
      cookTimeMinutes: map['cookTimeMinutes'],
      servings: map['servings'],
      difficulty: map['difficulty'] ?? 'medium',
      tags: (map['tags'] as String).split('|').where((s) => s.isNotEmpty).toList(),
      aiGeneratedPrompt: map['aiGeneratedPrompt'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isFavorite: map['isFavorite'] == 1,
      defaultPortionSize: map['defaultPortionSize'] ?? 100.0,
      portionDescription: map['portionDescription'] ?? "1 serving",
    );
  }

  // Convert to Food object for logging
  Food toFood() {
    return Food(
      id: foodId, // Use the linked food ID
      name: name,
      calories: calories / servings, // Per serving calories
      fat: fat / servings,
      carbs: carbs / servings,
      protein: protein / servings,
      type: 'custom_recipe',
      defaultPortionSize: defaultPortionSize,
      portionDescription: portionDescription,
    );
  }

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  CustomRecipe copyWith({
    int? id,
    int? foodId,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    double? calories,
    double? fat,
    double? carbs,
    double? protein,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? servings,
    String? difficulty,
    List<String>? tags,
    String? aiGeneratedPrompt,
    DateTime? createdAt,
    bool? isFavorite,
    double? defaultPortionSize,
    String? portionDescription,
  }) {
    return CustomRecipe(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      calories: calories ?? this.calories,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      aiGeneratedPrompt: aiGeneratedPrompt ?? this.aiGeneratedPrompt,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      defaultPortionSize: defaultPortionSize ?? this.defaultPortionSize,
      portionDescription: portionDescription ?? this.portionDescription,
    );
  }
}