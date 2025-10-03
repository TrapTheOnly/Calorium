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
  }) : loggedAt = loggedAt ?? _defaultLoggedAt(date);

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
              : _defaultLoggedAt(map['date'] ?? ''),
      foodName: map['name'],
      calories: map['calories'],
      fat: map['fat'],
      carbs: map['carbs'],
      protein: map['protein'],
      portions: map['portions'] ?? 1.0,
      defaultPortionSize: map['defaultPortionSize'],
      portionDescription: map['portionDescription'],
    );
  }

  static DateTime _defaultLoggedAt(String date) {
    DateTime targetDate;
    try {
      targetDate = DateTime.parse(date);
    } catch (_) {
      return DateTime.now();
    }

    final now = DateTime.now();
    final isToday =
        targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;

    if (isToday) {
      return now;
    }

    return DateTime(targetDate.year, targetDate.month, targetDate.day, 14);
  }
}
