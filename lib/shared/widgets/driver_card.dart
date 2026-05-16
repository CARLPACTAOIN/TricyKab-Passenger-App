import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Driver presentation card (mockups 04 / 05).
///
/// Shows initials avatar, driver name, TODA + plate meta, and a phone CTA
/// that surfaces the number via the [onCallPressed] callback.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.name,
    this.subtitle,
    this.plateNumber,
    this.onCallPressed,
    this.compact = false,
    this.licenseVerified = false,
  });

  final String name;
  final String? subtitle;
  final String? plateNumber;
  final VoidCallback? onCallPressed;
  final bool compact;
  final bool licenseVerified;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String ch(String s) {
      if (s.isEmpty) return '';
      final it = s.runes.iterator;
      if (!it.moveNext()) return '';
      return String.fromCharCode(it.current).toUpperCase();
    }
    if (parts.length == 1) {
      final c = ch(parts.first);
      return c.isEmpty ? '?' : c;
    }
    final a = ch(parts[0]);
    final b = ch(parts[1]);
    final out = '$a$b';
    return out.isEmpty ? '?' : out;
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 36.0 : 48.0;
    final avatarRadius = compact ? 10.0 : 14.0;
    final nameSize = compact ? 13.0 : 15.0;
    final metaSize = compact ? 11.0 : 12.0;
    final callSize = compact ? 36.0 : 44.0;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: AppColors.primary10,
                  borderRadius: BorderRadius.circular(avatarRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: nameSize,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(color: AppColors.textMuted, fontSize: metaSize),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: callSize,
                height: callSize,
                child: OutlinedButton(
                  onPressed: onCallPressed,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 2),
                  ),
                  child: Icon(Icons.phone, size: compact ? 18 : 20),
                ),
              ),
            ],
          ),
          if (!compact && (plateNumber != null || licenseVerified)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (plateNumber != null && plateNumber!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.electric_rickshaw, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Plate: $plateNumber',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                if (licenseVerified)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      const Text(
                        'License verified',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
