import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/food_database.dart';
import 'models/food_item.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FridgeKeeperApp());
}

const seedGreen = Color(0xFF20875B);
const categories = ['ทั่วไป', 'ผัก / ผลไม้', 'เนื้อสัตว์', 'นม / ไข่', 'อาหารปรุงสุก', 'เครื่องดื่ม', 'อื่น ๆ'];
const locations = ['ช่องแช่เย็น', 'ช่องแช่แข็ง', 'ช่องประตู', 'ช่องผัก', 'อื่น ๆ'];
const units = ['ชิ้น', 'กล่อง', 'ขวด', 'ถุง', 'แพ็ก', 'ฟอง', 'ถ้วย', 'กรัม', 'กก.', 'ลิตร'];

String formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';
String formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

class FridgeKeeperApp extends StatelessWidget {
  const FridgeKeeperApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fridge Keeper',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seedGreen),
          scaffoldBackgroundColor: const Color(0xFFF7F9F7),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F9F7)),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FoodItem> _items = [];
  List<UsageEvent> _events = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  String _query = '';
  String _filter = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final items = await FoodDatabase.instance.all();
      final events = await FoodDatabase.instance.history();
      if (mounted) setState(() { _items = items; _events = events; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _openEditor([FoodItem? item]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FoodEditor(item: item)));
    if (saved == true) await _reload();
  }

  Future<void> _useItem(FoodItem item, {required String action, required double amount}) async {
    // Confirm before an action removes the item from the active inventory.
    if (action == 'discarded' || amount >= item.quantity) {
      final discard = action == 'discarded';
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(discard ? 'ยืนยันทิ้งอาหาร?' : 'ยืนยันใช้ของหมด?'),
        content: Text('${item.name}\n${discard ? 'ทิ้ง' : 'ใช้'} ${formatQty(amount)} ${item.unit}\n\nรายการนี้จะหายจากอาหารคงเหลือ แต่ยังมีประวัติการใช้และสามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(discard ? 'ยืนยันทิ้ง' : 'ยืนยันใช้หมด')),
        ],
      ));
      if (confirmed != true || !mounted) return;
    }
    try {
      final eventId = await FoodDatabase.instance.recordUsage(item, action: action, amount: amount);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${action == 'discarded' ? 'บันทึกการทิ้ง' : 'ใช้ไป'} ${formatQty(amount)} ${item.unit} · ${item.name}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'เลิกทำ', onPressed: () => _undoUse(eventId)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    }
  }

  Future<void> _undoUse(int eventId) async {
    try {
      await FoodDatabase.instance.undoUsage(eventId);
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คืนจำนวนอาหารและยกเลิกประวัติแล้ว')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ย้อนกลับไม่สำเร็จ: $e')));
    }
  }

  Future<void> _askAmount(FoodItem item) async {
    final controller = TextEditingController(text: item.quantity < 1 ? formatQty(item.quantity) : '1');
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<double>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('ใช้ ${item.name}'),
      content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('มีอยู่ ${formatQty(item.quantity)} ${item.unit}'),
        const SizedBox(height: 14),
        TextFormField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'จำนวนที่ใช้ (${item.unit})'),
          validator: (value) {
            final number = double.tryParse((value ?? '').trim());
            if (number == null || !number.isFinite || number <= 0 || number > item.quantity) {
              return 'กรอกจำนวนมากกว่า 0 ไม่เกิน ${formatQty(item.quantity)}';
            }
            return null;
          }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
        FilledButton(onPressed: () {
          if (formKey.currentState!.validate()) Navigator.pop(dialogContext, double.parse(controller.text.trim()));
        }, child: const Text('บันทึกการใช้')),
      ],
    ));
    controller.dispose();
    if (amount != null && mounted) await _useItem(item, action: 'used', amount: amount);
  }

  Future<void> _remove(FoodItem item) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ลบรายการถาวร?'),
      content: Text('ลบ ${item.name} ออกจากข้อมูล (กู้คืนไม่ได้)'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ'))],
    ));
    if (confirmed != true) return;
    try { await FoodDatabase.instance.delete(item.id); await _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e'))); }
  }

  Future<void> _showActions(FoodItem item) async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(item.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('แก้ไขข้อมูล'), onTap: () { Navigator.pop(sheetContext); _openEditor(item); }),
        if (item.status == 'active') ...[
          ListTile(leading: const Icon(Icons.remove_circle_outline), title: Text('ใช้ไป 1 ${item.unit}'), onTap: () {
            Navigator.pop(sheetContext);
            _useItem(item, action: 'used', amount: item.quantity < 1 ? item.quantity : 1);
          }),
          ListTile(leading: const Icon(Icons.edit_note_outlined), title: const Text('ระบุจำนวนที่ใช้เอง'),
            subtitle: Text('เลือกจำนวนได้สูงสุด ${formatQty(item.quantity)} ${item.unit}'),
            onTap: () { Navigator.pop(sheetContext); _askAmount(item); }),
          ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('ใช้หมดแล้ว'), onTap: () { Navigator.pop(sheetContext); _useItem(item, action: 'used', amount: item.quantity); }),
          ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('ทิ้งแล้ว'), onTap: () { Navigator.pop(sheetContext); _useItem(item, action: 'discarded', amount: item.quantity); }),
        ],
        ListTile(leading: const Icon(Icons.delete_forever_outlined, color: Colors.red), title: const Text('ลบรายการ'), onTap: () { Navigator.pop(sheetContext); _remove(item); }),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = _items.where((x) => x.status == 'active').toList()
      ..sort((a, b) {
        final ad = a.expiryDate, bd = b.expiryDate;
        if (ad == null && bd == null) return b.createdAt.compareTo(a.createdAt);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    final urgent = active.where((x) { final d = x.daysUntilExpiry(now); return d != null && d >= 0 && d <= 3; }).length;
    final expired = active.where((x) { final d = x.daysUntilExpiry(now); return d != null && d < 0; }).length;
    final shown = active.where((x) {
      final matchSearch = x.name.toLowerCase().contains(_query.trim().toLowerCase());
      return matchSearch && (_filter == 'ทั้งหมด' || x.category == _filter);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Row(children: [Icon(Icons.kitchen, color: seedGreen), SizedBox(width: 10), Text('Fridge Keeper')]),
        actions: [IconButton(tooltip: 'รีเฟรช', onPressed: _reload, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('เปิดฐานข้อมูลไม่ได้\n$_error')))
        : RefreshIndicator(onRefresh: _reload, child: CustomScrollView(slivers: [
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 8), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_tab == 0) ...[
                const Text('ตู้เย็นของฉัน', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('เช็กก่อนซื้อ กินก่อนหมด ลดของเสีย', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard('รายการอาหาร', '${active.length}', Icons.inventory_2_outlined, seedGreen)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard('ใกล้หมด', '$urgent', Icons.schedule, Colors.orange.shade800)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard('เลยวัน', '$expired', Icons.warning_amber, Colors.red.shade700)),
                ]),
                const SizedBox(height: 10),
                if (urgent + expired > 0) Card(color: const Color(0xFFFFF0E1), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  const Icon(Icons.notifications_active_outlined, color: Color(0xFFAD5600)), const SizedBox(width: 10),
                  Expanded(child: Text('มี ${urgent + expired} รายการที่ควรตรวจสอบก่อนกิน', style: const TextStyle(fontWeight: FontWeight.w700))),
                ]))),
                const SizedBox(height: 10),
                const Text('ควรจัดการก่อน', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              ] else ...[
                Text(_tab == 1 ? 'อาหารทั้งหมด' : 'ประวัติการใช้', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_tab == 2 && _events.isNotEmpty) ...[
                  Text('บันทึกแล้ว ${_events.length} ครั้ง · ใช้ ${_events.where((e) => e.action == 'used').length} ครั้ง · ทิ้ง ${_events.where((e) => e.action == 'discarded').length} ครั้ง',
                    style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                ],
              ],
              if (_tab != 2) ...[
                TextField(onChanged: (v) => setState(() => _query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ค้นหาชื่ออาหาร...')),
                const SizedBox(height: 8),
                SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: ['ทั้งหมด', ...categories].map((c) => Padding(
                  padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(c), selected: _filter == c, onSelected: (_) => setState(() => _filter = c)),
                )).toList())),
              ],
              const SizedBox(height: 6),
            ]))),
            if (_tab == 2) ...[
              if (_events.isEmpty) const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('ยังไม่มีประวัติการใช้\nลองกดใช้ไป 1 หน่วยจากรายการอาหาร', textAlign: TextAlign.center)))
              else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), sliver: SliverList.builder(itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final date = event.recordedAt;
                  final previousDate = index == 0 ? null : _events[index - 1].recordedAt;
                  final showDate = previousDate == null || date.year != previousDate.year || date.month != previousDate.month || date.day != previousDate.day;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (showDate) Padding(padding: const EdgeInsets.fromLTRB(5, 12, 0, 8), child: Text(formatDate(date), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                    UsageEventCard(event: event,
                      onUndo: _events.take(index).any((e) => e.foodId == event.foodId) ? null : () => _undoUse(event.id)),
                  ]);
                })),
            ] else if (shown.isEmpty) SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.kitchen_outlined, size: 64, color: Colors.black26), const SizedBox(height: 10),
              Text(_items.isEmpty ? 'ยังไม่มีอาหารในตู้เย็น\nกด + เพื่อเพิ่มรายการแรก' : 'ไม่มีรายการที่ตรงกับตัวกรอง', textAlign: TextAlign.center),
            ]))))
            else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 100), sliver: SliverList.builder(itemCount: shown.length, itemBuilder: (ctx, i) => FoodCard(
              item: shown[i], now: now, onTap: () => _showActions(shown[i]),
              onQuickUse: () => _useItem(shown[i], action: 'used', amount: shown[i].quantity < 1 ? shown[i].quantity : 1),
            ))),
          ])),
      floatingActionButton: _tab == 2 ? null : FloatingActionButton.small(
        tooltip: 'เพิ่มอาหาร', onPressed: () => _openEditor(), child: const Icon(Icons.add)),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (v) => setState(() { _tab = v; _query = ''; _filter = 'ทั้งหมด'; }), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'หน้าหลัก'),
        NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'อาหาร'),
        NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5), child: Column(children: [
    Icon(icon, color: color, size: 22), const SizedBox(height: 3), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 12)),
  ])));
}

