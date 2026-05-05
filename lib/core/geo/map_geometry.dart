import 'package:latlong2/latlong.dart';

/// True when [a] and [b] are far enough apart to draw a non-degenerate route.
///
/// When both pins share the same (or nearly the same) coordinates, the
/// polyline collapses to zero pixel length after projection/simplification;
/// flutter_map's dashed [StrokePattern] / pixel hikers can then misbehave.
bool distinctMapEndpoints(LatLng a, LatLng b) {
  const e = 1e-6;
  return (a.latitude - b.latitude).abs() > e ||
      (a.longitude - b.longitude).abs() > e;
}
