import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/passenger_repository.dart';
import '../../../shared/widgets/info_row.dart';
import '../../../shared/widgets/status_badge.dart';

/// Mockup parity: TricyKab/mockups/passenger/06-trip-complete.html
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.repo, required this.bookingId});

  final PassengerRepository repo;
  final int bookingId;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Map<String, dynamic>? _data;
  String? _err;
  int? _selectedStars;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repo.receipt(widget.bookingId);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptNumber = _data?['receipt_number']?.toString();
    final payload = (_data?['payload'] as Map?)?.cast<String, dynamic>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.of(context).pushNamedAndRemoveUntil('/book', (_) => false),
        ),
      ),
      body: SafeArea(
        child: _data == null && _err == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SizedBox(height: 16),
                  _SuccessHero(
                    title: 'Trip Complete!',
                    subtitle: payload != null
                        ? "You've arrived at ${payload['destination_address'] ?? 'your destination'}"
                        : 'Your fare has been recorded.',
                  ),
                  const SizedBox(height: 24),
                  if (_err != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_err!, style: const TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    )
                  else if (payload == null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Text(
                        'Receipt is being prepared. Please check back in a moment.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ] else ...[
                    _summaryCard(payload),
                    const SizedBox(height: 12),
                    _paymentCard(payload, receiptNumber),
                    const SizedBox(height: 12),
                    _ratingCard(payload),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed('/trips'),
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('My trips'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil('/book', (_) => false),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Book Again'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard(Map<String, dynamic> payload) {
    final amountRaw = payload['amount'] ?? payload['fare_amount'];
    final amountLabel = amountRaw == null ? '₱—' : '₱$amountRaw';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          InfoRow(
            label: 'Pickup',
            value: payload['pickup_address']?.toString() ?? '—',
          ),
          InfoRow(
            label: 'Destination',
            value: payload['destination_address']?.toString() ?? '—',
          ),
          InfoRow(
            label: 'Passengers',
            value: payload['passenger_count']?.toString() ?? '—',
          ),
          InfoRow(
            label: 'Final fare',
            divider: false,
            trailing: Text(
              amountLabel,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> payload, String? receiptNumber) {
    final method = payload['method']?.toString().toUpperCase() ?? 'CASH';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          InfoRow(
            label: 'Payment',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payments, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text(method, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const InfoRow(
            label: 'Status',
            trailing: StatusBadge(
              label: 'COMPLETED',
              background: AppColors.badgeCompletedBg,
              foreground: AppColors.badgeCompletedText,
            ),
          ),
          InfoRow(
            label: 'Receipt',
            divider: false,
            trailing: Text(
              receiptNumber ?? '—',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingCard(Map<String, dynamic> payload) {
    final driverName = payload['driver_name']?.toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          const Text(
            'Rate your driver',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            driverName == null ? 'How was your ride?' : 'How was your ride with $driverName?',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = (_selectedStars ?? 0) > i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStars = i + 1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Thanks! Driver ratings will be saved server-side soon (PRD §15 deferred).',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 32,
                    color: filled ? AppColors.warning : AppColors.border,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Rating submission is a deferred PRD feature for the pilot.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.successLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_circle, color: AppColors.success, size: 36),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
