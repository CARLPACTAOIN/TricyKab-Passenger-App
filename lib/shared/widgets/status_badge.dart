import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Status pill matching `.badge` styles in `mockups/shared/styles.css`.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool dense;

  /// Shared/Special/etc. factory mapping.
  factory StatusBadge.forRideType(String rideType) {
    final upper = rideType.toUpperCase();
    if (upper == 'SPECIAL') {
      return const StatusBadge(
        label: 'SPECIAL',
        background: AppColors.badgeSpecialBg,
        foreground: AppColors.badgeSpecialText,
      );
    }
    return const StatusBadge(
      label: 'SHARED',
      background: AppColors.badgeSharedBg,
      foreground: AppColors.badgeSharedText,
    );
  }

  /// Booking status factory.
  factory StatusBadge.forBookingStatus(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'SEARCHING_DRIVER':
      case 'PENDING':
      case 'NEW':
        return const StatusBadge(
          label: 'SEARCHING',
          background: AppColors.badgeSearchingBg,
          foreground: AppColors.badgeSearchingText,
        );
      case 'DRIVER_ASSIGNED':
      case 'ACCEPTED':
        return const StatusBadge(
          label: 'ASSIGNED',
          background: AppColors.badgeAssignedBg,
          foreground: AppColors.badgeAssignedText,
        );
      case 'TRIP_IN_PROGRESS':
      case 'PRE_START':
      case 'IN_PROGRESS':
        return const StatusBadge(
          label: 'LIVE',
          background: AppColors.badgeInProgressBg,
          foreground: AppColors.badgeInProgressText,
        );
      case 'COMPLETED':
        return const StatusBadge(
          label: 'COMPLETED',
          background: AppColors.badgeCompletedBg,
          foreground: AppColors.badgeCompletedText,
        );
      case 'CANCELLED':
      case 'CANCELLED_BY_PASSENGER':
      case 'CANCELLED_BY_DRIVER':
      case 'NO_SHOW_PASSENGER':
        return const StatusBadge(
          label: 'CANCELLED',
          background: AppColors.badgeCancelledBg,
          foreground: AppColors.badgeCancelledText,
        );
    }
    return StatusBadge(
      label: s.replaceAll('_', ' '),
      background: AppColors.subtleBackground,
      foreground: AppColors.textSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: dense ? 11 : 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: dense ? 9 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
