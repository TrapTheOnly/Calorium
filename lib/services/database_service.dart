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
      version: 4, // Increased version for tags support
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
        tags TEXT DEFAULT ''
      )
    ''');
    
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodId INTEGER,
        amount REAL,
        portions REAL DEFAULT 1.0,
        date TEXT,
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
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 1 && newVersion >= 2) {
      await db.execute('ALTER TABLE foods ADD COLUMN defaultPortionSize REAL DEFAULT 100.0');
      await db.execute('ALTER TABLE foods ADD COLUMN portionDescription TEXT DEFAULT "100g"');
      
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
  }
}