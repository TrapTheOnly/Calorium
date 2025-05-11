import 'package:sqflite/sqflite.dart';
import '../models/log_entry.dart';
import 'database_service.dart';

class LogService {
  Future<List<LogEntry>> getLogEntriesByDate(String date) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT l.id, l.foodId, l.amount, l.date, f.name, f.calories, f.fat, f.carbs, f.protein
      FROM logs l JOIN foods f ON f.id = l.foodId
      WHERE l.date = ?
    ''', [date]);
    
    return List.generate(maps.length, (i) {
      return LogEntry.fromMap(maps[i]);
    });
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
    return await db.delete(
      'logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}