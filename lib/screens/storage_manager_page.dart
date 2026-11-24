import 'package:flutter/material.dart';

import '../data/food_database.dart';
import '../models/food_item.dart';
import '../models/storage_zone.dart';

/// Manage fridges and ordered shelves. Existing food must be moved before
/// removing a location, so old inventory is never silently deleted.
class StorageManagerPage extends StatefulWidget {
  const StorageManagerPage({super.key});
  @override
  State<StorageManagerPage> createState() => _StorageManagerPageState();
}

class _StorageManagerPageState extends State<StorageManagerPage> {
  List<StorageFridge> _fridges = [];
  List<StorageZone> _zones = [];
  List<FoodItem> _foods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final fridges = await FoodDatabase.instance.fridges();
      final zones = await FoodDatabase.instance.zones();
      final foods = await FoodDatabase.instance.all();
      if (mounted) setState(() {
        _fridges = fridges;
        _zones = zones;
        _foods = foods;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _message('$e');
      }
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller, autofocus: true, maxLength: 50,
          decoration: const InputDecoration(hintText: 'ระบุชื่อ'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(
            dialogContext, controller.text.trim()),
            child: const Text('บันทึก')),
        ],
      ));
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      _message('$e');
    }
  }

  Future<bool> _confirmDelete(String description) async =>
      await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยืนยันลบตำแหน่ง?'),
          content: Text('$description\n\nหากยังมีอาหารอยู่ ระบบจะไม่อนุญาตให้ลบ'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยันลบ')),
          ],
        )) ?? false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('จัดการตู้เย็นและชั้น')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final name = await _askName('เพิ่มตู้เย็น');
        if (name != null) await _perform(() =>
            FoodDatabase.instance.addFridge(name));
      },
      icon: const Icon(Icons.add), label: const Text('เพิ่มตู้เย็น')),
    body: _loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
        const Text('กำหนดตู้เย็นและช่องเก็บของตามบ้านจริงของคุณ',
          style: TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        const Text('แตะอาหารที่ชั้นเพื่อดูรายการ ย้ายอาหารได้จากหน้าแก้ไขอาหาร',
          style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 14),
        for (final fridge in _fridges) _buildFridge(fridge),
      ]),
  );

  Widget _buildFridge(StorageFridge fridge) {
    final zones = _zones.where((z) => z.fridgeId == fridge.id).toList();
    final count = _foods.where((f) => f.status == 'active' &&
      zones.any((z) => z.id == f.zoneId)).length;
    return Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 14),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.kitchen_outlined, color: Color(0xFF20875B)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fridge.name, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$count รายการอาหาร · ${zones.length} ช่อง/ชั้น',
                  style: const TextStyle(color: Colors.black54)),
              ])),
            PopupMenuButton<String>(
              tooltip: 'จัดการตู้เย็น',
              onSelected: (action) async {
                if (action == 'rename') {
                  final name = await _askName('เปลี่ยนชื่อตู้เย็น',
                    initial: fridge.name);
                  if (name != null) await _perform(() =>
                      FoodDatabase.instance.renameFridge(fridge.id, name));
                } else if (await _confirmDelete(fridge.name)) {
                  await _perform(() =>
                      FoodDatabase.instance.deleteFridge(fridge.id));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('เปลี่ยนชื่อ')),
                PopupMenuItem(value: 'delete', child: Text('ลบตู้เย็น')),
              ],
            ),
          ]),
          const Divider(height: 20),
          if (zones.isEmpty) const Padding(
            padding: EdgeInsets.all(10), child: Text('ยังไม่มีชั้นหรือช่อง')),
          for (var i = 0; i < zones.length; i++)
            _buildZone(zones[i], i, zones.length),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มช่อง / เพิ่มชั้น'),
            onPressed: () async {
              final name = await _askName('เพิ่มช่อง / ชั้น ใน ${fridge.name}');
              if (name != null) await _perform(() =>
                  FoodDatabase.instance.addZone(fridge.id, name));
            }),
        ])),
      ));
  }

  Widget _buildZone(StorageZone zone, int index, int count) {
    final foods = _foods.where((f) =>
        f.zoneId == zone.id && f.status == 'active').toList();
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: const Icon(Icons.layers_outlined, color: Color(0xFF20875B)),
      title: Text(zone.name),
      subtitle: Text('${foods.length} รายการ'),
      children: [
        if (foods.isEmpty) const ListTile(title: Text('ชั้นนี้ยังไม่มีอาหาร')),
        for (final food in foods)
          ListTile(dense: true,
            leading: const Icon(Icons.inventory_2_outlined, size: 18),
            title: Text(food.name),
            subtitle: Text('${food.quantity} ${food.unit}')),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(tooltip: 'เลื่อนขึ้น', onPressed: index == 0 ? null :
              () => _perform(() => FoodDatabase.instance.moveZone(zone.id, -1)),
              icon: const Icon(Icons.arrow_upward)),
          IconButton(tooltip: 'เลื่อนลง',
              onPressed: index == count - 1 ? null :
                  () => _perform(() => FoodDatabase.instance.moveZone(zone.id, 1)),
              icon: const Icon(Icons.arrow_downward)),
          IconButton(tooltip: 'แก้ชื่อ', icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await _askName('เปลี่ยนชื่อชั้น',
                initial: zone.name);
              if (name != null) await _perform(() =>
                  FoodDatabase.instance.renameZone(zone.id, name));
            }),
          IconButton(tooltip: 'ลบชั้น', icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await _confirmDelete(zone.name)) {
                await _perform(() => FoodDatabase.instance.deleteZone(zone.id));
              }
            }),
        ]),
      ],
    );
  }
}
