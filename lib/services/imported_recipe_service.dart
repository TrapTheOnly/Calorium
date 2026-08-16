import '../models/food.dart';
import '../models/imported_ingredient_line.dart';
import '../models/imported_recipe.dart';
import 'database_service.dart';
import 'video_resolvers/video_resolver.dart';

/// Persists recipes imported from shared videos as inventory-linked compound
/// recipes (so their macros recompute from live inventory) plus a metadata row
/// holding the video, source link, and instructions.
class ImportedRecipeService {
  /// Saves a brand-new imported recipe and returns the linked food id.
  ///
  /// Prefer [lines] (full parsed provenance). [components] is kept so older
  /// callers still compile; when [lines] is omitted, each component is stored
  /// as an inventory-matched line.
  static Future<int> saveImportedRecipe({
    required String name,
    required bool isLiquid,
    List<ImportedComponent> components = const [],
    List<ImportedIngredientLine>? lines,
    required ImportedRecipe meta,
  }) async {
    final db = await DatabaseService.instance.database;
    return db.transaction((txn) async {
      return _insertRecipe(
        txn,
        name: name,
        isLiquid: isLiquid,
        lines: lines,
        components: components,
        meta: meta,
      );
    });
  }

  /// Replaces ingredients, macros, and metadata for an existing imported recipe.
  static Future<void> updateImportedRecipe({
    required int foodId,
    required String name,
    required bool isLiquid,
    required List<ImportedIngredientLine> lines,
    required ImportedRecipe meta,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await _deleteEstimateFoods(txn, foodId);
      await txn.delete(
        'imported_ingredient_lines',
        where: 'recipeFoodId = ?',
        whereArgs: [foodId],
      );
      await txn.delete('components', where: 'recipeId = ?', whereArgs: [foodId]);

      final prepared = await _materializeLines(txn, lines);
      final merged = _mergeComponents(prepared.components);
      final macros = _macrosFrom(merged, meta.servings);

      await txn.update(
        'foods',
        {
          'name': name,
          'calories': macros.calories,
          'fat': macros.fat,
          'carbs': macros.carbs,
          'protein': macros.protein,
          'defaultPortionSize': macros.perServing,
          'portionDescription':
              meta.servings > 1 ? '1 serving' : 'whole recipe',
          'unit': isLiquid ? 'ml' : 'g',
          'hasServing': 1,
        },
        where: 'id = ?',
        whereArgs: [foodId],
      );

      await _insertComponents(txn, foodId, merged);
      await _insertLines(txn, foodId, prepared.lines);

      final existing = await txn.query(
        'imported_recipe_meta',
        where: 'foodId = ?',
        whereArgs: [foodId],
        limit: 1,
      );
      final metaMap = meta.toMap()..['foodId'] = foodId;
      if (existing.isEmpty) {
        await txn.insert('imported_recipe_meta', metaMap);
      } else {
        metaMap.remove('createdAt');
        await txn.update(
          'imported_recipe_meta',
          metaMap,
          where: 'foodId = ?',
          whereArgs: [foodId],
        );
      }
    });
  }

  /// Updates metadata only (name, instructions, servings, tags, difficulty).
  static Future<void> updateImportedRecipeMeta({
    required int foodId,
    required ImportedRecipe meta,
    String? name,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      if (name != null && name.trim().isNotEmpty) {
        await txn.update(
          'foods',
          {'name': name.trim()},
          where: 'id = ?',
          whereArgs: [foodId],
        );
      }
      final metaMap = meta.toMap()..['foodId'] = foodId;
      metaMap.remove('createdAt');
      await txn.update(
        'imported_recipe_meta',
        metaMap,
        where: 'foodId = ?',
        whereArgs: [foodId],
      );
    });
  }

  /// Food ids that are imported recipes (used to tag them in the inventory).
  static Future<Set<int>> getImportedFoodIds() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('imported_recipe_meta', columns: ['foodId']);
    return rows.map((r) => r['foodId'] as int).toSet();
  }

  /// All imported recipes, newest first — for the shared recipes library.
  static Future<List<ImportedRecipe>> getAll() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT m.*, f.name AS food_name
      FROM imported_recipe_meta m
      LEFT JOIN foods f ON f.id = m.foodId
      ORDER BY m.createdAt DESC
    ''');
    return rows
        .map(
          (row) => ImportedRecipe.fromMap(
            row,
            name: row['food_name']?.toString() ?? '',
          ),
        )
        .toList();
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

  /// Loads every original parsed line, including skipped / spice / estimated.
  static Future<List<ImportedIngredientLine>> getLines(int foodId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'imported_ingredient_lines',
      where: 'recipeFoodId = ?',
      whereArgs: [foodId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    if (rows.isEmpty) return const [];

    final ids = rows
        .map((r) => r['linkedFoodId'] as int?)
        .whereType<int>()
        .toSet();
    final foodsById = <int, Food>{};
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(',');
      final foodRows = await db.query(
        'foods',
        where: 'id IN ($placeholders)',
        whereArgs: ids.toList(),
      );
      for (final row in foodRows) {
        final food = Food.fromMap(row);
        if (food.id != null) foodsById[food.id!] = food;
      }
    }

    return rows
        .map(
          (row) => ImportedIngredientLine.fromMap(
            row,
            linkedFood: foodsById[row['linkedFoodId'] as int?],
          ),
        )
        .toList();
  }

  /// Deletes an imported recipe entirely: its metadata, ingredient links, the
  /// linked food row, hidden estimate foods, and any downloaded media files.
  static Future<void> deleteByFoodId(int foodId) async {
    final meta = await getByFoodId(foodId);
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      await _deleteEstimateFoods(txn, foodId);
      await txn.delete(
        'imported_ingredient_lines',
        where: 'recipeFoodId = ?',
        whereArgs: [foodId],
      );
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

  static Future<int> _insertRecipe(
    dynamic txn, {
    required String name,
    required bool isLiquid,
    required List<ImportedIngredientLine>? lines,
    required List<ImportedComponent> components,
    required ImportedRecipe meta,
  }) async {
    final prepared = lines != null
        ? await _materializeLines(txn, lines)
        : _PreparedLines(
            lines: [
              for (final c in components)
                ImportedIngredientLine(
                  parsedName: c.food.name,
                  amountGrams: c.amount,
                  unit: c.food.unit,
                  matchType: IngredientMatchType.inventory,
                  linkedFood: c.food,
                ),
            ],
            components: components,
          );

    final merged = _mergeComponents(prepared.components);
    final macros = _macrosFrom(merged, meta.servings);

    final foodId = await txn.insert('foods', {
      'name': name,
      'calories': macros.calories,
      'fat': macros.fat,
      'carbs': macros.carbs,
      'protein': macros.protein,
      'type': 'compound',
      'defaultPortionSize': macros.perServing,
      'portionDescription': meta.servings > 1 ? '1 serving' : 'whole recipe',
      'unit': isLiquid ? 'ml' : 'g',
      'hasServing': 1,
    });

    await _insertComponents(txn, foodId, merged);
    await _insertLines(txn, foodId, prepared.lines);

    final metaMap = meta.toMap()..['foodId'] = foodId;
    await txn.insert('imported_recipe_meta', metaMap);
    return foodId as int;
  }

  static Future<_PreparedLines> _materializeLines(
    dynamic txn,
    List<ImportedIngredientLine> lines,
  ) async {
    final resolved = <ImportedIngredientLine>[];
    final components = <ImportedComponent>[];

    for (final line in lines) {
      if (line.matchType == IngredientMatchType.estimated &&
          line.estimate != null) {
        final estimateId = await txn.insert('foods', {
          'name': line.parsedName,
          'calories': line.estimate!.calories,
          'fat': line.estimate!.fat,
          'carbs': line.estimate!.carbs,
          'protein': line.estimate!.protein,
          'type': 'estimate',
          'isArchived': 1,
          'defaultPortionSize': 100.0,
          'portionDescription': '100${line.unit}',
          'unit': line.unit,
          'hasServing': 0,
        });
        final food = Food(
          id: estimateId as int,
          name: line.parsedName,
          calories: line.estimate!.calories,
          fat: line.estimate!.fat,
          carbs: line.estimate!.carbs,
          protein: line.estimate!.protein,
          type: 'estimate',
          isArchived: true,
          unit: line.unit,
        );
        final stored = line.copyWith(
          linkedFood: food,
          matchType: IngredientMatchType.estimated,
        );
        resolved.add(stored);
        if (stored.amountGrams > 0) {
          components.add(ImportedComponent(food: food, amount: stored.amountGrams));
        }
        continue;
      }

      resolved.add(line);
      final food = line.linkedFood;
      if (line.matchType == IngredientMatchType.inventory &&
          food?.id != null &&
          line.amountGrams > 0) {
        components.add(ImportedComponent(food: food!, amount: line.amountGrams));
      }
    }

    return _PreparedLines(lines: resolved, components: components);
  }

  static List<ImportedComponent> _mergeComponents(
    List<ImportedComponent> components,
  ) {
    final merged = <int, ImportedComponent>{};
    for (final c in components) {
      final id = c.food.id;
      if (id == null) continue;
      final existing = merged[id];
      merged[id] = existing == null
          ? c
          : ImportedComponent(food: c.food, amount: existing.amount + c.amount);
    }
    return merged.values.toList();
  }

  static _RecipeMacros _macrosFrom(
    List<ImportedComponent> components,
    int servingsRaw,
  ) {
    double totalWeight = 0, cal = 0, fat = 0, carb = 0, prot = 0;
    for (final c in components) {
      totalWeight += c.amount;
      cal += c.food.calories * c.amount / 100;
      fat += c.food.fat * c.amount / 100;
      carb += c.food.carbs * c.amount / 100;
      prot += c.food.protein * c.amount / 100;
    }
    final factor = totalWeight > 0 ? 100 / totalWeight : 0;
    final servings = servingsRaw < 1 ? 1 : servingsRaw;
    return _RecipeMacros(
      calories: cal * factor,
      fat: fat * factor,
      carbs: carb * factor,
      protein: prot * factor,
      perServing: totalWeight > 0 ? totalWeight / servings : 100.0,
    );
  }

  static Future<void> _insertComponents(
    dynamic txn,
    int foodId,
    List<ImportedComponent> components,
  ) async {
    for (final c in components) {
      await txn.insert('components', {
        'recipeId': foodId,
        'componentId': c.food.id,
        'amount': c.amount,
      });
    }
  }

  static Future<void> _insertLines(
    dynamic txn,
    int foodId,
    List<ImportedIngredientLine> lines,
  ) async {
    for (var i = 0; i < lines.length; i++) {
      await txn.insert(
        'imported_ingredient_lines',
        lines[i].toMap(recipeFoodId: foodId, sortOrder: i),
      );
    }
  }

  static Future<void> _deleteEstimateFoods(dynamic txn, int recipeFoodId) async {
    final rows = await txn.query(
      'imported_ingredient_lines',
      columns: ['linkedFoodId', 'matchType'],
      where: 'recipeFoodId = ?',
      whereArgs: [recipeFoodId],
    );
    for (final row in rows) {
      if (row['matchType']?.toString() != IngredientMatchType.estimated.name) {
        continue;
      }
      final id = row['linkedFoodId'] as int?;
      if (id == null) continue;
      await txn.delete('foods', where: 'id = ? AND type = ?', whereArgs: [id, 'estimate']);
    }
  }
}

class _PreparedLines {
  final List<ImportedIngredientLine> lines;
  final List<ImportedComponent> components;
  const _PreparedLines({required this.lines, required this.components});
}

class _RecipeMacros {
  final double calories;
  final double fat;
  final double carbs;
  final double protein;
  final double perServing;
  const _RecipeMacros({
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
    required this.perServing,
  });
}
