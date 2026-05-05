import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'status_badge.dart';

/// Estimated-fare card (mockup 02): peso amount on the left, ride badge +
/// distance/duration meta on the right.
class FareEstimateCard extends StatelessWidget {
  const FareEstimateCard({
    super.key,
    required this.amountLabel,
    required this.rideType,
    required this.metaLabel,
    this.children = const <Widget>[],
  });

  final String amountLabel;
  final String rideType;
  final String metaLabel;
  final List<Widget> children;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMATED FARE',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge.forRideType(rideType),
                  const SizedBox(height: 6),
                  Text(
                    metaLabel,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    );
  }
}
