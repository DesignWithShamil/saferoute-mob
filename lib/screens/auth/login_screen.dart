import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/env.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/sr_animations.dart';
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
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: SrAuthBackground(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SrAuthHero(
                        title: 'SafeRoute',
                        subtitle: 'School transport — safe every mile',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SrFadeIn(
                              delay: const Duration(milliseconds: 200),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Welcome back',
                                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6, color: AppColors.ink)),
                                  const SizedBox(height: 4),
                                  const Text('Sign in as driver, helper, or parent',
                                      style: TextStyle(color: AppColors.slate, fontSize: 14)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SrFadeIn(
                              delay: const Duration(milliseconds: 300),
                              child: SrFormPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (sessionMessage != null && _error == null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.amber.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(child: Text(sessionMessage, style: TextStyle(color: AppColors.onTint(AppColors.amber), height: 1.35))),
                                          ],
                                        ),
                                      ),
                                    TextFormField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
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
                                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                        ),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
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
                                    SrPrimaryButton(
                                      label: 'Sign in',
                                      icon: Icons.arrow_forward_rounded,
                                      busy: _busy,
                                      onPressed: _busy ? null : _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SrFadeIn(
                              delay: const Duration(milliseconds: 420),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => Navigator.of(context).push(srFadeRoute(const ParentRegisterScreen())),
                                      child: const FittedBox(fit: BoxFit.scaleDown, child: Text('New parent? Sign up')),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.slate,
                                        side: const BorderSide(color: AppColors.border, width: 1.2),
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => Navigator.of(context).push(srFadeRoute(const ForgotPasswordScreen())),
                                      child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Forgot password?')),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 14),
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
