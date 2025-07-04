import '../models/food.dart';
import 'database_service.dart';

class FoodService {
  Future<List<Food>> getSimpleFoods() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'type = ? AND isArchived = ?',
      whereArgs: ['simple', 0],
      orderBy: 'name',
    );
    
    return List.generate(maps.length, (i) {
      return Food.fromMap(maps[i]);
    });
  }
  
  Future<List<Food>> getCompoundFoods() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'type = ? AND isArchived = ?',
      whereArgs: ['compound', 0],
      orderBy: 'name',
    );
    
    return List.generate(maps.length, (i) {
      return Food.fromMap(maps[i]);
    });
  }
  
  Future<int> insertFood(Food food) async {
    final db = await DatabaseService.instance.database;
    return await db.insert('foods', food.toMap());
  }
  
  Future<int> updateFood(Food food) async {
    final db = await DatabaseService.instance.database;
    return await db.update(
      'foods',
      food.toMap(),
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }
  
  Future<int> deleteFood(int id) async {
    final db = await DatabaseService.instance.database;
    return await db.update(
      'foods',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}