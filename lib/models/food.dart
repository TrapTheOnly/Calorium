class Food {
  final int? id;
  final String name;
  final double calories;
  final double fat;
  final double carbs;
  final double protein;
  final String type;
  final bool isArchived;
  final double defaultPortionSize;
  final String portionDescription;
  final List<String> tags;
  
  Food({
    this.id,
    required this.name,
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
    this.type = 'simple',
    this.isArchived = false,
    this.defaultPortionSize = 100.0,
    this.portionDescription = "100g",
    this.tags = const [],
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'fat': fat,
      'carbs': carbs,
      'protein': protein,
      'type': type,
      'isArchived': isArchived ? 1 : 0,
      'defaultPortionSize': defaultPortionSize,
      'portionDescription': portionDescription,
      'tags': tags.join(','),
    };
  }
  
  factory Food.fromMap(Map<String, dynamic> map) {
    final tagsString = map['tags'] ?? '';
    List<String> tagsList = [];
    if (tagsString.isNotEmpty && tagsString != null) {
      try {
        tagsList = tagsString
            .toString()
            .split(',')
            .where((tag) => tag.trim().isNotEmpty)
            .map((tag) => tag.trim())
            .cast<String>()
            .toList();
      } catch (e) {
        // If parsing fails, default to empty list
        tagsList = [];
      }
    }
    
    return Food(
      id: map['id']?.toInt(),
      name: map['name']?.toString() ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      type: map['type']?.toString() ?? 'simple',
      isArchived: (map['isArchived'] ?? 0) == 1,
      defaultPortionSize: (map['defaultPortionSize'] ?? 100.0).toDouble(),
      portionDescription: map['portionDescription']?.toString() ?? "100g",
      tags: tagsList,
    );
  }
  
  // Helper method to create a copy with updated tags
  Food copyWith({
    int? id,
    String? name,
    double? calories,
    double? fat,
    double? carbs,
    double? protein,
    String? type,
    bool? isArchived,
    double? defaultPortionSize,
    String? portionDescription,
    List<String>? tags,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      type: type ?? this.type,
      isArchived: isArchived ?? this.isArchived,
      defaultPortionSize: defaultPortionSize ?? this.defaultPortionSize,
      portionDescription: portionDescription ?? this.portionDescription,
      tags: tags ?? this.tags,
    );
  }
}