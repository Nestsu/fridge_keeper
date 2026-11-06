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
      version: 2,
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
        await _createUsageTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createUsageTable(db);
      },
    );
  }

  static Future<void> _createUsageTable(Database db) async {
    await db.execute('''
      CREATE TABLE usage_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        action TEXT NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        remaining REAL NOT NULL,
        recorded_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_usage_recorded_at ON usage_events(recorded_at)');
  }

  Future<List<UsageEvent>> history() async {
    final db = await database;
    final rows = await db.query('usage_events', orderBy: 'recorded_at DESC, id DESC');
    return rows.map(UsageEvent.fromMap).toList();
  }

  /// Both the stock update and its history entry succeed or fail together.
  Future<void> recordUsage(FoodItem item, {required String action, required double amount}) async {
    final db = await database;
    await db.transaction((txn) async {
      final currentRows = await txn.query('foods', where: 'id = ?', whereArgs: [item.id], limit: 1);
      if (currentRows.isEmpty) throw StateError('ไม่พบรายการอาหาร');
      final current = FoodItem.fromMap(currentRows.first);
      if (current.status != 'active') throw StateError('รายการนี้ถูกปิดแล้ว');
      if (!amount.isFinite || amount <= 0 || amount > current.quantity) {
        throw StateError('จำนวนที่ใช้ไม่ถูกต้อง');
      }
      final remaining = current.quantity - amount;
      final status = action == 'discarded' ? 'discarded' : remaining <= 0 ? 'used' : 'active';
      final now = DateTime.now();
      await txn.update('foods', current.copyWith(quantity: remaining, status: status, updatedAt: now).toMap(), where: 'id = ?', whereArgs: [item.id]);
      await txn.insert('usage_events', {
        'food_id': item.id, 'food_name': current.name, 'action': action,
        'amount': amount, 'unit': current.unit, 'remaining': remaining,
        'recorded_at': now.toIso8601String(),
      });
    });
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

class UsageEvent {
  const UsageEvent({required this.id, required this.foodName, required this.action,
    required this.amount, required this.unit, required this.remaining, required this.recordedAt});
  final int id;
  final String foodName;
  final String action;
  final double amount;
  final String unit;
  final double remaining;
  final DateTime recordedAt;

  factory UsageEvent.fromMap(Map<String, Object?> map) => UsageEvent(
    id: map['id'] as int, foodName: map['food_name'] as String,
    action: map['action'] as String, amount: (map['amount'] as num).toDouble(),
    unit: map['unit'] as String, remaining: (map['remaining'] as num).toDouble(),
    recordedAt: DateTime.parse(map['recorded_at'] as String),
  );
}
