import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum PassengerNavTab { book, trips, profile }

/// Bottom navigation matching mockup 02 (`Book` / `Trips` / `Profile`).
///
/// "Profile" surfaces the Settings screen (api base + sign out) for the pilot;
/// the PRD doesn't define a separate passenger profile management surface yet.
class PassengerBottomNav extends StatelessWidget {
  const PassengerBottomNav({super.key, required this.current});

  final PassengerNavTab current;

  void _onTap(BuildContext context, PassengerNavTab tab) {
    if (tab == current) return;
    switch (tab) {
      case PassengerNavTab.book:
        Navigator.of(context).pushNamedAndRemoveUntil('/book', (_) => false);
        break;
      case PassengerNavTab.trips:
        Navigator.of(context).pushNamedAndRemoveUntil('/trips', (_) => false);
        break;
      case PassengerNavTab.profile:
        Navigator.of(context).pushNamedAndRemoveUntil('/profile', (_) => false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: _item(context, PassengerNavTab.book, Icons.pin_drop, 'Book')),
            Expanded(child: _item(context, PassengerNavTab.trips, Icons.history, 'Trips')),
            Expanded(child: _item(context, PassengerNavTab.profile, Icons.account_circle_outlined, 'Profile')),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, PassengerNavTab tab, IconData icon, String label) {
    final active = tab == current;
    final color = active ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onTap(context, tab),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
