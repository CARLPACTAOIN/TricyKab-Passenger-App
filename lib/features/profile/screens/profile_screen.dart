import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/passenger_bookings_scope.dart';
import '../../../data/passenger_repository.dart';
import '../../../shared/widgets/passenger_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.repo, required this.settings});

  final PassengerRepository repo;
  final AppSettings settings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  String? _err;

  final _addressCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();

  String _email = '';
  String _phone = '';
  String _name = '';
  String _photoUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final data = await widget.repo.myProfile();
      final profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

      _email = '${profile['email'] ?? ''}';
      _phone = '${profile['phone'] ?? ''}';
      final first = '${profile['first_name'] ?? ''}'.trim();
      final last = '${profile['last_name'] ?? ''}'.trim();
      _name = ('$first $last').trim();

      _addressCtrl.text = '${profile['home_address'] ?? ''}';
      _ecNameCtrl.text = '${profile['emergency_contact_name'] ?? ''}';
      _ecPhoneCtrl.text = '${profile['emergency_contact_phone'] ?? ''}';
      _photoUrl = '${profile['profile_photo_url'] ?? ''}'.trim();
      _photoCtrl.text = _photoUrl;
    } catch (e) {
      _err = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.repo.updateProfile(
        homeAddress: _addressCtrl.text.trim(),
        emergencyContactName: _ecNameCtrl.text.trim(),
        emergencyContactPhone: _ecPhoneCtrl.text.trim(),
        profilePhotoUrl: _photoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      _err = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await PassengerBookingsScope.of(context).clear();
    await widget.settings.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await PassengerBookingsScope.of(context).clear();
              await widget.settings.clearTokens();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: const PassengerBottomNav(current: PassengerNavTab.profile),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Card(
              child: Row(
                children: [
                  _ProfileAvatar(url: _photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name.isEmpty ? 'Passenger' : _name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email.isEmpty ? '—' : _email,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _phone.isEmpty ? '—' : _phone,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OPTIONAL DETAILS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary, size: 20),
                      hintText: 'Home address (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ecNameCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.contact_phone_outlined, color: AppColors.primary, size: 20),
                      hintText: 'Emergency contact name (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ecPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.phone_in_talk_outlined, color: AppColors.primary, size: 20),
                      hintText: 'Emergency contact phone (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _photoCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.photo_outlined, color: AppColors.primary, size: 20),
                      hintText: 'Profile photo URL (optional)',
                    ),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 10),
                    _ErrorBanner(message: _err!),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(_busy ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        color: AppColors.primary10,
        child: hasUrl
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.account_circle_outlined,
                color: AppColors.primary,
              ),
      ),
    );
  }
}

