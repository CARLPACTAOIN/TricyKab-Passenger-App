import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches a real road-following route from the OSRM demo server
/// (OpenStreetMap routing — no API key required for pilot/demo use).
///
/// Returns an ordered list of [LatLng] points that form the road route.
/// Falls back to `null` on any network / parse error so callers can
/// degrade gracefully to a straight-line polyline.
class OsrmService {
  OsrmService._();

  static const String _base = 'https://routing.openstreetmap.de/routed-car';

  /// Fetch a driving route between [from] and [to].
  ///
  /// Uses `overview=full` so the entire route geometry is returned,
  /// and `geometries=geojson` for easy [LatLng] parsing.
  static Future<List<LatLng>?> fetchRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        '$_base/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TricyKab/1.0.0 (Demo/Pilot Application)',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final geometry =
          (routes.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null) return null;

      return coords
          .whereType<List<dynamic>>()
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
