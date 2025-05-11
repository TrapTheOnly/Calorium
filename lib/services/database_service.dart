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
      version: 1,
      onCreate: _createDatabase,
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
        isArchived INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodId INTEGER,
        amount REAL,
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
}