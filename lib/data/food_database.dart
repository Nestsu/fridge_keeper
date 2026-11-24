import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';
import '../models/storage_zone.dart';

class FoodDatabase {
  FoodDatabase._();
  static final FoodDatabase instance = FoodDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    return _database = await openDatabase(
      p.join(dbPath, 'fridge_keeper.db'),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE foods (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            location TEXT NOT NULL,
            zone_id TEXT,
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
        await _createStorageTables(db);
        await _migrateLegacyLocations(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createUsageTable(db);
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE foods ADD COLUMN zone_id TEXT');
          await _createStorageTables(db);
          await _migrateLegacyLocations(db);
        }
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


  static const defaultFridgeId = 'fridge-default';

  static Future<void> _createStorageTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE storage_fridges (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE storage_zones (
        id TEXT PRIMARY KEY,
        fridge_id TEXT NOT NULL,
        name TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(fridge_id) REFERENCES storage_fridges(id)
      )
    ''');
    await db.insert('storage_fridges',
      {'id': defaultFridgeId, 'name': 'ตู้เย็นหลัก'});
  }

  /// Legacy location labels remain readable, and are assigned a matching zone.
  static Future<void> _migrateLegacyLocations(DatabaseExecutor db) async {
    final rows = await db.query('foods', columns: ['location'],
      distinct: true);
    final labels = <String>{
      'ช่องแช่เย็น', 'ช่องแช่แข็ง', 'ช่องประตู', 'ช่องผัก',
      for (final row in rows) (row['location'] as String? ?? '').trim(),
    }..remove('');
    var i = 0;
    for (final name in labels) {
      final id = 'legacy-zone-${i++}';
      await db.insert('storage_zones', {
        'id': id, 'fridge_id': defaultFridgeId,
        'name': name, 'position': i,
      });
      await db.update('foods', {'zone_id': id},
        where: 'location = ? AND zone_id IS NULL', whereArgs: [name]);
    }
  }

  Future<List<StorageFridge>> fridges() async {
    final db = await database;
    return (await db.query('storage_fridges', orderBy: 'rowid ASC'))
        .map(StorageFridge.fromMap).toList();
  }

  Future<List<StorageZone>> zones() async {
    final db = await database;
    return (await db.query('storage_zones',
      orderBy: 'fridge_id ASC, position ASC, rowid ASC'))
        .map(StorageZone.fromMap).toList();
  }

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> addFridge(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw StateError('กรุณาใส่ชื่อตู้เย็น');
    final db = await database;
    await db.insert('storage_fridges', {'id': _nextId(), 'name': clean});
  }

  Future<void> renameFridge(String id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw StateError('กรุณาใส่ชื่อตู้เย็น');
    final db = await database;
    await db.update('storage_fridges', {'name': clean},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteFridge(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final fridges = await txn.query('storage_fridges');
      if (fridges.length <= 1) throw StateError('ต้องมีตู้เย็นอย่างน้อยหนึ่งตู้');
      final zones = await txn.query('storage_zones',
        where: 'fridge_id = ?', whereArgs: [id]);
      for (final zone in zones) {
        final used = await txn.query('foods', columns: ['id'],
          where: 'zone_id = ?', whereArgs: [zone['id']], limit: 1);
        if (used.isNotEmpty) throw StateError('ย้ายอาหารออกจากตู้เย็นนี้ก่อนลบ');
      }
      await txn.delete('storage_zones', where: 'fridge_id = ?', whereArgs: [id]);
      await txn.delete('storage_fridges', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> addZone(String fridgeId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw StateError('กรุณาใส่ชื่อช่องหรือชั้น');
    final db = await database;
    final fridges = await db.query('storage_fridges',
      where: 'id = ?', whereArgs: [fridgeId], limit: 1);
    if (fridges.isEmpty) throw StateError('ไม่พบตู้เย็น');
    final current = await db.query('storage_zones', columns: ['position'],
      where: 'fridge_id = ?', whereArgs: [fridgeId],
      orderBy: 'position DESC', limit: 1);
    final position = current.isEmpty ? 0 : (current.first['position'] as int) + 1;
    await db.insert('storage_zones', {
      'id': _nextId(), 'fridge_id': fridgeId,
      'name': clean, 'position': position,
    });
  }

  Future<void> renameZone(String zoneId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw StateError('กรุณาใส่ชื่อช่องหรือชั้น');
    final db = await database;
    // Keep the legacy display label in sync for all associated food.
    await db.transaction((txn) async {
      await txn.update('storage_zones', {'name': clean},
        where: 'id = ?', whereArgs: [zoneId]);
      await txn.update('foods', {'location': clean},
        where: 'zone_id = ?', whereArgs: [zoneId]);
    });
  }

  Future<void> moveZone(String zoneId, int direction) async {
    final db = await database;
    await db.transaction((txn) async {
      final found = await txn.query('storage_zones',
        where: 'id = ?', whereArgs: [zoneId], limit: 1);
      if (found.isEmpty) return;
      final zone = found.single;
      final siblings = await txn.query('storage_zones',
        where: 'fridge_id = ?', whereArgs: [zone['fridge_id']],
        orderBy: 'position ASC, rowid ASC');
      final index = siblings.indexWhere((row) => row['id'] == zoneId);
      final target = index + direction;
      if (target < 0 || target >= siblings.length) return;
      final otherId = siblings[target]['id'] as String;
      await txn.update('storage_zones', {'position': target},
        where: 'id = ?', whereArgs: [zoneId]);
      await txn.update('storage_zones', {'position': index},
        where: 'id = ?', whereArgs: [otherId]);
    });
  }

  Future<void> deleteZone(String zoneId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Includes used/discarded stock: historical rows must not be orphaned.
      final foods = await txn.query('foods', columns: ['id'],
        where: 'zone_id = ?', whereArgs: [zoneId], limit: 1);
      if (foods.isNotEmpty) throw StateError('ย้ายอาหารออกจากชั้นนี้ก่อนลบ');
      await txn.delete('storage_zones',
        where: 'id = ?', whereArgs: [zoneId]);
    });
  }

  Future<void> moveFood(String foodId, StorageZone zone) async {
    final db = await database;
    await db.update('foods', {
      'zone_id': zone.id, 'location': zone.name,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [foodId]);
  }

  Future<List<UsageEvent>> history() async {
    final db = await database;
    final rows = await db.query('usage_events', orderBy: 'recorded_at DESC, id DESC');
    return rows.map(UsageEvent.fromMap).toList();
  }

  /// Both the stock update and its history entry succeed or fail together.
  Future<int> recordUsage(FoodItem item, {required String action, required double amount}) async {
    final db = await database;
    return db.transaction<int>((txn) async {
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
      return txn.insert('usage_events', {
        'food_id': item.id, 'food_name': current.name, 'action': action,
        'amount': amount, 'unit': current.unit, 'remaining': remaining,
        'recorded_at': now.toIso8601String(),
      });
    });
  }

  /// Undo only the latest usage event for an item, so later edits are not lost.
  Future<void> undoUsage(int eventId) async {
    final db = await database;
    await db.transaction((txn) async {
      final events = await txn.query('usage_events', where: 'id = ?', whereArgs: [eventId], limit: 1);
      if (events.isEmpty) throw StateError('ไม่พบประวัติที่ต้องการย้อนกลับ');
      final event = events.single;
      final foodId = event['food_id'] as String;
      final last = await txn.query('usage_events', columns: ['id'], where: 'food_id = ?',
        whereArgs: [foodId], orderBy: 'id DESC', limit: 1);
      if (last.isEmpty || last.single['id'] != eventId) {
        throw StateError('มีการใช้รายการนี้เพิ่มเติมแล้ว จึงไม่สามารถย้อนกลับครั้งก่อน');
      }
      final foods = await txn.query('foods', where: 'id = ?', whereArgs: [foodId], limit: 1);
      if (foods.isEmpty) throw StateError('รายการอาหารถูกลบไปแล้ว');
      final food = FoodItem.fromMap(foods.single);
      final remaining = (event['remaining'] as num).toDouble();
      if ((food.quantity - remaining).abs() > 0.000001) {
        throw StateError('จำนวนอาหารถูกแก้ไขแล้ว ไม่สามารถย้อนกลับอัตโนมัติ');
      }
      final amount = (event['amount'] as num).toDouble();
      await txn.update('foods', food.copyWith(quantity: remaining + amount,
        status: 'active', updatedAt: DateTime.now()).toMap(), where: 'id = ?', whereArgs: [foodId]);
      await txn.delete('usage_events', where: 'id = ?', whereArgs: [eventId]);
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
  const UsageEvent({required this.id, required this.foodId, required this.foodName, required this.action,
    required this.amount, required this.unit, required this.remaining, required this.recordedAt});
  final int id;
  final String foodId;
  final String foodName;
  final String action;
  final double amount;
  final String unit;
  final double remaining;
  final DateTime recordedAt;

  factory UsageEvent.fromMap(Map<String, Object?> map) => UsageEvent(
    id: map['id'] as int, foodId: map['food_id'] as String, foodName: map['food_name'] as String,
    action: map['action'] as String, amount: (map['amount'] as num).toDouble(),
    unit: map['unit'] as String, remaining: (map['remaining'] as num).toDouble(),
    recordedAt: DateTime.parse(map['recorded_at'] as String),
  );
}
