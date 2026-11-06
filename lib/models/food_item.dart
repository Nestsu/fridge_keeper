class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.purchaseDate,
    required this.createdAt,
    required this.updatedAt,
    this.expiryDate,
    this.imagePath,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final String location;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final String? imagePath;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? daysUntilExpiry(DateTime now) {
    if (expiryDate == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final date = expiryDate!;
    return DateTime(date.year, date.month, date.day).difference(today).inDays;
  }

  FoodItem copyWith({double? quantity, String? status, DateTime? updatedAt}) => FoodItem(
        id: id, name: name, category: category, quantity: quantity ?? this.quantity,
        unit: unit, location: location, purchaseDate: purchaseDate,
        expiryDate: expiryDate, imagePath: imagePath,
        status: status ?? this.status, createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id, 'name': name, 'category': category, 'quantity': quantity,
        'unit': unit, 'location': location,
        'purchase_date': purchaseDate.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'image_path': imagePath, 'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory FoodItem.fromMap(Map<String, Object?> map) => FoodItem(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] as String,
        location: map['location'] as String,
        purchaseDate: DateTime.parse(map['purchase_date'] as String),
        expiryDate: map['expiry_date'] == null ? null : DateTime.parse(map['expiry_date'] as String),
        imagePath: map['image_path'] as String?,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
