import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// PRD §7.19 — bottom sheet for filing a dispute.
///
/// Shows a type picker and a description field.
/// On confirm, calls [onSubmit] with the selected type and description.
/// The caller is responsible for the API call and error handling.
class DisputeSheet extends StatefulWidget {
  const DisputeSheet({super.key, required this.onSubmit});

  /// Called when the user taps Submit.  The sheet stays open while the future
  /// is resolving; the sheet closes itself on success.
  final Future<void> Function(String disputeType, String description) onSubmit;

  /// Convenience constructor — shows the sheet and returns the future from
  /// [onSubmit] (null if dismissed without submitting).
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String disputeType, String description)
        onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DisputeSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<DisputeSheet> {
  static const _types = <_DisputeOption>[
    _DisputeOption('FARE', 'Incorrect fare charged', Icons.payments_outlined),
    _DisputeOption('NO_SHOW', 'Driver did not show up', Icons.person_off_outlined),
    _DisputeOption('GPS', 'Wrong route / GPS problem', Icons.map_outlined),
    _DisputeOption('CONDUCT', 'Driver behaviour issue', Icons.sentiment_dissatisfied_outlined),
    _DisputeOption('SAFETY', 'Safety concern', Icons.shield_outlined),
    _DisputeOption('OTHER', 'Other issue', Icons.more_horiz),
  ];

  String? _selectedType;
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedType == null) {
      setState(() => _submitError = 'Please select an issue type.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.onSubmit(_selectedType!, _descController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Report an Issue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Your complaint will be reviewed by the TODA/LGU admin.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              // Type grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((opt) {
                    final selected = _selectedType == opt.value;
                    return GestureDetector(
                      onTap: _submitting
                          ? null
                          : () => setState(() {
                                _selectedType = opt.value;
                                _submitError = null;
                              }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary10
                              : AppColors.subtleBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              opt.icon,
                              size: 16,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_selectedType == null && _submitError != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    _submitError!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 16),
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  controller: _descController,
                  enabled: !_submitting,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Describe what happened (required)…',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.subtleBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'Please enter at least 10 characters.';
                    }
                    return null;
                  },
                ),
              ),
              if (_submitError != null && _selectedType != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined, size: 16),
                        label: Text(_submitting ? 'Submitting…' : 'Submit Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeOption {
  const _DisputeOption(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}
