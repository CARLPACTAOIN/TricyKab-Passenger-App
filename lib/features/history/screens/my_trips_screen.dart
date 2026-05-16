import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/passenger_bookings_scope.dart';
import '../../../shared/widgets/app_brand.dart';
import '../../../shared/widgets/passenger_bottom_nav.dart';
import '../../../shared/widgets/status_badge.dart';

/// Mockup parity: TricyKab/mockups/passenger/07-trip-history.html
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

enum _Filter { all, completed, cancelled }

class _MyTripsScreenState extends State<MyTripsScreen> {
  _Filter _filter = _Filter.all;
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    PassengerBookingsScope.of(context).loadBookings(forceNetwork: false);
  }

  Future<void> _refresh() async {
    await PassengerBookingsScope.of(context).loadBookings(forceNetwork: true);
  }

  bool _matchesFilter(Map<String, dynamic> b) {
    final status = b['status']?.toString() ?? '';
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.completed:
        return status == 'COMPLETED';
      case _Filter.cancelled:
        return status.startsWith('CANCELLED') ||
            status == 'NO_SHOW_PASSENGER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PassengerBookingsScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppBrand(),
        actions: [
          PopupMenuButton<_Filter>(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list, color: AppColors.textMuted),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: _Filter.all,
                checked: _filter == _Filter.all,
                child: const Text('All trips'),
              ),
              CheckedPopupMenuItem(
                value: _Filter.completed,
                checked: _filter == _Filter.completed,
                child: const Text('Completed'),
              ),
              CheckedPopupMenuItem(
                value: _Filter.cancelled,
                checked: _filter == _Filter.cancelled,
                child: const Text('Cancelled'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final items = store.bookings;
            if (items == null && store.bookingsLoadError == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (store.bookingsLoadError != null && items == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    store.bookingsLoadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            }
            final filtered = (items ?? const <Map<String, dynamic>>[])
                .where(_matchesFilter)
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: filtered.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        const Text(
                          'Trip History',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          store.bookingsFetchedAt != null
                              ? 'Pull down to refresh'
                              : 'Your recent trips',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                _TripRow(
                                  booking: filtered[i],
                                  onTap: () => _open(filtered[i]),
                                ),
                                if (i != filtered.length - 1)
                                  const Divider(height: 1, color: AppColors.borderLight),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
      bottomNavigationBar: const PassengerBottomNav(current: PassengerNavTab.trips),
    );
  }

  void _open(Map<String, dynamic> b) {
    final id = b['id'];
    final status = b['status']?.toString();
    if (id is! int) return;
    if (status == 'COMPLETED') {
      Navigator.of(context).pushNamed('/receipt', arguments: id);
    } else if (status != null && !status.startsWith('CANCELLED') && status != 'NO_SHOW_PASSENGER') {
      Navigator.of(context).pushNamed('/active', arguments: id);
    }
  }

  Widget _emptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary10,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.directions_bike, size: 32, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No trips yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Book your first ride to see it here.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamedAndRemoveUntil('/book', (_) => false),
            icon: const Icon(Icons.local_taxi),
            label: const Text('Book a ride'),
          ),
        ),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.booking, required this.onTap});

  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pickup = (booking['pickup'] as Map?)?['address']?.toString() ?? 'Pickup';
    final dest = (booking['destination'] as Map?)?['address']?.toString() ?? 'Destination';
    final status = booking['status']?.toString() ?? 'COMPLETED';
    final rideType = booking['ride_type']?.toString() ?? 'SHARED';
    final fare = booking['estimated_fare'] ?? booking['fare_amount'];
    final isCancelled = status.startsWith('CANCELLED') || status == 'NO_SHOW_PASSENGER';
    final createdAt = DateTime.tryParse(booking['created_at']?.toString() ?? '')?.toLocal();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCancelled ? AppColors.dangerLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                isCancelled ? Icons.cancel : Icons.check_circle,
                color: isCancelled ? AppColors.danger : AppColors.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pickup → $dest',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          createdAt == null
                              ? 'Recent'
                              : DateFormat('MMM d, h:mm a').format(createdAt),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      isCancelled
                          ? const StatusBadge(
                              label: 'CANCELLED',
                              background: AppColors.badgeCancelledBg,
                              foreground: AppColors.badgeCancelledText,
                              dense: true,
                            )
                          : StatusBadge.forRideType(rideType),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              fare == null ? '—' : '₱$fare',
              style: TextStyle(
                color: isCancelled ? AppColors.textMuted : AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
