import 'package:flutter/material.dart';

/// TricyKab Design System — Passenger App.
///
/// Tokens mirror `TricyKab/mockups/shared/styles.css` and the driver app, so
/// both Flutter clients render the same brand surface defined by the mockups.
class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF6258CA);
  static const Color primaryLight = Color(0xFF8078D6);
  static const Color primaryDark = Color(0xFF4E46A3);
  static const Color primary10 = Color(0x1A6258CA);
  static const Color primary20 = Color(0x336258CA);

  // Semantic
  static const Color success = Color(0xFF09AD95);
  static const Color successLight = Color(0xFFD1FAF4);
  static const Color warning = Color(0xFFF5A623);
  static const Color warningLight = Color(0xFFFEF3CD);
  static const Color info = Color(0xFF17A2B8);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);

  // Backgrounds
  static const Color background = Color(0xFFF6F6F8);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color subtleBackground = Color(0xFFF0F0F4);

  // Text
  static const Color textPrimary = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Badge palette (mockup parity)
  static const Color badgeSharedBg = Color(0xFFEDE9FE);
  static const Color badgeSharedText = Color(0xFF5B21B6);
  static const Color badgeSpecialBg = Color(0xFFFCE7F3);
  static const Color badgeSpecialText = Color(0xFF9D174D);
  static const Color badgeSearchingBg = Color(0xFFFEF3CD);
  static const Color badgeSearchingText = Color(0xFF92400E);
  static const Color badgeAssignedBg = Color(0xFFDBEAFE);
  static const Color badgeAssignedText = Color(0xFF1D4ED8);
  static const Color badgeInProgressBg = Color(0xFFE0F2FE);
  static const Color badgeInProgressText = Color(0xFF0369A1);
  static const Color badgeCompletedBg = Color(0xFFD1FAF4);
  static const Color badgeCompletedText = Color(0xFF065F46);
  static const Color badgeCancelledBg = Color(0xFFFEF2F2);
  static const Color badgeCancelledText = Color(0xFF991B1B);
  static const Color badgeOnlineBg = Color(0xFFD1FAF4);
  static const Color badgeOnlineText = Color(0xFF09AD95);
  static const Color badgeOfflineBg = Color(0xFFF1F5F9);
  static const Color badgeOfflineText = Color(0xFF64748B);
  static const Color badgeCashBg = Color(0xFFF0FDF4);
  static const Color badgeCashText = Color(0xFF166534);
}
