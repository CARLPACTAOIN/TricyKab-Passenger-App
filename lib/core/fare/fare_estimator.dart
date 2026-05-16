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

  static const double _baseShared = 15;
  static const double _perKmShared = 2.50;
  static const double _minDistance = 2.0;
  static const double _baseSpecial = 50;
  static const double _perKmSpecial = 5;
  static const double _multiplierSpecial = 1.5;

  static FareEstimate estimate({
    required LatLng pickup,
    required LatLng destination,
    required String rideType,
  }) {
    final km = _haversineKm(pickup, destination);
    final minutes = math.max(1, (km / 0.25).round()); // ~15 km/h average
    
    final chargeableKm = math.max(0.0, km - _minDistance);

    if (rideType.toUpperCase() == 'SPECIAL') {
      final amount = _baseSpecial + (chargeableKm * _perKmSpecial * _multiplierSpecial);
      return FareEstimate(
        distanceKm: km,
        durationMinutes: minutes,
        amountPhp: _round(amount),
        suggestedSpecialMin: _round(amount * 0.85),
        suggestedSpecialMax: _round(amount * 1.25),
      );
    }
    final amount = _baseShared + (chargeableKm * _perKmShared);
    return FareEstimate(
      distanceKm: km,
      durationMinutes: minutes,
      amountPhp: _round(amount),
      suggestedSpecialMin: 0,
      suggestedSpecialMax: 0,
    );
  }

  static double _round(double value) => (value * 100).round() / 100.0;

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
