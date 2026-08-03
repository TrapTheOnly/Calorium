import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;

  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'calories.db');
    return await openDatabase(
      path,
      version: 9, // v9: track which logs were mirrored to Health Connect
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calories REAL,
        fat REAL,
        carbs REAL,
        protein REAL,
        type TEXT DEFAULT 'simple',
        isArchived INTEGER DEFAULT 0,
        defaultPortionSize REAL DEFAULT 100.0,
        portionDescription TEXT DEFAULT '100g',
        tags TEXT DEFAULT '',
        unit TEXT DEFAULT 'g',
        hasServing INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodId INTEGER,
        amount REAL,
        portions REAL DEFAULT 1.0,
        date TEXT,
        loggedAt INTEGER,
        syncedHealth INTEGER DEFAULT 0,
        FOREIGN KEY(foodId) REFERENCES foods(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE components (
        recipeId INTEGER,
        componentId INTEGER,
        amount REAL,
        PRIMARY KEY(recipeId, componentId)
      )
    ''');

    // Custom recipes table for AI-generated recipes
    await db.execute('''
      CREATE TABLE custom_recipes (
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

    await db.execute(_createImportedRecipeMetaSql);
  }

  /// Metadata for recipes imported from a shared video link.
  ///
  /// The ingredients + macros live in the linked compound `foods` row and the
  /// `components` table (so nutrition recomputes from live inventory); this
  /// table adds the video, source link, instructions, and recipe metadata.
  static const String _createImportedRecipeMetaSql = '''
    CREATE TABLE imported_recipe_meta (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      foodId INTEGER NOT NULL,
      platform TEXT DEFAULT '',
      sourceUrl TEXT DEFAULT '',
      videoPath TEXT DEFAULT '',
      thumbnailPath TEXT DEFAULT '',
      description TEXT DEFAULT '',
      instructions TEXT NOT NULL,
      servings INTEGER DEFAULT 1,
      prepTimeMinutes INTEGER DEFAULT 0,
      cookTimeMinutes INTEGER DEFAULT 0,
      difficulty TEXT DEFAULT 'medium',
      tags TEXT DEFAULT '',
      createdAt INTEGER NOT NULL,
      FOREIGN KEY (foodId) REFERENCES foods (id) ON DELETE CASCADE
    )
  ''';

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == 1 && newVersion >= 2) {
      await db.execute(
        'ALTER TABLE foods ADD COLUMN defaultPortionSize REAL DEFAULT 100.0',
      );
      await db.execute(
        'ALTER TABLE foods ADD COLUMN portionDescription TEXT DEFAULT "100g"',
      );

      await db.execute('ALTER TABLE logs ADD COLUMN portions REAL DEFAULT 1.0');
    }

    if (oldVersion <= 2 && newVersion >= 3) {
      // Add custom recipes table
      await db.execute('''
        CREATE TABLE custom_recipes (
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

    if (oldVersion <= 3 && newVersion >= 4) {
      // Add tags support to foods table
      await db.execute('ALTER TABLE foods ADD COLUMN tags TEXT DEFAULT ""');

      // Ensure all existing records have an empty tags value
      await db.execute('UPDATE foods SET tags = "" WHERE tags IS NULL');
    }

    if (oldVersion <= 4 && newVersion >= 5) {
      await db.execute('ALTER TABLE logs ADD COLUMN loggedAt INTEGER');
      await db.execute('''
        UPDATE logs
        SET loggedAt = CAST(strftime('%s', date || ' 12:00:00') AS INTEGER) * 1000
        WHERE loggedAt IS NULL AND date IS NOT NULL
      ''');
    }

    if (oldVersion <= 5 && newVersion >= 6) {
      await db.execute("ALTER TABLE foods ADD COLUMN unit TEXT DEFAULT 'g'");
      await db.execute(
        'ALTER TABLE foods ADD COLUMN hasServing INTEGER DEFAULT 0',
      );
      // Infer base unit for existing rows from the portion description.
      await db.execute(
        "UPDATE foods SET unit = 'ml' WHERE lower(portionDescription) LIKE '%ml%'",
      );
      // Treat any food with a distinct portion size as having a serving.
      await db.execute(
        'UPDATE foods SET hasServing = 1 '
        'WHERE defaultPortionSize IS NOT NULL AND defaultPortionSize != 100.0',
      );
    }

    if (oldVersion <= 6 && newVersion >= 7) {
      await db.execute(_createImportedRecipeMetaSql);
    }

    if (oldVersion <= 7 && newVersion >= 8) {
      // Normalize custom-recipe foods to the canonical model: one serving == 100
      // nominal units, with per-serving nutrition stored in the per-100 columns.
      // Older AI recipes stored a garbage defaultPortionSize (== per-serving
      // calories), which inflated calories when logged from Inventory, while
      // the recipe detail screen always stored amount=100 (only 1 serving).
      await db.execute(
        "UPDATE foods SET defaultPortionSize = 100.0, hasServing = 1 "
        "WHERE type = 'custom_recipe'",
      );
      await db.execute('UPDATE custom_recipes SET defaultPortionSize = 100.0');
      // Rebuild each historical recipe log's amount from its stored serving
      // count (`portions`), which equals the servings for BOTH past producers
      // (detail path stored portions=servings; inventory/LogEntryScreen stored
      // portions = baseAmount/defaultPortionSize = servings). Keyed off
      // `portions` (never the old amount), so this is idempotent.
      await db.execute(
        "UPDATE logs SET amount = 100.0 * COALESCE(portions, 1) "
        "WHERE foodId IN (SELECT id FROM foods WHERE type = 'custom_recipe') "
        "AND (portions IS NULL OR portions > 0)",
      );
    }

    if (oldVersion <= 8 && newVersion >= 9) {
      // Marks which logs have already been mirrored to Health Connect so that
      // re-syncing (and re-inserting) never writes the same meal twice.
      await db.execute(
        'ALTER TABLE logs ADD COLUMN syncedHealth INTEGER DEFAULT 0',
      );
    }
  }
}
