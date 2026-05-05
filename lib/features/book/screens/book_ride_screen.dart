import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/fare/fare_estimator.dart';
import '../../../core/geo/geocoding_service.dart';
import '../../../core/geo/map_geometry.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/passenger_repository.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/fare_estimate_card.dart';
import '../../../shared/widgets/passenger_bottom_nav.dart';
import '../widgets/address_search_sheet.dart';

/// Booking screen — PRD §11 / mockup 02.
///
/// Key interactions:
///  • Tapping the pickup or destination field opens an [AddressSearchSheet]
///    with real-time Photon/Nominatim suggestions.
///  • GPS button auto-fills the pickup field and reverse-geocodes.
///  • Tapping the map drops a teal (pickup) or red (destination) pin and
///    reverse-geocodes the tapped coordinate into the matching address field.
///  • A Full-Screen Map toggle expands the map and overlays lat/lng precision
///    coordinates of the active marker.
class BookRideScreen extends StatefulWidget {
  const BookRideScreen(
      {super.key, required this.repo, required this.settings});

  final PassengerRepository repo;
  final AppSettings settings;

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  static const LatLng _kabacanCenter = LatLng(7.1117, 124.8419);

  final MapController _mapController = MapController();
  final _specialFareCtrl = TextEditingController();

  // ── Pins ──────────────────────────────────────────────────────────────────
  LatLng? _pickup;
  LatLng? _destination;

  /// Which pin the next map-tap will set; also controls the active highlight
  /// on the address panel.
  bool _settingPickup = true;

  // ── Address text ──────────────────────────────────────────────────────────
  String _pickupAddress = '';
  String _destAddress = '';

  // ── Loading states ────────────────────────────────────────────────────────
  bool _pickupGeoLoading = false;
  bool _destGeoLoading = false;
  bool _gpsLoading = false;

  /// Stale-result guards: each reverse-geocode start bumps the counter;
  /// the result is only applied if the counter hasn't moved on.
  int _pickupRevId = 0;
  int _destRevId = 0;

  // ── Map state ─────────────────────────────────────────────────────────────
  LatLng _mapCenter = _kabacanCenter;
  double _mapZoom = 14.0;
  bool _fullScreen = false;

  // ── Booking ───────────────────────────────────────────────────────────────
  String _rideType = 'SHARED';
  bool _busy = false;
  String? _err;
  FareEstimate? _estimate;

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _specialFareCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _coordFallback(LatLng pos) =>
      '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

  String _resolveAddr(LatLng? pos, String addr, bool loading) {
    if (pos == null) return '';
    if (addr.isEmpty || loading) return _coordFallback(pos);
    return addr;
  }

  void _recomputeEstimate() {
    if (_pickup == null || _destination == null) {
      setState(() => _estimate = null);
      return;
    }
    setState(() {
      _estimate = FareEstimator.estimate(
        pickup: _pickup!,
        destination: _destination!,
        rideType: _rideType,
      );
    });
  }

  // ── Map position tracking ─────────────────────────────────────────────────

  void _onPositionChanged(MapCamera cam, bool hasGesture) {
    _mapCenter = cam.center;
    _mapZoom = cam.zoom;
  }

  // ── Map tap ───────────────────────────────────────────────────────────────

  void _onMapTap(TapPosition _, LatLng latlng) {
    final isPickup = _settingPickup;
    setState(() {
      if (isPickup) {
        _pickup = latlng;
        _pickupAddress = 'Getting address…';
        _pickupGeoLoading = true;
        // Auto-advance to destination after pickup is set (normal mode only).
        if (!_fullScreen) _settingPickup = false;
      } else {
        _destination = latlng;
        _destAddress = 'Getting address…';
        _destGeoLoading = true;
      }
    });
    _recomputeEstimate();
    _reverseAt(latlng, isPickup: isPickup);
  }

