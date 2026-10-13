import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';

class ParentRegisterScreen extends StatefulWidget {
  const ParentRegisterScreen({super.key});

  @override
  State<ParentRegisterScreen> createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  bool _otpStep = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final err = await context.read<AuthController>().requestParentRegisterOtp(
          fullName: _name.text,
          email: _email.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        _otpStep = true;
        _info = 'Verification code sent to ${_email.text.trim()}.';
      }
    });
  }

  Future<void> _createAccount() async {
    if (_busy) return;
    if (_otp.text.trim().isEmpty) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AuthController>().registerParent(
          fullName: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          otp: _otp.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SrAuthBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SrAuthHero(
                      compact: true,
                      showFeatures: false,
                      icon: Icons.family_restroom_rounded,
                      title: 'Create your account',
                      subtitle: 'Verify your email first. After sign-in, use Add child with each school\'s link code.',
                      onBack: _busy ? null : () => Navigator.of(context).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SrFadeIn(delay: const Duration(milliseconds: 150), child: _StepIndicator(step: _otpStep ? 2 : 1)),
                          const SizedBox(height: 16),
                          SrFadeIn(
                            delay: const Duration(milliseconds: 250),
                            child: SrFormPanel(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: Column(
                                  key: ValueKey(_otpStep),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (!_otpStep) ...[
                                      TextFormField(
                                        controller: _name,
                                        decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                                        textCapitalization: TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _email,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _phone,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                                        validator: (v) {
                                          final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                          return digits.length < 10 ? 'Enter at least 10 digits' : null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _password,
                                        obscureText: _obscure,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: 'Password (min 10 characters)',
                                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                            onPressed: () => setState(() => _obscure = !_obscure),
                                          ),
                                        ),
                                        validator: (v) => (v == null || v.length < 10) ? 'At least 10 characters' : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _confirm,
                                        obscureText: _obscure,
                                        textInputAction: TextInputAction.done,
                                        decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                                        validator: (v) => (v == null || v.isEmpty) ? 'Confirm your password' : null,
                                      ),
                                    ] else ...[
                                      if (_info != null)
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.mark_email_read_rounded, color: AppColors.brand),
                                              const SizedBox(width: 10),
                                              Expanded(child: Text(_info!, style: const TextStyle(color: AppColors.brandDeep, height: 1.35, fontWeight: FontWeight.w600))),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _otp,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Email verification code', prefixIcon: Icon(Icons.pin_outlined)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'In development, the code may also appear in the Django server log.',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Container(
                                    margin: const EdgeInsets.only(top: 14),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.red, height: 1.35))),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          SrFadeIn(
                            delay: const Duration(milliseconds: 350),
                            child: SrPrimaryButton(
                              label: _busy ? 'Please wait…' : (_otpStep ? 'Verify & create account' : 'Send verification code'),
                              icon: _busy ? null : Icons.arrow_forward_rounded,
                              busy: _busy,
                              onPressed: _busy ? null : (_otpStep ? _createAccount : _requestOtp),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_otpStep)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _otpStep = false;
                                        _otp.clear();
                                        _error = null;
                                      }),
                              child: const Text('Back to edit details'),
                            ),
                          TextButton(
                            onPressed: _busy ? null : () => Navigator.of(context).pop(),
                            child: const Text('Back to sign in'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    Widget dot(int n, String label) {
      final active = step >= n;
      return Expanded(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.brand : AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? AppColors.brand : AppColors.slate),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        dot(1, '1 · Your details'),
        const SizedBox(width: 10),
        dot(2, '2 · Verify email'),
      ],
    );
  }
}
