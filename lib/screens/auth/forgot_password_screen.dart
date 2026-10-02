import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_step == 3) ...[
              const Text('Your password has been updated. You can sign in now.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to sign in')),
            ] else if (_step == 2) ...[
              Text('Enter the 6-digit code sent to ${_email.text} and choose a new password.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otp,
                decoration: const InputDecoration(labelText: 'Verification code', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter the code' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _reset,
                child: Text(_busy ? 'Updating…' : 'Update password'),
              ),
              TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Resend code')),
            ] else ...[
              const Text('We will email a one-time verification code to reset your password.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: Text(_busy ? 'Sending…' : 'Send verification code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
