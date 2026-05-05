import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Lightweight client-side fare hint used purely to fill the estimate card
/// before the booking is created. The authoritative fare comes from
/// `PassengerBookingService::create()` (PRD §9.2) once the booking is posted.
class FareEstimate {
  const FareEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.amountPhp,
    required this.suggestedSpecialMin,
    required this.suggestedSpecialMax,
  });

  final double distanceKm;
  final int durationMinutes;
  final double amountPhp;
  final double suggestedSpecialMin;
  final double suggestedSpecialMax;

  String get distanceLabel => '~${distanceKm.toStringAsFixed(1)} km · $durationMinutes min';
}

class FareEstimator {
  FareEstimator._();

  static const double _baseShared = 35; // PRD pilot baseline (Kabacan TODA).
  static const double _perKmShared = 8;
  static const double _baseSpecial = 60;
  static const double _perKmSpecial = 18;

  static FareEstimate estimate({
    required LatLng pickup,
    required LatLng destination,
    required String rideType,
  }) {
    final km = _haversineKm(pickup, destination);
    final minutes = math.max(1, (km / 0.25).round()); // ~15 km/h average
    if (rideType.toUpperCase() == 'SPECIAL') {
      final amount = _baseSpecial + (km * _perKmSpecial);
      return FareEstimate(
        distanceKm: km,
        durationMinutes: minutes,
        amountPhp: _round(amount),
        suggestedSpecialMin: _round(amount * 0.85),
        suggestedSpecialMax: _round(amount * 1.25),
      );
    }
    final amount = _baseShared + (km * _perKmShared);
    return FareEstimate(
      distanceKm: km,
      durationMinutes: minutes,
      amountPhp: _round(amount),
      suggestedSpecialMin: 0,
      suggestedSpecialMax: 0,
    );
  }

  static double _round(double value) => (value / 5).roundToDouble() * 5;

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg(b.latitude - a.latitude);
    final dLon = _deg(b.longitude - a.longitude);
    final lat1 = _deg(a.latitude);
    final lat2 = _deg(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _deg(double v) => v * math.pi / 180;
}
