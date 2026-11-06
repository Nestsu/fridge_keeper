import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_keeper/models/food_item.dart';

void main() {
  final item = FoodItem(
    id: 'test-1', name: 'นมสด', category: 'นม / ไข่', quantity: 2,
    unit: 'กล่อง', location: 'ช่องแช่เย็น',
    purchaseDate: DateTime(2026, 11, 5), expiryDate: DateTime(2026, 11, 8),
    createdAt: DateTime(2026, 11, 5), updatedAt: DateTime(2026, 11, 5),
  );

  test('expiry is calendar-day based', () {
    expect(item.daysUntilExpiry(DateTime(2026, 11, 5, 23, 59)), 3);
    expect(item.daysUntilExpiry(DateTime(2026, 11, 8, 12)), 0);
    expect(item.daysUntilExpiry(DateTime(2026, 11, 9)), -1);
  });

  test('round-trip map retains fields', () {
    final actual = FoodItem.fromMap(item.toMap());
    expect(actual.name, 'นมสด');
    expect(actual.quantity, 2);
    expect(actual.expiryDate, DateTime(2026, 11, 8));
  });

  test('copy with updates quantity and status', () {
    final used = item.copyWith(quantity: 0, status: 'used');
    expect(used.quantity, 0);
    expect(used.status, 'used');
    expect(item.quantity, 2);
  });
}
