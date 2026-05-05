import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A resolved place returned by forward or reverse geocoding.
class GeoPlace {
  const GeoPlace({
    required this.shortName,
    required this.displayName,
    required this.position,
  });

  /// Short, human-readable label (e.g. "Kabacan Public Market, Kabacan").
  final String shortName;

  /// Full OSM display name for subtitle display.
  final String displayName;

  /// Map coordinates.
  final LatLng position;

  /// Best available label for text-field display.
  String get label => shortName.isNotEmpty ? shortName : displayName;

  @override
  String toString() => 'GeoPlace($shortName, $position)';
}

/// Geocoding service for the passenger booking screen.
///
/// Forward search → Photon (komoot) — proximity-biased, no strict rate limit.
/// Reverse geocode → Nominatim — required by OSM ToS; 1-req/s limit respected
///   via on-tap-only calls (never on map drag).
class GeocodingService {
  GeocodingService._();

  static const String _ua =
      'TricyKabPassenger/1.0 (Kabacan dispatch pilot; educational)';
  static const Duration _timeout = Duration(seconds: 8);

  // Kabacan, Cotabato centre used when no proximity hint is supplied.
  static const double _defaultLat = 7.1117;
  static const double _defaultLon = 124.8419;

  // ── Forward search (Photon / komoot) ──────────────────────────────────────

  /// Returns up to 7 geocoded suggestions for [query], biased toward [near].
  ///
  /// Returns an empty list on network error or if [query] is too short.
  static Future<List<GeoPlace>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final biasLat = (near?.latitude ?? _defaultLat).toStringAsFixed(4);
    final biasLon = (near?.longitude ?? _defaultLon).toStringAsFixed(4);

    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'lat': biasLat,
      'lon': biasLon,
      'limit': '7',
      'lang': 'en',
    });

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final features = body['features'] as List? ?? const [];
      return features
          .map(_photonFeatureToPlace)
          .whereType<GeoPlace>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  // ── Reverse geocode (Nominatim) ───────────────────────────────────────────

  /// Returns the nearest address for [pos], or null on failure.
  ///
  /// Only call this on explicit user gestures (map tap, GPS button) — never
  /// on map drag — to stay within Nominatim's 1-req/s rate limit.
  static Future<GeoPlace?> reverseGeocode(LatLng pos) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': pos.latitude.toStringAsFixed(7),
      'lon': pos.longitude.toStringAsFixed(7),
      'format': 'json',
      'zoom': '18',
      'addressdetails': '1',
    });

    try {
      final res = await http.get(uri, headers: {
        'User-Agent': _ua,
        'Accept-Language': 'en',
      }).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data.containsKey('error')) return null;
      return _nominatimToPlace(data, pos);
    } catch (_) {
      return null;
    }
  }

  // ── Parsers ───────────────────────────────────────────────────────────────

  static GeoPlace? _photonFeatureToPlace(dynamic feature) {
    try {
      final coords = (feature['geometry']['coordinates'] as List);
      if (coords.length < 2) return null;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final p = feature['properties'] as Map<String, dynamic>;

      final nameParts = <String>[];
      for (final key in [
        'name',
        'street',
        'city',
        'town',
        'village',
        'municipality',
      ]) {
        final v = p[key]?.toString().trim();
        if (v != null && v.isNotEmpty && !nameParts.contains(v)) {
          nameParts.add(v);
          if (nameParts.length >= 3) break;
        }
      }

      final displayParts = [
        ...nameParts,
        p['county']?.toString(),
        p['state']?.toString(),
        p['country']?.toString(),
      ].whereType<String>().where((s) => s.isNotEmpty).toList();

      return GeoPlace(
        shortName: nameParts.join(', '),
        displayName: displayParts.join(', '),
        position: LatLng(lat, lon),
      );
    } catch (_) {
      return null;
    }
  }

  static GeoPlace _nominatimToPlace(Map<String, dynamic> data, LatLng pos) {
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    final parts = <String>[];
    for (final key in [
      'amenity',
      'shop',
      'building',
      'tourism',
      'leisure',
      'road',
      'suburb',
      'quarter',
      'neighbourhood',
      'city_district',
      'city',
      'town',
      'village',
    ]) {
      final v = addr[key]?.toString().trim();
      if (v != null && v.isNotEmpty) {
        parts.add(v);
        if (parts.length >= 3) break;
      }
    }
    return GeoPlace(
      shortName: parts.join(', '),
      displayName: data['display_name']?.toString() ?? parts.join(', '),
      position: pos,
    );
  }
}
