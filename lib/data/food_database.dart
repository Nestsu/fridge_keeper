import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';

class FoodDatabase {
  FoodDatabase._();
  static final FoodDatabase instance = FoodDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    return _database = await openDatabase(
      p.join(dbPath, 'fridge_keeper.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE foods (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            location TEXT NOT NULL,
            purchase_date TEXT NOT NULL,
            expiry_date TEXT,
            image_path TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_foods_status_expiry ON foods(status, expiry_date)');
      },
    );
  }

  Future<List<FoodItem>> all() async {
    final db = await database;
    final rows = await db.query('foods', orderBy: 'created_at DESC');
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<void> save(FoodItem item) async {
    final db = await database;
    await db.insert('foods', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }
}
