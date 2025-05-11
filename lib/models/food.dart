class Food {
  final int? id;
  final String name;
  final double calories;
  final double fat;
  final double carbs;
  final double protein;
  final String type;
  final bool isArchived;
  final bool fromBarcode; // New flag to identify barcode-scanned foods
  
  Food({
    this.id,
    required this.name,
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
    this.type = 'simple',
    this.isArchived = false,
    this.fromBarcode = false, // Default to false
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
      // fromBarcode is not stored in the database, it's just a transient flag
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
    );
  }
}