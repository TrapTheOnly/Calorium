import 'food.dart';

/// An ingredient line in an imported recipe: an inventory [Food] plus the
/// amount used (in that food's base unit). Mirrors a `components` row and drives
/// live nutrition (`food.macro_per_100 * amount / 100`).
class ImportedComponent {
  final Food food;
  final double amount;
  const ImportedComponent({required this.food, required this.amount});
}

/// Metadata for a recipe imported from a shared video, stored alongside the
/// linked compound `foods` row (which carries the macros + ingredient links).
class ImportedRecipe {
  final int? id;
  final int foodId;

  /// Recipe name (sourced from the linked food row when loaded).
  final String name;
  final String platform;
  final String sourceUrl;
  final String? videoPath;
  final String? thumbnailPath;
  final String description;
  final List<String> instructions;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final List<String> tags;
  final DateTime createdAt;

  ImportedRecipe({
    this.id,
    required this.foodId,
    this.name = '',
    this.platform = '',
    this.sourceUrl = '',
    this.videoPath,
    this.thumbnailPath,
    this.description = '',
    this.instructions = const [],
    this.servings = 1,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    this.difficulty = 'medium',
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;

  bool get hasThumbnail =>
      thumbnailPath != null && thumbnailPath!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'foodId': foodId,
      'platform': platform,
      'sourceUrl': sourceUrl,
      'videoPath': videoPath ?? '',
      'thumbnailPath': thumbnailPath ?? '',
      'description': description,
      'instructions': instructions.join('|'),
      'servings': servings,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'tags': tags.join('|'),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ImportedRecipe.fromMap(Map<String, dynamic> map, {String? name}) {
    String? nullable(dynamic v) {
      final s = v?.toString() ?? '';
      return s.isEmpty ? null : s;
    }

    List<String> splitPipes(dynamic v) => (v?.toString() ?? '')
        .split('|')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return ImportedRecipe(
      id: map['id'] as int?,
      foodId: map['foodId'] as int,
      name: name ?? '',
      platform: map['platform']?.toString() ?? '',
      sourceUrl: map['sourceUrl']?.toString() ?? '',
      videoPath: nullable(map['videoPath']),
      thumbnailPath: nullable(map['thumbnailPath']),
      description: map['description']?.toString() ?? '',
      instructions: splitPipes(map['instructions']),
      servings: (map['servings'] as num?)?.toInt() ?? 1,
      prepTimeMinutes: (map['prepTimeMinutes'] as num?)?.toInt() ?? 0,
      cookTimeMinutes: (map['cookTimeMinutes'] as num?)?.toInt() ?? 0,
      difficulty: map['difficulty']?.toString() ?? 'medium',
      tags: splitPipes(map['tags']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
