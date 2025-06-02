 import '../models/custom_recipe.dart';
import '../models/food.dart';
import 'database_service.dart';

class CustomRecipeService {
  /// Save a new custom recipe to the database
  static Future<int> saveCustomRecipe(CustomRecipe recipe) async {
    final db = await DatabaseService.instance.database;
    
    // First save as a food item for integration with existing system
    final foodId = await db.insert('foods', {
      'name': recipe.name,
      'calories': recipe.calories / recipe.servings, // Per serving nutrition
      'fat': recipe.fat / recipe.servings,
      'carbs': recipe.carbs / recipe.servings,
      'protein': recipe.protein / recipe.servings,
      'type': 'custom_recipe',
      'defaultPortionSize': recipe.defaultPortionSize,
      'portionDescription': recipe.portionDescription,
    });

    // Then save the full recipe details
    final recipeData = recipe.toMap();
    recipeData['foodId'] = foodId; // Link to the food entry
    recipeData.remove('id'); // Remove id for insertion
    
    final recipeId = await db.insert('custom_recipes', recipeData);
    
    return recipeId;
  }

  /// Get all custom recipes
  static Future<List<CustomRecipe>> getAllCustomRecipes() async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => CustomRecipe.fromMap(map)).toList();
  }

  /// Get custom recipes by tag
  static Future<List<CustomRecipe>> getRecipesByTag(String tag) async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      where: 'tags LIKE ?',
      whereArgs: ['%$tag%'],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => CustomRecipe.fromMap(map)).toList();
  }

  /// Get favorite recipes
  static Future<List<CustomRecipe>> getFavoriteRecipes() async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => CustomRecipe.fromMap(map)).toList();
  }

  /// Search recipes by name or ingredients
  static Future<List<CustomRecipe>> searchRecipes(String query) async {
    final db = await DatabaseService.instance.database;
    
    final searchTerm = '%${query.toLowerCase()}%';
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      where: 'LOWER(name) LIKE ? OR LOWER(ingredients) LIKE ? OR LOWER(description) LIKE ?',
      whereArgs: [searchTerm, searchTerm, searchTerm],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => CustomRecipe.fromMap(map)).toList();
  }

  /// Update a custom recipe
  static Future<void> updateCustomRecipe(CustomRecipe recipe) async {
    final db = await DatabaseService.instance.database;
    
    await db.update(
      'custom_recipes',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );

    // Also update the corresponding food entry
    if (recipe.id != null) {
      await db.update(
        'foods',
        {
          'name': recipe.name,
          'calories': recipe.calories / recipe.servings,
          'fat': recipe.fat / recipe.servings,
          'carbs': recipe.carbs / recipe.servings,
          'protein': recipe.protein / recipe.servings,
          'defaultPortionSize': recipe.defaultPortionSize,
          'portionDescription': recipe.portionDescription,
        },
        where: 'id = (SELECT foodId FROM custom_recipes WHERE id = ?)',
        whereArgs: [recipe.id],
      );
    }
  }

  /// Toggle favorite status
  static Future<void> toggleFavorite(int recipeId) async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> result = await db.query(
      'custom_recipes',
      columns: ['isFavorite'],
      where: 'id = ?',
      whereArgs: [recipeId],
    );
    
    if (result.isNotEmpty) {
      final currentStatus = result.first['isFavorite'] == 1;
      await db.update(
        'custom_recipes',
        {'isFavorite': currentStatus ? 0 : 1},
        where: 'id = ?',
        whereArgs: [recipeId],
      );
    }
  }

  /// Delete a custom recipe
  static Future<void> deleteCustomRecipe(int recipeId) async {
    final db = await DatabaseService.instance.database;
    
    // Get the foodId before deleting
    final List<Map<String, dynamic>> result = await db.query(
      'custom_recipes',
      columns: ['foodId'],
      where: 'id = ?',
      whereArgs: [recipeId],
    );
    
    if (result.isNotEmpty) {
      final foodId = result.first['foodId'];
      
      // Delete from custom_recipes table
      await db.delete(
        'custom_recipes',
        where: 'id = ?',
        whereArgs: [recipeId],
      );
      
      // Delete from foods table
      await db.delete(
        'foods',
        where: 'id = ?',
        whereArgs: [foodId],
      );
    }
  }

  /// Get a single recipe by ID
  static Future<CustomRecipe?> getRecipeById(int recipeId) async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      where: 'id = ?',
      whereArgs: [recipeId],
    );
    
    if (maps.isNotEmpty) {
      return CustomRecipe.fromMap(maps.first);
    }
    return null;
  }

  /// Get recipes by difficulty
  static Future<List<CustomRecipe>> getRecipesByDifficulty(String difficulty) async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      where: 'difficulty = ?',
      whereArgs: [difficulty],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => CustomRecipe.fromMap(map)).toList();
  }

  /// Get recipes by cooking time range
  static Future<List<CustomRecipe>> getRecipesByTimeRange(int minMinutes, int maxMinutes) async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_recipes',
      where: '(prepTimeMinutes + cookTimeMinutes) BETWEEN ? AND ?',
      whereArgs: [minMinutes, maxMinutes],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => CustomRecipe.fromMap(map)).toList();
  }

  /// Get statistics about custom recipes
  static Future<Map<String, dynamic>> getRecipeStatistics() async {
    final db = await DatabaseService.instance.database;
    
    final totalRecipes = await db.rawQuery('SELECT COUNT(*) as count FROM custom_recipes');
    final favoriteRecipes = await db.rawQuery('SELECT COUNT(*) as count FROM custom_recipes WHERE isFavorite = 1');
    final avgCookTime = await db.rawQuery('SELECT AVG(prepTimeMinutes + cookTimeMinutes) as avg FROM custom_recipes');
    
    // Get most used tags
    final allTags = await db.rawQuery('SELECT tags FROM custom_recipes WHERE tags != ""');
    Map<String, int> tagCounts = {};
    for (var row in allTags) {
      final tags = (row['tags'] as String).split('|');
      for (var tag in tags) {
        if (tag.isNotEmpty) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    
    return {
      'totalRecipes': totalRecipes.first['count'],
      'favoriteRecipes': favoriteRecipes.first['count'],
      'averageCookTime': avgCookTime.first['avg'] ?? 0,
      'popularTags': tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
    };
  }

  /// Initialize the custom recipes table
  static Future<void> initializeCustomRecipesTable() async {
    final db = await DatabaseService.instance.database;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodId INTEGER,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        instructions TEXT NOT NULL,
        calories REAL NOT NULL,
        fat REAL NOT NULL,
        carbs REAL NOT NULL,
        protein REAL NOT NULL,
        prepTimeMinutes INTEGER NOT NULL,
        cookTimeMinutes INTEGER NOT NULL,
        servings INTEGER NOT NULL,
        difficulty TEXT DEFAULT 'medium',
        tags TEXT DEFAULT '',
        aiGeneratedPrompt TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        isFavorite INTEGER DEFAULT 0,
        defaultPortionSize REAL DEFAULT 100.0,
        portionDescription TEXT DEFAULT '1 serving',
        FOREIGN KEY (foodId) REFERENCES foods (id) ON DELETE CASCADE
      )
    ''');
  }
}