class UsageEventCard extends StatelessWidget {
  const UsageEventCard({super.key, required this.event, this.onUndo});
  final UsageEvent event;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final discarded = event.action == 'discarded';
    final date = event.recordedAt;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(elevation: 0, color: Colors.white, margin: const EdgeInsets.only(bottom: 9), child: Padding(
      padding: const EdgeInsets.all(14), child: Row(children: [
        CircleAvatar(backgroundColor: discarded ? const Color(0xFFFFE8E8) : const Color(0xFFE5F3EA),
          child: Icon(discarded ? Icons.delete_outline : Icons.remove_circle_outline, color: discarded ? Colors.red : seedGreen)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.foodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 3),
          Text('${discarded ? 'ทิ้ง' : 'ใช้ไป'} ${formatQty(event.amount)} ${event.unit} · เหลือ ${formatQty(event.remaining)} ${event.unit}', style: const TextStyle(fontSize: 12)),
          Text('${formatDate(date)} เวลา $time', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ])),
        if (onUndo != null) IconButton(tooltip: 'ยกเลิกการใช้ครั้งนี้',
          onPressed: onUndo, icon: const Icon(Icons.undo), color: seedGreen),
      ]),
    ));
  }
}

class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.item, required this.now, required this.onTap, required this.onQuickUse});
  final FoodItem item;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onQuickUse;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry(now);
    final label = item.status == 'used' ? 'ใช้หมดแล้ว' : item.status == 'discarded' ? 'ทิ้งแล้ว'
      : days == null ? 'ไม่ระบุวัน' : days < 0 ? 'เลยวัน ${-days} วัน' : days == 0 ? 'ครบกำหนดวันนี้' : 'อีก $days วัน';
    final color = item.status != 'active' || days == null ? Colors.grey : days < 0 ? Colors.red : days <= 3 ? Colors.deepOrange : Colors.green;
    return Card(elevation: 0, color: Colors.white, margin: const EdgeInsets.only(bottom: 9), child: InkWell(
      borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56, child: item.imagePath == null
          ? const ColoredBox(color: Color(0xFFE8F3EB), child: Icon(Icons.restaurant, color: seedGreen))
          : Image.file(File(item.imagePath!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFFE8F3EB), child: Icon(Icons.broken_image_outlined))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3), Text('${formatQty(item.quantity)} ${item.unit} · ${item.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 5), Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ])),
        IconButton.filledTonal(
          tooltip: 'ใช้ไป ${item.quantity < 1 ? formatQty(item.quantity) : '1'} ${item.unit}',
          onPressed: onQuickUse,
          icon: const Icon(Icons.remove, size: 20),
          visualDensity: VisualDensity.compact,
        ),
        const Icon(Icons.chevron_right, color: Colors.black38, size: 18),
      ])),
    ));
  }
}

