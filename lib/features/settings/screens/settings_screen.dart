import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.onSaved});

  final AppSettings settings;
  final VoidCallback onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseCtrl;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: widget.settings.apiBase);
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setApiBase(_baseCtrl.text.trim());
    if (!mounted) return;
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _signOut() async {
    await widget.settings.clearTokens();
    if (!mounted) return;
    widget.onSaved();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = (widget.settings.accessToken ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _sectionHeader('TricyKab API'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'API BASE URL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _baseCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.cloud_outlined,
                          color: AppColors.primary, size: 20),
                      hintText: 'http://10.0.2.2:8000/api/v1',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use http://10.0.2.2:8000/api/v1 for the Android emulator.\n'
                    'Use http://<lan-ip>:8000/api/v1 for physical devices on the same Wi-Fi.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save & continue'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Session'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: hasToken
                              ? AppColors.successLight
                              : AppColors.subtleBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          hasToken ? Icons.verified_user : Icons.person_off_outlined,
                          color: hasToken ? AppColors.success : AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasToken
                              ? 'Signed in (token cached locally)'
                              : 'Not signed in.',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: hasToken ? _signOut : null,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out / clear token'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}
