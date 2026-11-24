class StorageFridge {
  const StorageFridge({required this.id, required this.name});
  final String id;
  final String name;
  factory StorageFridge.fromMap(Map<String, Object?> map) =>
      StorageFridge(id: map['id'] as String, name: map['name'] as String);
}

class StorageZone {
  const StorageZone({required this.id, required this.fridgeId,
    required this.name, required this.position});
  final String id;
  final String fridgeId;
  final String name;
  final int position;
  factory StorageZone.fromMap(Map<String, Object?> map) => StorageZone(
    id: map['id'] as String,
    fridgeId: map['fridge_id'] as String,
    name: map['name'] as String,
    position: (map['position'] as num).toInt(),
  );
}

String storageLabel(StorageZone zone, List<StorageFridge> fridges) {
  for (final fridge in fridges) {
    if (fridge.id == zone.fridgeId) return '${fridge.name} › ${zone.name}';
  }
  return zone.name;
}