  Future<void> _reverseAt(LatLng pos, {required bool isPickup}) async {
    if (isPickup) {
      _pickupRevId++;
      final myId = _pickupRevId;
      final place = await GeocodingService.reverseGeocode(pos);
      if (!mounted || _pickupRevId != myId) return;
      setState(() {
        _pickupAddress = place?.label ?? _coordFallback(pos);
        _pickupGeoLoading = false;
      });
    } else {
      _destRevId++;
      final myId = _destRevId;
      final place = await GeocodingService.reverseGeocode(pos);
      if (!mounted || _destRevId != myId) return;
      setState(() {
        _destAddress = place?.label ?? _coordFallback(pos);
        _destGeoLoading = false;
      });
    }
    _recomputeEstimate();
  }

  // ── GPS pickup ────────────────────────────────────────────────────────────

  Future<void> _useGps() async {
    setState(() => _gpsLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission required for GPS pickup.')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _pickup = latlng;
        _pickupAddress = 'Getting address…';
        _pickupGeoLoading = true;
        _settingPickup = false;
      });
      try {
        _mapController.move(latlng, 16);
      } catch (_) {}
      _recomputeEstimate();
      _reverseAt(latlng, isPickup: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('GPS error: $e')));
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Address search ────────────────────────────────────────────────────────

  Future<void> _openSearch({required bool forPickup}) async {
    setState(() => _settingPickup = forPickup);
    final place = await AddressSearchSheet.show(
      context,
      label: forPickup ? 'Pickup' : 'Destination',
      near: (forPickup ? _destination : _pickup) ?? _kabacanCenter,
      onUseGps: forPickup ? _useGps : null,
    );
    if (place == null || !mounted) return; // cancelled or GPS chosen
    setState(() {
      if (forPickup) {
        _pickup = place.position;
        _pickupAddress = place.label;
        _settingPickup = false;
      } else {
        _destination = place.position;
        _destAddress = place.label;
      }
    });
    try {
      _mapController.move(place.position, 15);
    } catch (_) {}
    _recomputeEstimate();
  }

  // ── Swap pickup ↔ destination ─────────────────────────────────────────────

  void _swap() {
    setState(() {
      final tmpPos = _pickup;
      final tmpAddr = _pickupAddress;
      _pickup = _destination;
      _pickupAddress = _destAddress;
      _destination = tmpPos;
      _destAddress = tmpAddr;
    });
    _recomputeEstimate();
    final focus = _pickup ?? _destination;
    if (focus != null) {
      try {
        _mapController.move(focus, _mapZoom);
      } catch (_) {}
    }
  }

  // ── Book ──────────────────────────────────────────────────────────────────

  Future<void> _book() async {
    if (_pickup == null || _destination == null) {
      setState(() =>
          _err = 'Set both a pickup and a destination before booking.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final key =
          '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';
      final data = await widget.repo.createBooking(
        rideType: _rideType,
        pickup: {
          'latitude': _pickup!.latitude,
          'longitude': _pickup!.longitude,
          'address': _resolveAddr(_pickup, _pickupAddress, _pickupGeoLoading),
        },
        destination: {
          'latitude': _destination!.latitude,
          'longitude': _destination!.longitude,
          'address': _resolveAddr(_destination, _destAddress, _destGeoLoading),
        },
        idempotencyKey: key,
      );
      final booking = data['booking'];
      if (booking is Map<String, dynamic>) {
        final id = booking['id'];
        if (id is int && mounted) {
          Navigator.of(context).pushNamed('/active', arguments: id);
          return;
        }
      }
      setState(() => _err = 'Booking created but no id returned.');
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_fullScreen) return _buildFullScreenScaffold();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppBrand(),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            color: AppColors.textMuted,
            onPressed: () => Navigator.of(context).pushNamed('/trips'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            color: AppColors.textMuted,
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildNormalBody(),
      ),
      bottomNavigationBar:
          const PassengerBottomNav(current: PassengerNavTab.book),
    );
  }

  Widget _buildNormalBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _MapArea(
          mapController: _mapController,
          initialCenter: _mapCenter,
          initialZoom: _mapZoom,
          pickup: _pickup,
          destination: _destination,
          settingPickup: _settingPickup,
          onTap: _onMapTap,
          onPositionChanged: _onPositionChanged,
          onFullScreen: () => setState(() => _fullScreen = true),
        ),
        const SizedBox(height: 16),
        _AddressPanel(
          pickupAddress: _pickupAddress,
          destAddress: _destAddress,
          pickupGeoLoading: _pickupGeoLoading,
          destGeoLoading: _destGeoLoading,
          gpsLoading: _gpsLoading,
          settingPickup: _settingPickup,
          onPickupTap: () => _openSearch(forPickup: true),
          onDestTap: () => _openSearch(forPickup: false),
          onGps: _useGps,
          onSwap: _swap,
        ),
        const SizedBox(height: 12),
        _RideTypeToggle(
          rideType: _rideType,
          onChanged: (v) {
            setState(() => _rideType = v);
            _recomputeEstimate();
          },
        ),
        const SizedBox(height: 12),
        FareEstimateCard(
          amountLabel: _estimate == null
              ? '₱—'
              : '₱${_estimate!.amountPhp.toStringAsFixed(2)}',
          rideType: _rideType,
          metaLabel: _estimate == null
              ? 'Set both pins to see fare'
              : _estimate!.distanceLabel,
          children: _rideType == 'SPECIAL'
              ? [
                  const Text(
                    'YOUR FARE PROPOSAL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _specialFareCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.payments,
                          color: AppColors.primary, size: 20),
                      hintText: _estimate == null
                          ? 'Suggest your fare in ₱'
                          : '₱${_estimate!.suggestedSpecialMin.toInt()} – ₱${_estimate!.suggestedSpecialMax.toInt()} suggested',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Note: special-fare proposal API is deferred per PRD §9.2; the booking is recorded as SPECIAL with the calculated estimate for the pilot.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ]
              : const <Widget>[],
        ),
        if (_err != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _err!),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _book,
          style:
              FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: const Icon(Icons.local_taxi, size: 20),
          label: Text(_busy ? 'Sending request…' : 'Book Now'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/trips'),
          icon: const Icon(Icons.history, size: 16),
          label: const Text('See my recent trips'),
        ),
      ],
    );
  }

  // ── Full-screen map scaffold ───────────────────────────────────────────────

  Widget _buildFullScreenScaffold() {
    final top = MediaQuery.of(context).padding.top;
    final activePos = _settingPickup ? _pickup : _destination;
    final activeAddr = _settingPickup ? _pickupAddress : _destAddress;
    final activeLoading =
        _settingPickup ? _pickupGeoLoading : _destGeoLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _mapZoom,
                onTap: _onMapTap,
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tricykab.passenger',
                ),
                if (_pickup != null &&
                    _destination != null &&
                    distinctMapEndpoints(_pickup!, _destination!))
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [_pickup!, _destination!],
                      strokeWidth: 3,
                      color: AppColors.primary,
                      pattern:
                          StrokePattern.dashed(segments: const [8.0, 6.0]),
                    ),
                  ]),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),

          // ── Exit button (top-left) ───────────────────────────────────────
          Positioned(
            top: top + 8,
            left: 16,
            child: _MapFab(
              icon: Icons.fullscreen_exit,
              onTap: () => setState(() => _fullScreen = false),
              tooltip: 'Exit full-screen',
            ),
          ),

          // ── Lat/Lng overlay (top-right) ──────────────────────────────────
          if (activePos != null)
            Positioned(
              top: top + 8,
              right: 16,
              child: _LatLngCard(pos: activePos, isPickup: _settingPickup),
            ),

          // ── Bottom control panel ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _FullScreenBottomPanel(
                  settingPickup: _settingPickup,
                  activeAddress: activeAddr,
                  activeLoading: activeLoading,
                  onPickupMode: () => setState(() => _settingPickup = true),
                  onDestMode: () => setState(() => _settingPickup = false),
                  onDone: () => setState(() => _fullScreen = false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() => [
        if (_pickup != null)
          Marker(
            point: _pickup!,
            width: 36,
            height: 36,
            child: const _MapPin(
                color: AppColors.success, icon: Icons.my_location),
          ),
        if (_destination != null)
          Marker(
            point: _destination!,
            width: 36,
            height: 36,
            child: const _MapPin(color: AppColors.danger, icon: Icons.place),
          ),
      ];
}

