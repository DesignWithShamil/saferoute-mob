import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/env.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/sr_transitions.dart';
import '../../widgets/state_views.dart';
import 'forgot_password_screen.dart';
import 'parent_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AuthController>().login(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionMessage = context.select<AuthController, String?>((a) => a.message);
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF4FF), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.brand.withValues(alpha: 0.92),
                                const Color(0xFF1D4ED8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.directions_bus_rounded, size: 44, color: Colors.white),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'SafeRoute',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'School transport — safe every mile',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Sign in as driver, helper, or parent',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.slate.withValues(alpha: 0.12))),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (sessionMessage != null && _error == null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(sessionMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.amber, height: 1.35)),
                                  ),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(_error!, style: const TextStyle(color: AppColors.red, height: 1.35), textAlign: TextAlign.center),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                      : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(srFadeRoute(const ParentRegisterScreen())),
                          child: const Text('New parent? Create an account'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(srFadeRoute(const ForgotPasswordScreen())),
                          child: const Text('Forgot password?'),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 8),
                          Text('API: ${Env.apiBaseUrl}', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                          if (Env.apiBaseUrl.contains('10.0.2.2'))
                            Text(
                              'On a physical phone, set API_BASE_URL to your PC IP in env/dev.json',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.amber),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
