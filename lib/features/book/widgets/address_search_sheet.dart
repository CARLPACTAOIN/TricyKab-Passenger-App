import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/geocoding_service.dart';
import '../../../core/theme/app_colors.dart';

/// Popular Kabacan landmarks offered as quick-tap suggestions when the
/// search field is empty.  Coordinates are approximate pilot-quality values.
const _kPopularPlaces = [
  GeoPlace(
    shortName: 'Kabacan Public Market',
    displayName: 'Kabacan Public Market, Poblacion, Kabacan, North Cotabato',
    position: LatLng(7.1115, 124.8405),
  ),
  GeoPlace(
    shortName: 'USM Main Gate',
    displayName: 'University of Southern Mindanao, Kabacan, North Cotabato',
    position: LatLng(7.1043, 124.8446),
  ),
  GeoPlace(
    shortName: 'Kabacan Town Plaza',
    displayName: 'Poblacion, Kabacan, North Cotabato',
    position: LatLng(7.1120, 124.8400),
  ),
  GeoPlace(
    shortName: 'Kabacan Bus Terminal',
    displayName: 'Bus Terminal, Kabacan, North Cotabato',
    position: LatLng(7.1093, 124.8385),
  ),
  GeoPlace(
    shortName: 'Osias Market',
    displayName: 'Osias, Kabacan, North Cotabato',
    position: LatLng(7.1080, 124.8460),
  ),
  GeoPlace(
    shortName: 'Nongnongan Church',
    displayName: 'Nongnongan, Kabacan, North Cotabato',
    position: LatLng(7.1065, 124.8370),
  ),
];

/// Bottom-sheet address picker with real-time Photon/Nominatim suggestions.
///
/// Call [AddressSearchSheet.show] and await the returned [GeoPlace] (null if
/// the user cancelled or chose the GPS option via [onUseGps]).
class AddressSearchSheet extends StatefulWidget {
  const AddressSearchSheet({
    super.key,
    required this.label,
    this.near,
    this.onUseGps,
  });

  final String label;
  final LatLng? near;

  /// Called when the user taps "Use my current location". The sheet closes
  /// with null and the parent should then trigger GPS logic.
  final VoidCallback? onUseGps;

  static Future<GeoPlace?> show(
    BuildContext context, {
    required String label,
    LatLng? near,
    VoidCallback? onUseGps,
  }) {
    return showModalBottomSheet<GeoPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressSearchSheet(
        label: label,
        near: near,
        onUseGps: onUseGps,
      ),
    );
  }

  @override
  State<AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<AddressSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<GeoPlace> _results = const [];
  bool _loading = false;
  bool _searched = false;

  bool get _isPickup => widget.label.toLowerCase().contains('pickup');

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final places = await GeocodingService.search(v.trim(), near: widget.near);
      if (!mounted) return;
      setState(() {
        _results = places;
        _loading = false;
        _searched = true;
      });
    });
  }

  void _select(GeoPlace place) => Navigator.pop(context, place);

  void _useGpsAndClose() {
    Navigator.pop(context); // returns null → parent skips address update
    widget.onUseGps?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showPopular = _ctrl.text.trim().length < 2;
    final suggestions = showPopular ? _kPopularPlaces : _results;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            _header(),
            const SizedBox(height: 4),
            _searchField(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.borderLight,
                ),
              )
            else
              const SizedBox(height: 2),
            if (_isPickup && widget.onUseGps != null)
              _gpsItem(),
            if (showPopular)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Row(
                  children: const [
                    Icon(Icons.star_outline, size: 14, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'POPULAR IN KABACAN',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: suggestions.isEmpty && _searched && !_loading
                  ? _emptyState()
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: suggestions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, i) => _resultTile(suggestions[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Sub-widgets ----

  Widget _handle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _header() {
    final iconColor = _isPickup ? AppColors.success : AppColors.danger;
    final iconBg = _isPickup ? AppColors.successLight : AppColors.dangerLight;
    final icon = _isPickup ? Icons.my_location : Icons.place;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Set ${widget.label}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChanged,
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.search, color: AppColors.primary, size: 20),
          hintText: 'Search address in Kabacan…',
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    _ctrl.clear();
                    setState(() {
                      _results = const [];
                      _searched = false;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _gpsItem() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary10,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.gps_fixed, color: AppColors.primary, size: 18),
      ),
      title: const Text(
        'Use my current location',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: const Text(
        'Auto-detect via GPS',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      onTap: _useGpsAndClose,
    );
  }

  Widget _resultTile(GeoPlace place) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary10,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child:
            const Icon(Icons.location_on, color: AppColors.primary, size: 18),
      ),
      title: Text(
        place.shortName.isNotEmpty ? place.shortName : place.displayName,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        place.displayName,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _select(place),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off, size: 48, color: AppColors.border),
            SizedBox(height: 12),
            Text(
              'No results found',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Try a different search term.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
