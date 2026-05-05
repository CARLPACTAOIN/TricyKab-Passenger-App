import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Animated `pulse-dot` used on the searching-driver screen.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 80});

  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final t = _ctrl.value;
              final scale = 0.8 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              final opacity = (t < 0.5 ? (1 - t * 1.2) : (0.4 + (t - 0.5) * 1.2))
                  .clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary10,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.search, color: Colors.white, size: widget.size * 0.27),
          ),
        ],
      ),
    );
  }
}
