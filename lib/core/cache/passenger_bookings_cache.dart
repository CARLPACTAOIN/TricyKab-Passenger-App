import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CachedPassengerBookings {
  const CachedPassengerBookings({required this.rows, required this.fetchedAt});

  final List<Map<String, dynamic>> rows;
  final DateTime fetchedAt;
}

class PassengerBookingsCache {
  PassengerBookingsCache({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsFuture async =>
      _prefs ?? await SharedPreferences.getInstance();

  String scopeKey = 'default';

  String get _listKey => 'passenger_bookings_v1_$scopeKey';
  String get _fetchedAtKey => 'passenger_bookings_fetched_at_v1_$scopeKey';

  Future<CachedPassengerBookings?> readList() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_listKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final rows = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
          .toList();
      final fetchedRaw = prefs.getString(_fetchedAtKey);
      return CachedPassengerBookings(
        rows: rows,
        fetchedAt: DateTime.tryParse(fetchedRaw ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeList(List<Map<String, dynamic>> rows) async {
    final prefs = await _prefsFuture;
    await prefs.setString(_listKey, jsonEncode(rows));
    await prefs.setString(_fetchedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> clear() async {
    final prefs = await _prefsFuture;
    final keys = prefs.getKeys().where(
      (k) => k == _listKey || k == _fetchedAtKey,
    );
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
