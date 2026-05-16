import 'package:flutter_test/flutter_test.dart';
import 'package:passenger_app/core/cache/passenger_bookings_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PassengerBookingsCache round-trips booking list JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = PassengerBookingsCache(prefs: prefs)..scopeKey = 'test_passenger';

    final rows = [
      {
        'id': 9,
        'status': 'COMPLETED',
        'pickup': {'address': 'Market'},
        'destination': {'address': 'USM'},
        'estimated_fare': '40.00',
      },
    ];

    await cache.writeList(rows);
    final cached = await cache.readList();
    expect(cached, isNotNull);
    expect(cached!.rows.length, 1);
    expect(cached.rows.first['id'], 9);

    await cache.clear();
    expect(await cache.readList(), isNull);
  });
}
