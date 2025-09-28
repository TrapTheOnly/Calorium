import '../models/log_entry.dart';
import 'database_service.dart';

class LogService {
  Future<List<LogEntry>> getLogEntriesByDate(String date) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT l.id, l.foodId, l.amount, l.date, l.portions, 
            f.name, f.calories, f.fat, f.carbs, f.protein, 
            f.defaultPortionSize, f.portionDescription,
            l.loggedAt
      FROM logs l JOIN foods f ON f.id = l.foodId
      WHERE l.date = ?
    ''',
      [date],
    );

    return List.generate(maps.length, (i) {
      return LogEntry.fromMap(maps[i]);
    });
  }

  // Add this method to get total macros with portions
  Future<Map<String, double>> getTotalMacros(String date) async {
    final db = await DatabaseService.instance.database;

    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(f.calories * l.amount * l.portions / 100) as totalCalories,
        SUM(f.fat * l.amount * l.portions / 100) as totalFat,
        SUM(f.carbs * l.amount * l.portions / 100) as totalCarbs,
        SUM(f.protein * l.amount * l.portions / 100) as totalProtein
      FROM logs l
      JOIN foods f ON l.foodId = f.id
      WHERE l.date = ?
    ''',
      [date],
    );

    final row = result.first;

    return {
      'calories': row['totalCalories'] as double? ?? 0,
      'fat': row['totalFat'] as double? ?? 0,
      'carbs': row['totalCarbs'] as double? ?? 0,
      'protein': row['totalProtein'] as double? ?? 0,
    };
  }

  Future<int> insertLogEntry(LogEntry entry) async {
    final db = await DatabaseService.instance.database;
    return await db.insert('logs', entry.toMap());
  }

  Future<int> updateLogEntry(LogEntry entry) async {
    final db = await DatabaseService.instance.database;
    return await db.update(
      'logs',
      {'amount': entry.amount},
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteLogEntry(int id) async {
    final db = await DatabaseService.instance.database;
    return await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }
}
