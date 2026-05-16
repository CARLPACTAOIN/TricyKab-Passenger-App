import 'package:flutter/foundation.dart';

import '../core/cache/passenger_bookings_cache.dart';
import '../core/settings/app_settings.dart';
import 'passenger_repository.dart';

/// In-memory + disk display cache for passenger trip lists.
class PassengerBookingsStore extends ChangeNotifier {
  PassengerBookingsStore({
    required this.repo,
    required this.settings,
    PassengerBookingsCache? cache,
  }) : _cache = cache ?? PassengerBookingsCache();

  final PassengerRepository repo;
  final AppSettings settings;
  final PassengerBookingsCache _cache;

  List<Map<String, dynamic>>? bookings;
  DateTime? bookingsFetchedAt;
  bool bookingsRefreshing = false;
  String? bookingsLoadError;

  void _syncScope() {
    final token = settings.accessToken ?? '';
    _cache.scopeKey = token.isEmpty ? 'guest' : 'passenger_${token.hashCode}';
  }

  Future<void> loadBookings({required bool forceNetwork}) async {
    _syncScope();
    bookingsLoadError = null;

    if (!forceNetwork) {
      if (bookings != null) return;

      final cached = await _cache.readList();
      if (cached != null && cached.rows.isNotEmpty) {
        bookings = cached.rows;
        bookingsFetchedAt = cached.fetchedAt;
        notifyListeners();
        return;
      }
    }

    final hadData = bookings != null;
    bookingsRefreshing = hadData;
    if (!hadData) notifyListeners();

    try {
      final rows = await repo.myBookings();
      bookings = rows;
      bookingsFetchedAt = DateTime.now();
      await _cache.writeList(rows);
    } catch (e) {
      bookingsLoadError = e.toString();
      if (!hadData) bookings = null;
    } finally {
      bookingsRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _syncScope();
    bookings = null;
    bookingsFetchedAt = null;
    bookingsLoadError = null;
    bookingsRefreshing = false;
    await _cache.clear();
    notifyListeners();
  }
}
