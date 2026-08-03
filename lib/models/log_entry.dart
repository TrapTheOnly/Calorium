class LogEntry {
  final int? id;
  final int foodId;
  final double amount;
  final String date;
  final DateTime loggedAt;
  final String? foodName;
  final double? calories;
  final double? fat;
  final double? carbs;
  final double? protein;
  final double? portions;
  final double? defaultPortionSize;
  final String? portionDescription;
  final String? unit;
  final bool? hasServing;

  LogEntry({
    this.id,
    required this.foodId,
    required this.amount,
    required this.date,
    DateTime? loggedAt,
    this.foodName,
    this.calories,
    this.fat,
    this.carbs,
    this.protein,
    this.portions = 1.0,
    this.defaultPortionSize,
    this.portionDescription,
    this.unit,
    this.hasServing,
  }) : loggedAt = loggedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodId': foodId,
      'amount': amount,
      'date': date,
      'loggedAt': loggedAt.millisecondsSinceEpoch,
      'portions': portions,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      foodId: map['foodId'],
      amount: map['amount'],
      date: map['date'],
      loggedAt:
          map['loggedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['loggedAt'])
              : DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      foodName: map['name'],
      calories: map['calories'],
      fat: map['fat'],
      carbs: map['carbs'],
      protein: map['protein'],
      portions: map['portions'] ?? 1.0,
      defaultPortionSize: map['defaultPortionSize'],
      portionDescription: map['portionDescription'],
      unit: map['unit'],
      hasServing: map['hasServing'] == null ? null : (map['hasServing'] == 1),
    );
  }
}
