import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
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
      appBar: AppBar(title: const Text('Parent registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create your account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Verify your email first. After sign-in, use Add child with each school\'s link code.',
                  style: TextStyle(height: 1.35),
                ),
                const SizedBox(height: 24),
                if (!_otpStep) ...[
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile number'),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      return digits.length < 10 ? 'Enter at least 10 digits' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password (min 10 characters)'),
                    validator: (v) => (v == null || v.length < 10) ? 'At least 10 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Confirm your password' : null,
                  ),
                ] else ...[
                  if (_info != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: Text(_info!, style: const TextStyle(color: AppColors.brand, height: 1.35)),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Email verification code'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'In development, the code may also appear in the Django server log.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : (_otpStep ? _createAccount : _requestOtp),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(_busy ? 'Please wait…' : (_otpStep ? 'Verify & create account' : 'Send verification code')),
                ),
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
        ),
      ),
    );
  }
}
