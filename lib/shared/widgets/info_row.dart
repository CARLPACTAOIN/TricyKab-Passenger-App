import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Two-column key/value row matching `.info-row` in the mockup CSS.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.divider = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: divider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight, width: 1),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            Flexible(child: Align(alignment: Alignment.centerRight, child: trailing!))
          else
            Flexible(
              child: Text(
                value ?? '—',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}
