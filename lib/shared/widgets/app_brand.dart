import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Header brand block: rounded purple logo + "TricyKab" wordmark.
///
/// Mirrors `.app-header .brand` in mockups/shared/styles.css.
class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 28.0 : 32.0;
    final iconSize = compact ? 16.0 : 18.0;
    final textSize = compact ? 16.0 : 18.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.electric_rickshaw, color: Colors.white, size: iconSize),
        ),
        const SizedBox(width: 8),
        Text(
          'TricyKab',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: textSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