class FoodEditor extends StatefulWidget {
  const FoodEditor({super.key, this.item});
  final FoodItem? item;
  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends State<FoodEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late String _category, _unit, _location;
  late DateTime _purchase;
  DateTime? _expiry;
  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _quantity = TextEditingController(text: item == null ? '1' : formatQty(item.quantity));
    _category = item?.category ?? categories.first;
    _unit = item?.unit ?? units.first;
    _location = item?.location ?? locations.first;
    _purchase = item?.purchaseDate ?? DateTime.now();
    _expiry = item?.expiryDate;
    _imagePath = item?.imagePath;
  }

  @override
  void dispose() { _name.dispose(); _quantity.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1200);
      if (image == null) return;
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'food_photos'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}${p.extension(image.path)}');
      await File(image.path).copy(target);
      if (mounted) setState(() => _imagePath = target);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เลือกรูปไม่สำเร็จ: $e')));
    }
  }

  Future<void> _pickDate({required bool expiry}) async {
    final selected = await showDatePicker(context: context,
      initialDate: expiry ? (_expiry ?? DateTime.now()) : _purchase,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() { if (expiry) { _expiry = selected; } else { _purchase = selected; } });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final old = widget.item;
      final item = FoodItem(
        id: old?.id ?? now.microsecondsSinceEpoch.toString(), name: _name.text.trim(),
        category: _category, quantity: double.parse(_quantity.text.trim()), unit: _unit,
        location: _location, purchaseDate: _purchase, expiryDate: _expiry, imagePath: _imagePath,
        status: old?.status ?? 'active', createdAt: old?.createdAt ?? now, updatedAt: now,
      );
      await FoodDatabase.instance.save(item);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.item == null ? 'เพิ่มอาหาร' : 'แก้ไขอาหาร')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: InkWell(onTap: _pickImage, borderRadius: BorderRadius.circular(16), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 128, height: 128,
        child: _imagePath == null ? const ColoredBox(color: Color(0xFFE1F0E6), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: seedGreen, size: 32), SizedBox(height: 8), Text('เพิ่มรูปภาพ')]))
          : Image.file(File(_imagePath!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image)),
      )))),
      const SizedBox(height: 20),
      TextFormField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'ชื่ออาหาร *', hintText: 'เช่น นมสด'),
        validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่ออาหาร' : null),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'หมวดหมู่'), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _category = v!)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TextFormField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'จำนวน *'),
          validator: (v) { final n = double.tryParse(v?.trim() ?? ''); return n == null || !n.isFinite || n <= 0 ? 'จำนวนต้องมากกว่า 0' : null; })),
        const SizedBox(width: 10),
        Expanded(child: DropdownButtonFormField<String>(initialValue: _unit, decoration: const InputDecoration(labelText: 'หน่วย'), items: units.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _unit = v!))),
      ]),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: _location, decoration: const InputDecoration(labelText: 'เก็บที่ไหน'), items: locations.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _location = v!)),
      const SizedBox(height: 12),
      Card(elevation: 0, color: Colors.white, child: Column(children: [
        ListTile(leading: const Icon(Icons.shopping_bag_outlined), title: const Text('วันที่ซื้อ'), subtitle: Text(formatDate(_purchase)), trailing: const Icon(Icons.calendar_month), onTap: () => _pickDate(expiry: false)),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.event_busy_outlined), title: const Text('วันหมดอายุ (ไม่บังคับ)'), subtitle: Text(_expiry == null ? 'ยังไม่ระบุ' : formatDate(_expiry!)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (_expiry != null) IconButton(tooltip: 'ล้างวันที่', onPressed: () => setState(() => _expiry = null), icon: const Icon(Icons.close)), const Icon(Icons.calendar_month)]),
          onTap: () => _pickDate(expiry: true)),
      ])),
      const SizedBox(height: 8),
      const Text('ระบบแสดงวันตามที่กรอก ไม่ประเมินความปลอดภัยของอาหารโดยอัตโนมัติ', style: TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกอาหาร'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      const SizedBox(height: 32),
    ])),
  );
}
