import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_keeper/models/food_item.dart';
import 'package:fridge_keeper/models/storage_zone.dart';

void main() {
  test('food zone survives SQLite map round-trip and quantity changes', () {
    final now = DateTime(2026, 11, 24);
    final item = FoodItem(
      id: 'test-zone', name: 'โยเกิร์ต', category: 'นม / ไข่',
      quantity: 3, unit: 'ถ้วย', location: 'ชั้นที่ 2',
      zoneId: 'zone-123', purchaseDate: now,
      createdAt: now, updatedAt: now,
    );
    final restored = FoodItem.fromMap(item.toMap());
    expect(restored.zoneId, 'zone-123');
    expect(restored.location, 'ชั้นที่ 2');
    expect(restored.copyWith(quantity: 2).zoneId, 'zone-123');
  });

  test('old food maps without zone_id remain readable', () {
    final item = FoodItem.fromMap({
      'id': 'old-1', 'name': 'นม', 'category': 'ทั่วไป',
      'quantity': 2.0, 'unit': 'กล่อง', 'location': 'ช่องแช่เย็น',
      'purchase_date': '2026-11-06T00:00:00.000',
      'expiry_date': null, 'image_path': null, 'status': 'active',
      'created_at': '2026-11-06T00:00:00.000',
      'updated_at': '2026-11-06T00:00:00.000',
    });
    expect(item.zoneId, isNull);
    expect(item.location, 'ช่องแช่เย็น');
  });

  test('storage label includes fridge name', () {
    const fridge = StorageFridge(id: 'fridge-1', name: 'ตู้เย็นห้องครัว');
    const zone = StorageZone(id: 'zone-1', fridgeId: 'fridge-1',
      name: 'ชั้นที่ 2', position: 1);
    expect(storageLabel(zone, [fridge]), 'ตู้เย็นห้องครัว › ชั้นที่ 2');
  });
}
