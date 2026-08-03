import 'dart:async';
import '../models/log_entry.dart';
import 'database_service.dart';
import 'health_service.dart';

class LogService {
  Future<List<LogEntry>> getLogEntriesByDate(String date) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT l.id, l.foodId, l.amount, l.date, l.portions, 
            f.name, f.calories, f.fat, f.carbs, f.protein, 
            f.defaultPortionSize, f.portionDescription, f.unit, f.hasServing,
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
        SUM(f.calories * l.amount / 100) as totalCalories,
        SUM(f.fat * l.amount / 100) as totalFat,
        SUM(f.carbs * l.amount / 100) as totalCarbs,
        SUM(f.protein * l.amount / 100) as totalProtein
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
    final id = await db.insert('logs', entry.toMap());
    // Best-effort: mirror the meal to Health Connect so other apps can read it.
    // Silently skips when write access isn't granted or on desktop.
    unawaited(_writeMealToHealthConnect(id));
    return id;
  }

  /// Reads the just-inserted row's joined nutrition and writes it to Health
  /// Connect. Wrapped so any failure never affects logging.
  Future<void> _writeMealToHealthConnect(int logId) async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT f.name, f.calories, f.fat, f.carbs, f.protein,
               l.amount, l.portions, l.loggedAt
        FROM logs l JOIN foods f ON f.id = l.foodId
        WHERE l.id = ?
      ''',
        [logId],
      );
      if (rows.isEmpty) return;
      final r = rows.first;
      // `amount` is the total quantity in base units (g/ml); `portions` is only
      // display metadata (amount / portionSize). The whole app derives nutrition
      // as perValue * amount / 100, so Health Connect must use the same factor —
      // multiplying by `portions` here double-counted serving-based entries.
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final factor = amount / 100.0;
      if (factor <= 0) return;

      final loggedAtMs = r['loggedAt'] as int?;
      final time = loggedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(loggedAtMs)
          : DateTime.now();

      await HealthService.instance.writeMeal(
        name: (r['name'] as String?) ?? 'Meal',
        calories: ((r['calories'] as num?)?.toDouble() ?? 0) * factor,
        protein: ((r['protein'] as num?)?.toDouble() ?? 0) * factor,
        carbs: ((r['carbs'] as num?)?.toDouble() ?? 0) * factor,
        fat: ((r['fat'] as num?)?.toDouble() ?? 0) * factor,
        time: time,
      );
    } catch (_) {
      // Never let Health Connect issues break logging.
    }
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

  /// Backfills past logged meals to Health Connect (for apps that already had
  /// history before write-permission was granted). Returns how many meals were
  /// successfully written. Requests write permission if missing.
  Future<int> resyncMealsToHealthConnect({int lookbackDays = 90}) async {
    final granted =
        await HealthService.instance.requestNutritionWritePermission();
    if (!granted) return 0;

    final db = await DatabaseService.instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final rows = await db.rawQuery(
      '''
      SELECT l.id, f.name, f.calories, f.fat, f.carbs, f.protein,
             l.amount, l.portions, l.loggedAt, l.date
      FROM logs l JOIN foods f ON f.id = l.foodId
      WHERE l.date >= ?
      ORDER BY l.date ASC, l.id ASC
    ''',
      [cutoffStr],
    );

    var written = 0;
    for (final r in rows) {
      // See _writeMealToHealthConnect: nutrition is perValue * amount / 100.
      // `portions` is display metadata only and must not be applied here.
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final factor = amount / 100.0;
      if (factor <= 0) continue;

      final loggedAtMs = r['loggedAt'] as int?;
      DateTime time;
      if (loggedAtMs != null) {
        time = DateTime.fromMillisecondsSinceEpoch(loggedAtMs);
      } else {
        final dateStr = r['date'] as String? ?? cutoffStr;
        time = DateTime.tryParse(dateStr) ?? DateTime.now();
      }

      final ok = await HealthService.instance.writeMeal(
        name: (r['name'] as String?) ?? 'Meal',
        calories: ((r['calories'] as num?)?.toDouble() ?? 0) * factor,
        protein: ((r['protein'] as num?)?.toDouble() ?? 0) * factor,
        carbs: ((r['carbs'] as num?)?.toDouble() ?? 0) * factor,
        fat: ((r['fat'] as num?)?.toDouble() ?? 0) * factor,
        time: time,
      );
      if (ok) written++;
    }
    return written;
  }
}
