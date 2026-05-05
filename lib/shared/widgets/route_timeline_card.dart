import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Card showing pickup → destination as a vertical timeline,
/// matching the dashed-line treatment in mockups 02–05.
class RouteTimelineCard extends StatelessWidget {
  const RouteTimelineCard({
    super.key,
    required this.pickupLabel,
    required this.destinationLabel,
    this.pickupSubtitle,
    this.destinationSubtitle,
    this.padding = const EdgeInsets.all(16),
  });

  final String pickupLabel;
  final String destinationLabel;
  final String? pickupSubtitle;
  final String? destinationSubtitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            icon: Icons.my_location,
            iconColor: AppColors.success,
            label: pickupLabel,
            subtitle: pickupSubtitle,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9, top: 6, bottom: 6),
            child: SizedBox(
              height: 16,
              child: CustomPaint(painter: _DashedVerticalPainter()),
            ),
          ),
          _row(
            icon: Icons.place,
            iconColor: AppColors.danger,
            label: destinationLabel,
            subtitle: destinationSubtitle,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedVerticalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
