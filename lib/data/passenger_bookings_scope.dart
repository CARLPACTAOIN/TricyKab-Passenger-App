import 'package:flutter/material.dart';

import 'passenger_bookings_store.dart';

class PassengerBookingsScope extends InheritedNotifier<PassengerBookingsStore> {
  const PassengerBookingsScope({
    super.key,
    required PassengerBookingsStore store,
    required super.child,
  }) : super(notifier: store);

  static PassengerBookingsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PassengerBookingsScope>();
    assert(scope != null, 'PassengerBookingsScope not found');
    return scope!.notifier!;
  }
}