// ═══════════════════════════════════════════════════════════════════════════
// Normal-mode map area
// ═══════════════════════════════════════════════════════════════════════════

class _MapArea extends StatelessWidget {
  const _MapArea({
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.pickup,
    required this.destination,
    required this.settingPickup,
    required this.onTap,
    required this.onPositionChanged,
    required this.onFullScreen,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final LatLng? pickup;
  final LatLng? destination;
  final bool settingPickup;
  final void Function(TapPosition, LatLng) onTap;
  final void Function(MapCamera, bool) onPositionChanged;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                onTap: onTap,
                onPositionChanged: onPositionChanged,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tricykab.passenger',
                ),
                if (pickup != null &&
                    destination != null &&
                    distinctMapEndpoints(pickup!, destination!))
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [pickup!, destination!],
                      strokeWidth: 3,
                      color: AppColors.primary,
                      pattern:
                          StrokePattern.dashed(segments: const [8.0, 6.0]),
                    ),
                  ]),
                MarkerLayer(markers: [
                  if (pickup != null)
                    Marker(
                      point: pickup!,
                      width: 36,
                      height: 36,
                      child: const _MapPin(
                          color: AppColors.success, icon: Icons.my_location),
                    ),
                  if (destination != null)
                    Marker(
                      point: destination!,
                      width: 36,
                      height: 36,
                      child: const _MapPin(
                          color: AppColors.danger, icon: Icons.place),
                    ),
                ]),
              ],
            ),
          ),
          // Hint chip (top-left corner)
          Positioned(
            top: 12,
            left: 12,
            child: _MapHintChip(
              settingPickup: settingPickup,
              pickup: pickup,
              destination: destination,
            ),
          ),
          // Full-screen toggle (bottom-right corner)
          Positioned(
            bottom: 12,
            right: 12,
            child: _MapFab(
              icon: Icons.fullscreen,
              onTap: onFullScreen,
              tooltip: 'Full-screen map',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Address panel (pickup + destination with swap)
// ═══════════════════════════════════════════════════════════════════════════

class _AddressPanel extends StatelessWidget {
  const _AddressPanel({
    required this.pickupAddress,
    required this.destAddress,
    required this.pickupGeoLoading,
    required this.destGeoLoading,
    required this.gpsLoading,
    required this.settingPickup,
    required this.onPickupTap,
    required this.onDestTap,
    required this.onGps,
    required this.onSwap,
  });

  final String pickupAddress;
  final String destAddress;
  final bool pickupGeoLoading;
  final bool destGeoLoading;
  final bool gpsLoading;
  final bool settingPickup;
  final VoidCallback onPickupTap;
  final VoidCallback onDestTap;
  final VoidCallback onGps;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          _AddressField(
            isPickup: true,
            address: pickupAddress,
            geoLoading: pickupGeoLoading,
            gpsLoading: gpsLoading,
            isActive: settingPickup,
            onTap: onPickupTap,
            onGps: onGps,
          ),
          _ConnectorRow(onSwap: onSwap),
          _AddressField(
            isPickup: false,
            address: destAddress,
            geoLoading: destGeoLoading,
            gpsLoading: false,
            isActive: !settingPickup,
            onTap: onDestTap,
          ),
        ],
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.isPickup,
    required this.address,
    required this.geoLoading,
    required this.gpsLoading,
    required this.isActive,
    required this.onTap,
    this.onGps,
  });

  final bool isPickup;
  final String address;
  final bool geoLoading;
  final bool gpsLoading;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onGps;

  @override
  Widget build(BuildContext context) {
    final pinColor = isPickup ? AppColors.success : AppColors.danger;
    final icon = isPickup ? Icons.my_location : Icons.place;
    final label = isPickup ? 'PICKUP ADDRESS' : 'DESTINATION';
    final placeholder = isPickup ? 'Set pickup location' : 'Set destination';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            EdgeInsets.fromLTRB(12, 12, onGps != null ? 4 : 12, 12),
        decoration: BoxDecoration(
          color: isActive
              ? pinColor.withValues(alpha: 0.04)
              : AppColors.subtleBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? pinColor : AppColors.border,
            width: isActive ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: pinColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? pinColor : AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (geoLoading)
                    Row(
                      children: [
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: pinColor),
                        ),
                        const SizedBox(width: 8),
                        const Text('Getting address…',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ],
                    )
                  else
                    Text(
                      address.isEmpty ? placeholder : address,
                      style: TextStyle(
                        color: address.isEmpty
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (onGps != null) ...[
              const SizedBox(width: 4),
              gpsLoading
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primary),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.gps_fixed, size: 20),
                      color: AppColors.primary,
                      tooltip: 'Use my location',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: onGps,
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectorRow extends StatelessWidget {
  const _ConnectorRow({required this.onSwap});
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 19),
          CustomPaint(
            painter: _DashedLinePainter(),
            size: const Size(2, 32),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSwap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.subtleBackground,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.swap_vert,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2;
    const dashH = 5.0;
    const gapH = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gapH;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// Map hint chip shown in the normal-mode map panel
// ═══════════════════════════════════════════════════════════════════════════

class _MapHintChip extends StatelessWidget {
  const _MapHintChip({
    required this.settingPickup,
    required this.pickup,
    required this.destination,
  });
  final bool settingPickup;
  final LatLng? pickup;
  final LatLng? destination;

  @override
  Widget build(BuildContext context) {
    final color = settingPickup ? AppColors.success : AppColors.danger;
    final icon = settingPickup ? Icons.my_location : Icons.place;
    final label = settingPickup
        ? (pickup == null ? 'Tap map to set pickup' : 'Tap to adjust pickup')
        : (destination == null
            ? 'Tap map to set destination'
            : 'Tap to adjust destination');

    return Material(
      color: Colors.white.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Full-screen overlay widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Precise lat/lng overlay card shown in full-screen map mode.
class _LatLngCard extends StatelessWidget {
  const _LatLngCard({required this.pos, required this.isPickup});
  final LatLng pos;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final color = isPickup ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isPickup ? 'PICKUP' : 'DESTINATION',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Lat   ${pos.latitude.toStringAsFixed(5)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Lng  ${pos.longitude.toStringAsFixed(5)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom control panel in full-screen mode.
class _FullScreenBottomPanel extends StatelessWidget {
  const _FullScreenBottomPanel({
    required this.settingPickup,
    required this.activeAddress,
    required this.activeLoading,
    required this.onPickupMode,
    required this.onDestMode,
    required this.onDone,
  });

  final bool settingPickup;
  final String activeAddress;
  final bool activeLoading;
  final VoidCallback onPickupMode;
  final VoidCallback onDestMode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final color = settingPickup ? AppColors.success : AppColors.danger;
    final pinIcon = settingPickup ? Icons.my_location : Icons.place;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.14), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode chips
          Row(
            children: [
              _ModeChip(
                  isPickup: true,
                  active: settingPickup,
                  onTap: onPickupMode),
              const SizedBox(width: 8),
              _ModeChip(
                  isPickup: false,
                  active: !settingPickup,
                  onTap: onDestMode),
            ],
          ),
          const SizedBox(height: 12),
          // Active address
          Row(
            children: [
              Icon(pinIcon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: activeLoading
                    ? Row(children: [
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color),
                        ),
                        const SizedBox(width: 8),
                        const Text('Getting address…',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ])
                    : Text(
                        activeAddress.isEmpty
                            ? (settingPickup
                                ? 'Tap map to set pickup'
                                : 'Tap map to set destination')
                            : activeAddress,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Done — back to booking'),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(
      {required this.isPickup, required this.active, required this.onTap});
  final bool isPickup;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isPickup ? AppColors.success : AppColors.danger;
    final bg = isPickup ? AppColors.successLight : AppColors.dangerLight;
    final icon = isPickup ? Icons.my_location : Icons.place;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? bg : AppColors.subtleBackground,
          borderRadius: BorderRadius.circular(100),
          border: active ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12, color: active ? color : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              isPickup ? 'Pickup' : 'Destination',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared small widgets used throughout this file
// ═══════════════════════════════════════════════════════════════════════════

class _MapFab extends StatelessWidget {
  const _MapFab({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _RideTypeToggle extends StatelessWidget {
  const _RideTypeToggle({required this.rideType, required this.onChanged});
  final String rideType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RIDE TYPE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.subtleBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _segment('SHARED', 'Shared')),
                Expanded(child: _segment('SPECIAL', 'Special')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(String value, String label) {
    final active = rideType == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
