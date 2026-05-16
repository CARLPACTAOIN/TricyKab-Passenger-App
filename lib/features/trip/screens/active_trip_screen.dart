import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/passenger_repository.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/driver_card.dart';
import '../../../shared/widgets/eta_banner.dart';
import '../../../shared/widgets/info_row.dart';
import '../../../shared/widgets/pulse_dot.dart';
import '../../../shared/widgets/route_timeline_card.dart';
import '../../../shared/widgets/sos_floating_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/geo/map_geometry.dart';
import '../../../core/geo/osrm_service.dart';

/// Active trip screen — covers all three mockup states:
///   - 03 Searching driver  (booking.status == SEARCHING_DRIVER)
///   - 04 Driver assigned   (booking.status == DRIVER_ASSIGNED)
///   - 05 Trip in progress  (booking.status == TRIP_IN_PROGRESS)
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key, required this.repo, required this.bookingId});

  final PassengerRepository repo;
  final int bookingId;

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  Timer? _pollTimer;
  DateTime? _statusEnteredAt;
  String? _lastStatus;
  Map<String, dynamic>? _data;
  String? _err;
  bool _cancelling = false;
  bool _navigatedToReceipt = false;
  DateTime? _completedSeenAt;
  bool _ackPickupBusy = false;
  bool _ackDropoffBusy = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _refreshOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshOnce());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOnce() async {
    try {
      final data = await widget.repo.tripTracking(widget.bookingId);
      if (!mounted) return;
      final booking = data['booking'];
      final status = booking is Map ? booking['status']?.toString() : null;
      if (status != null && status != _lastStatus) {
        _statusEnteredAt = DateTime.now();
        _lastStatus = status;
      }
      setState(() {
        _data = data;
        _err = null;
      });
      if (status != 'COMPLETED') {
        _completedSeenAt = null;
      }
      final receiptReady = data['receipt_available'] == true;
      if (status == 'COMPLETED' && !_navigatedToReceipt) {
        _completedSeenAt ??= DateTime.now();
        final waited = DateTime.now().difference(_completedSeenAt!);
        final bool go =
            receiptReady || waited > const Duration(seconds: 45);
        if (go) {
          _navigatedToReceipt = true;
          _pollTimer?.cancel();
          Future.microtask(() {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/receipt', arguments: widget.bookingId);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _passengerAckPickup() async {
    setState(() => _ackPickupBusy = true);
    try {
      await widget.repo.passengerAck(widget.bookingId, 'pickup');
      await _refreshOnce();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You’re marked at the pickup — your driver can start when everyone’s ready.')),
      );
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _ackPickupBusy = false);
    }
  }

  Future<void> _passengerAckDropoff() async {
    setState(() => _ackDropoffBusy = true);
    try {
      await widget.repo.passengerAck(widget.bookingId, 'dropoff');
      await _refreshOnce();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination arrival noted for your driver.')),
      );
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _ackDropoffBusy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await widget.repo.cancelBooking(widget.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/book', (_) => false);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _sos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send SOS alert?'),
        content: const Text(
          'Admins will be notified with your current location. Use only in genuine emergencies.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      double lat = 7.1117;
      double lng = 124.8419;
      try {
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
        if (p != LocationPermission.denied && p != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition();
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}
      await widget.repo.sos(
        bookingId: widget.bookingId,
        latitude: lat,
        longitude: lng,
        notes: 'Sent from passenger app',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('SOS sent. Admin notified.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SOS failed: $e')),
        );
      }
    }
  }

  void _showDriverPhone() {
    final driver = (_data?['driver'] as Map?)?.cast<String, dynamic>();
    final phone = driver?['phone']?.toString();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone not available.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.phone, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Call your driver',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Text(phone,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'SEARCHING_DRIVER':
        return 'SEARCHING';
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ON_THE_WAY':
      case 'DRIVER_ARRIVED':
        return 'ASSIGNED';
      case 'TRIP_IN_PROGRESS':
        return 'LIVE';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null && _err == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final booking = (data?['booking'] as Map?)?.cast<String, dynamic>();
    final trip = (data?['trip'] as Map?)?.cast<String, dynamic>();
    final driver = (data?['driver'] as Map?)?.cast<String, dynamic>();
    final status = booking?['status']?.toString() ?? 'SEARCHING_DRIVER';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppBrand(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StatusBadge(
              label: _statusLabel(status),
              background: _statusBg(status),
              foreground: _statusFg(status),
            )),
          ),
        ],
      ),
      body: Stack(
        children: [
          _bodyForStatus(status, booking, trip, driver),
          if (status == 'TRIP_IN_PROGRESS')
            Positioned(right: 16, bottom: 16, child: SosFloatingButton(onPressed: _sos)),
        ],
      ),
    );
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'SEARCHING_DRIVER':
        return AppColors.badgeSearchingBg;
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ON_THE_WAY':
      case 'DRIVER_ARRIVED':
        return AppColors.badgeAssignedBg;
      case 'TRIP_IN_PROGRESS':
        return AppColors.badgeInProgressBg;
      case 'COMPLETED':
        return AppColors.badgeCompletedBg;
    }
    return AppColors.subtleBackground;
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'SEARCHING_DRIVER':
        return AppColors.badgeSearchingText;
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ON_THE_WAY':
      case 'DRIVER_ARRIVED':
        return AppColors.badgeAssignedText;
      case 'TRIP_IN_PROGRESS':
        return AppColors.badgeInProgressText;
      case 'COMPLETED':
        return AppColors.badgeCompletedText;
    }
    return AppColors.textSecondary;
  }

  Widget _bodyForStatus(
    String status,
    Map<String, dynamic>? booking,
    Map<String, dynamic>? trip,
    Map<String, dynamic>? driver,
  ) {
    switch (status) {
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ON_THE_WAY':
      case 'DRIVER_ARRIVED':
        return _assignedView(status, booking, driver);
      case 'TRIP_IN_PROGRESS':
        return _inProgressView(booking, trip, driver);
      case 'COMPLETED':
      case 'SEARCHING_DRIVER':
      default:
        return _searchingView(booking);
    }
  }

  // ---- Searching driver view (mockup 03) ----

  Widget _searchingView(Map<String, dynamic>? booking) {
    final ref = booking?['booking_reference']?.toString() ?? '—';
    final pickup = (booking?['pickup'] as Map?)?['address']?.toString() ?? 'Pickup';
    final dest = (booking?['destination'] as Map?)?['address']?.toString() ?? 'Destination';
    final fare = booking?['fare_amount']?.toString();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Ref: $ref',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(child: PulseDot()),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Finding your driver...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "We're matching you with the nearest available driver in your area.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            RouteTimelineCard(pickupLabel: pickup, destinationLabel: dest),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  StatusBadge.forRideType(booking?['ride_type']?.toString() ?? 'SHARED'),
                  const Spacer(),
                  Text(
                    fare == null ? '—' : '₱$fare',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _err!),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cancelling ? null : _cancel,
              icon: const Icon(Icons.close),
              label: Text(_cancelling ? 'Cancelling...' : 'Cancel Booking'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Driver assigned view (mockup 04) ----

  Widget _assignedView(
    String status,
    Map<String, dynamic>? booking,
    Map<String, dynamic>? driver,
  ) {
    final pickup = (booking?['pickup'] as Map?)?.cast<String, dynamic>();
    final dest = (booking?['destination'] as Map?)?.cast<String, dynamic>();
    final fare = booking?['fare_amount']?.toString();
    final passengerAckPickupAt = booking?['passenger_ack_pickup_at'];
    final canAckPickup = (status == 'DRIVER_ASSIGNED' || status == 'DRIVER_ON_THE_WAY') &&
        passengerAckPickupAt == null;
    final driverPos = _maybeLatLng(
      (driver?['last_location'] as Map?)?['latitude'],
      (driver?['last_location'] as Map?)?['longitude'],
    );
    final pickupPos = _maybeLatLng(pickup?['latitude'], pickup?['longitude']);
    final etaMinutes = _etaMinutesFromBooking();

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _PassengerMiniMap(pickup: pickupPos, driver: driverPos, height: 200),
          const SizedBox(height: 16),
          EtaBanner(
            label: status == 'DRIVER_ARRIVED' ? 'Status' : 'Driver arriving in',
            value: status == 'DRIVER_ARRIVED'
                ? 'At pickup'
                : '$etaMinutes min',
          ),
          const SizedBox(height: 16),
          if (driver != null)
            DriverCard(
              name: driver['full_name']?.toString() ?? 'Your driver',
              subtitle: _driverSubtitle(driver),
              plateNumber: driver['plate_number']?.toString(),
              licenseVerified: true,
              onCallPressed: _showDriverPhone,
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                InfoRow(label: 'Pickup', value: pickup?['address']?.toString() ?? '—'),
                InfoRow(label: 'Dest', value: dest?['address']?.toString() ?? '—'),
                InfoRow(label: 'Fare', trailing: Text(
                  fare == null ? '—' : '₱$fare',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                )),
                InfoRow(
                  label: 'Type',
                  divider: false,
                  trailing: StatusBadge.forRideType(
                    booking?['ride_type']?.toString() ?? 'SHARED',
                  ),
                ),
              ],
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _err!),
          ],
          if (canAckPickup) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _ackPickupBusy ? null : _passengerAckPickup,
              icon: _ackPickupBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.location_on_outlined),
              label: Text(_ackPickupBusy ? 'Saving…' : 'I’m at the pickup'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap when you’ve reached the pickup point — we’ll treat it like a driver “arrived” signal for your ride.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
            ),
          ],
          if (passengerAckPickupAt != null && status != 'DRIVER_ARRIVED') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You’ve confirmed you’re at the pickup. Waiting for your driver to arrive and start the trip.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _cancelling ? null : _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(_cancelling ? 'Cancelling...' : 'Cancel booking'),
          ),
        ],
      ),
    );
  }

  String? _driverSubtitle(Map<String, dynamic> driver) {
    final toda = driver['toda_name']?.toString();
    final plate = driver['plate_number']?.toString();
    final parts = <String>[];
    if (toda != null && toda.isNotEmpty) parts.add('$toda TODA');
    if (plate != null && plate.isNotEmpty) parts.add(plate);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  int _etaMinutesFromBooking() {
    final fallback = 4;
    if (_statusEnteredAt == null) return fallback;
    final elapsed = DateTime.now().difference(_statusEnteredAt!).inMinutes;
    return (fallback - elapsed).clamp(1, 30);
  }

  // ---- Trip in progress view (mockup 05) ----

  Widget _inProgressView(
    Map<String, dynamic>? booking,
    Map<String, dynamic>? trip,
    Map<String, dynamic>? driver,
  ) {
    final dropoffAckAt = booking?['passenger_ack_dropoff_at'];
    final canAckDropoff = dropoffAckAt == null;
    final pickup = (booking?['pickup'] as Map?)?.cast<String, dynamic>();
    final dest = (booking?['destination'] as Map?)?.cast<String, dynamic>();
    final pickupPos = _maybeLatLng(pickup?['latitude'], pickup?['longitude']);
    final destPos = _maybeLatLng(dest?['latitude'], dest?['longitude']);
    final lastLoc = _maybeLatLng(
      (trip?['last_location'] as Map?)?['latitude'],
      (trip?['last_location'] as Map?)?['longitude'],
    );
    final fare = booking?['fare_amount']?.toString();
    final pickupShort = _shortLabel(pickup?['address']?.toString());
    final destShort = _shortLabel(dest?['address']?.toString());
    final passengerCount = trip?['passenger_count'];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRIP IN PROGRESS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pickupShort → $destShort',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                _PassengerMiniMap(
                  pickup: pickupPos,
                  destination: destPos,
                  driver: lastLoc,
                  height: 240,
                ),
                const SizedBox(height: 16),
                if (driver != null)
                  DriverCard(
                    compact: true,
                    name: driver['full_name']?.toString() ?? 'Your driver',
                    subtitle: _driverSubtitle(driver),
                    onCallPressed: _showDriverPhone,
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _stat(
                              value: _formatElapsed(),
                              label: 'Elapsed',
                            ),
                          ),
                          Expanded(
                            child: _stat(
                              value: passengerCount == null ? '—' : '$passengerCount',
                              label: 'Onboard',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          StatusBadge.forRideType(booking?['ride_type']?.toString() ?? 'SHARED'),
                          const Spacer(),
                          Text(
                            fare == null ? '—' : '₱$fare',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _err!),
                ],
                if (canAckDropoff) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _ackDropoffBusy ? null : _passengerAckDropoff,
                    icon: _ackDropoffBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.flag_outlined),
                    label: Text(_ackDropoffBusy ? 'Saving…' : 'I’ve arrived at my destination'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap when you’ve reached your drop-off — your driver sees this as your arrival at the stop.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
                  ),
                ] else if (dropoffAckAt != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You’ve marked arrival at your destination.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _formatElapsed() {
    final startStr = (_data?['trip'] as Map?)?['started_at']?.toString();
    if (startStr == null) {
      if (_statusEnteredAt == null) return '0:00';
      final secs = DateTime.now().difference(_statusEnteredAt!).inSeconds;
      return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    }
    final started = DateTime.tryParse(startStr)?.toLocal();
    if (started == null) return '0:00';
    final secs = DateTime.now().difference(started).inSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _shortLabel(String? full) {
    if (full == null || full.isEmpty) return '—';
    if (full.length <= 18) return full;
    final end = math.min(16, full.length);
    return '${full.substring(0, end)}…';
  }

  // ---- Map helpers ----

  LatLng? _maybeLatLng(Object? lat, Object? lng) {
    final dlat = double.tryParse(lat?.toString() ?? '');
    final dlng = double.tryParse(lng?.toString() ?? '');
    if (dlat == null || dlng == null) return null;
    return LatLng(dlat, dlng);
  }
}

class _PassengerMiniMap extends StatefulWidget {
  final LatLng? pickup;
  final LatLng? destination;
  final LatLng? driver;
  final double height;

  const _PassengerMiniMap({
    required this.pickup,
    this.destination,
    this.driver,
    required this.height,
  });

  @override
  State<_PassengerMiniMap> createState() => _PassengerMiniMapState();
}

class _PassengerMiniMapState extends State<_PassengerMiniMap> {
  final MapController _mapController = MapController();
  bool _fitted = false;
  List<LatLng>? _routePoints;
  bool _routeLoading = false;
  LatLng? _lastFrom;
  LatLng? _lastTo;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(covariant _PassengerMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickup != oldWidget.pickup || widget.destination != oldWidget.destination) {
      _fetchRoute();
    }
    if (widget.driver != oldWidget.driver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitBounds();
      });
    }
  }

  Future<void> _fetchRoute() async {
    final from = widget.pickup;
    final to = widget.destination;
    if (from == null || to == null) return;
    if (from == _lastFrom && to == _lastTo && _routePoints != null) return;

    setState(() => _routeLoading = true);
    _lastFrom = from;
    _lastTo = to;

    final points = await OsrmService.fetchRoute(from, to);
    if (!mounted) return;
    setState(() {
      _routeLoading = false;
      _routePoints = points;
    });
  }

  void _fitBounds() {
    final points = <LatLng>[
      if (widget.pickup != null) widget.pickup!,
      if (widget.destination != null) widget.destination!,
      if (widget.driver != null) widget.driver!,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15.5);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (widget.pickup != null)
        Marker(
          point: widget.pickup!,
          width: 32,
          height: 32,
          child: const _MiniPin(color: AppColors.success, icon: Icons.my_location),
        ),
      if (widget.destination != null)
        Marker(
          point: widget.destination!,
          width: 32,
          height: 32,
          child: const _MiniPin(color: AppColors.danger, icon: Icons.place),
        ),
      if (widget.driver != null)
        Marker(
          point: widget.driver!,
          width: 36,
          height: 36,
          child: const _MiniPin(color: AppColors.primary, icon: Icons.electric_rickshaw),
        ),
    ];

    final center = widget.driver ?? widget.pickup ?? widget.destination ?? const LatLng(7.1117, 124.8419);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  if (!_fitted) {
                    _fitted = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fitBounds();
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tricykab.passenger',
                ),
                if (_routePoints != null && _routePoints!.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints!,
                        strokeWidth: 4,
                        color: AppColors.primary,
                      ),
                    ],
                  )
                else if (widget.pickup != null && widget.destination != null && distinctMapEndpoints(widget.pickup!, widget.destination!))
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [widget.pickup!, widget.destination!],
                        strokeWidth: 3,
                        color: AppColors.primary.withValues(alpha: 0.5),
                        pattern: StrokePattern.dashed(segments: const [8.0, 6.0]),
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
                const SimpleAttributionWidget(source: Text('OpenStreetMap'), onTap: null),
              ],
            ),
            if (_routeLoading)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary)),
                      const SizedBox(width: 6),
                      const Text('Loading route', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniPin extends StatelessWidget {
  const _MiniPin({required this.color, required this.icon});
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 18),
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
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
