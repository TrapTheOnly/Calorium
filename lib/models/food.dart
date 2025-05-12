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
    };
  }
  
  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      calories: map['calories'],
      fat: map['fat'],
      carbs: map['carbs'],
      protein: map['protein'],
      type: map['type'] ?? 'simple',
      isArchived: map['isArchived'] == 1,
      defaultPortionSize: map['defaultPortionSize'] ?? 100.0,
      portionDescription: map['portionDescription'] ?? "100g",
    );
  }
}