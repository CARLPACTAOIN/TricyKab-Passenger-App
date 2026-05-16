import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/passenger_repository.dart';

/// Passenger auth — deviation from PRD: register/login (email+password) with phone OTP verification.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key, required this.repo, required this.settings});

  final PassengerRepository repo;
  final AppSettings settings;

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _registerMode = false;
  bool _otpSent = false;
  bool _busy = false;
  String? _err;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.settings.lastPhone ?? '+63';
    _emailCtrl.text = widget.settings.lastEmail ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _resendTimer?.cancel();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpJoined => _otpCtrls.map((c) => c.text).join();

  void _resetOtpStep() {
    setState(() {
      _otpSent = false;
      _resendSeconds = 0;
      _err = null;
    });
    _resendTimer?.cancel();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  Future<void> _sendOtpForRegistration() async {
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (first.isEmpty || last.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() => _err = 'Please complete all required fields.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _err = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.repo.registerPassenger(
        email: email,
        password: pass,
        firstName: first,
        lastName: last,
        phoneNumber: phone,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        for (final c in _otpCtrls) {
          c.clear();
        }
      });
      _startResendCountdown();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _otpFocus.first.requestFocus();
      });
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _err = 'Enter your mobile number first.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.repo.requestOtpForPhoneVerification(phone);
      if (!mounted) return;
      setState(() {
        for (final c in _otpCtrls) {
          c.clear();
        }
      });
      _startResendCountdown();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _otpFocus.first.requestFocus();
      });
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPhone() async {
    final code = _otpJoined;
    if (code.length < 6) {
      setState(() => _err = 'Enter the full 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.repo.verifyPhone(
        email: _emailCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        otpCode: code,
      );
      if (!mounted) return;
      await widget.repo.loginPassenger(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/book', (_) => false);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _err = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.repo.loginPassenger(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/book', (_) => false);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _BrandHero(),
                  const SizedBox(height: 40),
                  if (!_registerMode) _loginCard() else (_otpSent ? _otpCard() : _registerCard()),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      "By continuing, you agree to TricyKab's Terms & Privacy Policy",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in to your account',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'EMAIL',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
              hintText: 'you@example.com',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'PASSWORD',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
              hintText: 'Your password',
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _err!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _login,
            icon: const Icon(Icons.login, size: 18),
            label: Text(_busy ? 'Signing in...' : 'Sign In'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    _resetOtpStep();
                    setState(() => _registerMode = true);
                  },
            child: const Text('Create an account'),
          ),
        ],
      ),
    );
  }

  Widget _registerCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create your passenger account',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                    hintText: 'First name',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                    hintText: 'Last name',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
              hintText: 'you@example.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
              hintText: 'Create a password (min 8 chars)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone, color: AppColors.primary, size: 20),
              hintText: '+63 917 123 4567',
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _err!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _sendOtpForRegistration,
            icon: const Icon(Icons.send, size: 18),
            label: Text(_busy ? 'Sending...' : 'Register & Send OTP'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    _resetOtpStep();
                    setState(() => _registerMode = false);
                  },
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }

  Widget _otpCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter verification code',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sent to ${_phoneCtrl.text.trim()}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(width: 44, child: _OtpBox(
                controller: _otpCtrls[i],
                focusNode: _otpFocus[i],
                onChanged: (v) {
                  if (v.length == 1 && i < 5) _otpFocus[i + 1].requestFocus();
                  if (v.isEmpty && i > 0) _otpFocus[i - 1].requestFocus();
                  if (_otpJoined.length == 6) _verifyPhone();
                },
              ));
            }),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _err!),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _verifyPhone,
            icon: const Icon(Icons.verified, size: 18),
            label: Text(_busy ? 'Verifying...' : 'Verify Phone & Continue'),
          ),
          TextButton(
            onPressed: _resendSeconds > 0 || _busy ? null : _resendOtp,
            child: Text(
              _resendSeconds > 0
                  ? 'Resend OTP in 0:${_resendSeconds.toString().padLeft(2, '0')}'
                  : 'Resend OTP',
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    _resetOtpStep();
                    setState(() => _registerMode = true);
                  },
            child: const Text('Edit registration details'),
          ),
        ],
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.electric_rickshaw, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'TricyKab',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Smart Tricycle Dispatch · Kabacan',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          fillColor: filled ? AppColors.primary10 : AppColors.cardBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: filled ? AppColors.primary : AppColors.border,
              width: filled ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
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
