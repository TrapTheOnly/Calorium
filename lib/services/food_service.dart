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
  
  // Search simple foods by name
  Future<List<Food>> searchSimpleFoods(String query) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'type = ? AND isArchived = ? AND name LIKE ?',
      whereArgs: ['simple', 0, '%$query%'],
      orderBy: 'name',
    );
    
    return List.generate(maps.length, (i) {
      return Food.fromMap(maps[i]);
    });
  }
  
  // Search compound foods by name
  Future<List<Food>> searchCompoundFoods(String query) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'type = ? AND isArchived = ? AND name LIKE ?',
      whereArgs: ['compound', 0, '%$query%'],
      orderBy: 'name',
    );
    
    return List.generate(maps.length, (i) {
      return Food.fromMap(maps[i]);
    });
  }
  
  // Filter simple foods by tags and search query
  Future<List<Food>> filterSimpleFoods({String? searchQuery, List<String>? tags}) async {
    final db = await DatabaseService.instance.database;
    String whereClause = 'type = ? AND isArchived = ?';
    List<dynamic> whereArgs = ['simple', 0];
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND name LIKE ?';
      whereArgs.add('%$searchQuery%');
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name',
    );
    
    List<Food> foods = List.generate(maps.length, (i) {
      return Food.fromMap(maps[i]);
    });
    
    // Filter by tags if provided
    if (tags != null && tags.isNotEmpty) {
      foods = foods.where((food) {
        return tags.every((tag) => food.tags.contains(tag));
      }).toList();
    }
    
    return foods;
  }
  
  // Get all unique tags from simple foods
  Future<List<String>> getAllSimpleFoodTags() async {
    try {
      final db = await DatabaseService.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'foods',
        columns: ['tags'],
        where: 'type = ? AND isArchived = ?',
        whereArgs: ['simple', 0],
      );
      
      Set<String> allTags = {};
      for (var map in maps) {
        final tagsString = map['tags']?.toString() ?? '';
        if (tagsString.isNotEmpty) {
          try {
            final tags = tagsString
                .split(',')
                .where((tag) => tag.trim().isNotEmpty)
                .map((tag) => tag.trim())
                .cast<String>();
            allTags.addAll(tags);
          } catch (e) {
            // Skip this entry if parsing fails
            continue;
          }
        }
      }
      
      List<String> sortedTags = allTags.toList();
      sortedTags.sort();
      return sortedTags;
    } catch (e) {
      // Return empty list if database operation fails
      return [];
    }
  }
  
  Future<Food?> getFoodById(int id) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Food.fromMap(maps.first);
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