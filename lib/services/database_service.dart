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
      version: 2,
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
        portionDescription TEXT DEFAULT '100g'
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
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 1 && newVersion == 2) {
      await db.execute('ALTER TABLE foods ADD COLUMN defaultPortionSize REAL DEFAULT 100.0');
      await db.execute('ALTER TABLE foods ADD COLUMN portionDescription TEXT DEFAULT "100g"');
      
      await db.execute('ALTER TABLE logs ADD COLUMN portions REAL DEFAULT 1.0');
    }
  }
}