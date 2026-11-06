import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/food_item.dart';

/// Schedules one reminder per active food item. No internet or server required.
class ExpiryNotifications {
  ExpiryNotifications._();
  static final instance = ExpiryNotifications._();

  static const _daysKey = 'expiry_notification_days';
  static const _enabledKey = 'expiry_notifications_enabled';
  static const _idsKey = 'expiry_notification_ids';
  static const _channel = AndroidNotificationDetails(
    'food_expiry_v1', 'อาหารใกล้หมดอายุ',
    channelDescription: 'แจ้งเตือนอาหารก่อนวันหมดอายุ',
    importance: Importance.high,
    priority: Priority.high,
  );
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _initialized = true;
  }

  Future<int> reminderDays() async =>
      (await SharedPreferences.getInstance()).getInt(_daysKey) ?? 3;

  Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<void> setDays(int days) async {
    if (![1, 3, 7].contains(days)) throw ArgumentError.value(days);
    await (await SharedPreferences.getInstance()).setInt(_daysKey, days);
  }

  Future<bool> enableNotifications() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, granted);
    return granted;
  }

  Future<void> disableNotifications() async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, false);
    await _cancelTracked();
  }

  // Only cancel reminders owned by Fridge Keeper, not other notifications.
  Future<void> _cancelTracked() async {
    if (!Platform.isAndroid) return;
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    for (final id in prefs.getStringList(_idsKey) ?? <String>[]) {
      final value = int.tryParse(id);
      if (value != null) await _plugin.cancel(value);
    }
    await prefs.setStringList(_idsKey, []);
  }

  /// Rebuilds reminders after add/edit/use/delete or when opening the app.
  Future<int> reschedule(List<FoodItem> foods) async {
    if (!Platform.isAndroid) return 0;
    await initialize();
    await _cancelTracked();
    if (!await enabled()) return 0;
    final days = await reminderDays();
    final now = tz.TZDateTime.now(tz.local);
    final eligible = foods.where((f) => f.status == 'active' && f.expiryDate != null)
        .toList()..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    final ids = <String>[];
    // Leave headroom for the Samsung alarm limit; earliest expiry first.
    for (final item in eligible.take(400)) {
      final expiry = item.expiryDate!;
      final reminderDate = DateTime(expiry.year, expiry.month, expiry.day)
          .subtract(Duration(days: days));
      var when = tz.TZDateTime(tz.local, reminderDate.year, reminderDate.month,
          reminderDate.day, 9);
      final expiryEnd = tz.TZDateTime(tz.local, expiry.year, expiry.month, expiry.day, 23, 59);
      if (expiryEnd.isBefore(now)) continue;
      if (!when.isAfter(now)) {
        // Items already inside the reminder window get one upcoming reminder.
        when = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 9);
      }
      if (when.isAfter(expiryEnd)) continue;
      final id = _stableId(item.id);
      await _plugin.zonedSchedule(
        id, 'ใกล้หมดอายุ: ${item.name}',
        '${item.name} เหลือ ${item.quantity} ${item.unit} · หมดอายุใน ${_daysLeft(expiry, when)} วัน',
        when,
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.id,
      );
      ids.add('$id');
    }
    await (await SharedPreferences.getInstance()).setStringList(_idsKey, ids);
    return ids.length;
  }

  int _daysLeft(DateTime expiry, DateTime reminder) =>
      DateTime(expiry.year, expiry.month, expiry.day)
          .difference(DateTime(reminder.year, reminder.month, reminder.day)).inDays;

  // FNV-1a within signed positive 31-bit Android notification ID range.
  int _stableId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return (hash & 0x7fffffff) == 0 ? 1 : (hash & 0x7fffffff);
  }

  Future<void> showTest() async {
    if (!await enabled()) throw StateError('กรุณาเปิดสิทธิแจ้งเตือนก่อน');
    await initialize();
    await _plugin.show(
      2147483646, 'Fridge Keeper ทดสอบแจ้งเตือน',
      'แจ้งเตือนบนมือถือพร้อมใช้งานแล้ว 🥬',
      const NotificationDetails(android: _channel),
    );
  }
}
