import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  int _step = 1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AuthController>().requestPasswordOtp(
          purpose: 'forgot_password',
          email: _email.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        _step = 2;
      }
    });
  }

  Future<void> _reset() async {
    if (_newPw.text != _confirmPw.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_newPw.text.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AuthController>().confirmForgotPassword(
          email: _email.text,
          otp: _otp.text,
          newPassword: _newPw.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        _step = 3;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget errorBox() => AnimatedSize(
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
        );

    final title = _step == 3 ? 'Password updated' : (_step == 2 ? 'Set a new password' : 'Forgot password?');
    final subtitle = _step == 3
        ? 'Your password has been updated. You can sign in now.'
        : (_step == 2
            ? 'Enter the 6-digit code sent to ${_email.text} and choose a new password.'
            : 'We will email a one-time verification code to reset your password.');
    final heroIcon = _step == 3 ? Icons.check_circle_rounded : (_step == 2 ? Icons.password_rounded : Icons.lock_reset_rounded);

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
                      icon: heroIcon,
                      title: title,
                      subtitle: subtitle,
                      onBack: _busy ? null : () => Navigator.of(context).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: SrFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey(_step),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_step == 3)
                                SrPrimaryButton(label: 'Back to sign in', icon: Icons.arrow_forward_rounded, onPressed: () => Navigator.pop(context))
                              else if (_step == 2) ...[
                                SrFormPanel(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _otp,
                                        decoration: const InputDecoration(labelText: 'Verification code', prefixIcon: Icon(Icons.pin_outlined)),
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) => (v == null || v.isEmpty) ? 'Enter the code' : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _newPw,
                                        obscureText: true,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _confirmPw,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                                      ),
                                      errorBox(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SrPrimaryButton(
                                  label: _busy ? 'Updating…' : 'Update password',
                                  busy: _busy,
                                  onPressed: _busy ? null : _reset,
                                ),
                                const SizedBox(height: 6),
                                TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Resend code')),
                              ] else ...[
                                SrFormPanel(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _email,
                                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                                        keyboardType: TextInputType.emailAddress,
                                        autocorrect: false,
                                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                                      ),
                                      errorBox(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SrPrimaryButton(
                                  label: _busy ? 'Sending…' : 'Send verification code',
                                  icon: _busy ? null : Icons.send_rounded,
                                  busy: _busy,
                                  onPressed: _busy ? null : _sendCode,
                                ),
                              ],
                            ],
                          ),
                        ),
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
