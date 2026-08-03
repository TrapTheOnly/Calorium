import '../models/food.dart';
import '../models/imported_recipe.dart';
import 'database_service.dart';
import 'video_resolvers/video_resolver.dart';

/// Persists recipes imported from shared videos as inventory-linked compound
/// recipes (so their macros recompute from live inventory) plus a metadata row
/// holding the video, source link, and instructions.
class ImportedRecipeService {
  /// Saves a brand-new imported recipe and returns the linked food id.
  ///
  /// [components] are the inventory ingredients + amounts (in each food's unit);
  /// macros are normalized to per-100 and stored on the compound food row,
  /// exactly like the manual recipe builder.
  static Future<int> saveImportedRecipe({
    required String name,
    required bool isLiquid,
    required List<ImportedComponent> components,
    required ImportedRecipe meta,
  }) async {
    final db = await DatabaseService.instance.database;

    // The components table is keyed by (recipeId, componentId), so the same
    // inventory food appearing on two ingredient lines (e.g. oil in a sauce and
    // a garnish) must be merged first — otherwise the second insert violates the
    // primary key and aborts the whole save. Sum amounts per food id, preserving
    // first-seen order.
    final merged = <int, ImportedComponent>{};
    for (final c in components) {
      final id = c.food.id;
      if (id == null) continue;
      final existing = merged[id];
      merged[id] = existing == null
          ? c
          : ImportedComponent(food: c.food, amount: existing.amount + c.amount);
    }
    final mergedComponents = merged.values.toList();

    double totalWeight = 0, cal = 0, fat = 0, carb = 0, prot = 0;
    for (final c in mergedComponents) {
      totalWeight += c.amount;
      cal += c.food.calories * c.amount / 100;
      fat += c.food.fat * c.amount / 100;
      carb += c.food.carbs * c.amount / 100;
      prot += c.food.protein * c.amount / 100;
    }
    final factor = totalWeight > 0 ? 100 / totalWeight : 0;
    final servings = meta.servings < 1 ? 1 : meta.servings;
    final perServing = totalWeight > 0 ? totalWeight / servings : 100.0;

    return db.transaction((txn) async {
      final foodId = await txn.insert('foods', {
        'name': name,
        'calories': cal * factor,
        'fat': fat * factor,
        'carbs': carb * factor,
        'protein': prot * factor,
        'type': 'compound',
        'defaultPortionSize': perServing,
        'portionDescription': servings > 1 ? '1 serving' : 'whole recipe',
        'unit': isLiquid ? 'ml' : 'g',
        'hasServing': 1,
      });

      for (final c in mergedComponents) {
        await txn.insert('components', {
          'recipeId': foodId,
          'componentId': c.food.id,
          'amount': c.amount,
        });
      }

      final metaMap = meta.toMap()..['foodId'] = foodId;
      await txn.insert('imported_recipe_meta', metaMap);

      return foodId;
    });
  }

  /// Food ids that are imported recipes (used to tag them in the inventory).
  static Future<Set<int>> getImportedFoodIds() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('imported_recipe_meta', columns: ['foodId']);
    return rows.map((r) => r['foodId'] as int).toSet();
  }

  /// Loads the metadata for an imported recipe by its linked food id.
  static Future<ImportedRecipe?> getByFoodId(int foodId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'imported_recipe_meta',
      where: 'foodId = ?',
      whereArgs: [foodId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final foodRows = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [foodId],
      limit: 1,
    );
    final name = foodRows.isNotEmpty
        ? (foodRows.first['name']?.toString() ?? '')
        : '';
    return ImportedRecipe.fromMap(rows.first, name: name);
  }

  /// Loads the inventory-linked ingredients (food + amount) for a recipe.
  static Future<List<ImportedComponent>> getComponents(int foodId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT f.*, c.amount AS component_amount
      FROM components c
      JOIN foods f ON f.id = c.componentId
      WHERE c.recipeId = ?
    ''', [foodId]);

    return rows.map((row) {
      final amount = (row['component_amount'] as num?)?.toDouble() ?? 0.0;
      return ImportedComponent(food: Food.fromMap(row), amount: amount);
    }).toList();
  }

  /// Deletes an imported recipe entirely: its metadata, ingredient links, the
  /// linked food row, and any downloaded media files.
  static Future<void> deleteByFoodId(int foodId) async {
    final meta = await getByFoodId(foodId);
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      await txn.delete(
        'imported_recipe_meta',
        where: 'foodId = ?',
        whereArgs: [foodId],
      );
      await txn.delete('components', where: 'recipeId = ?', whereArgs: [foodId]);
      await txn.delete('foods', where: 'id = ?', whereArgs: [foodId]);
    });

    await RecipeMediaStorage.deleteFile(meta?.videoPath);
    await RecipeMediaStorage.deleteFile(meta?.thumbnailPath);
  }
}
