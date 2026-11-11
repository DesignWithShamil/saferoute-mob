import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/sr_tokens.dart';
import '../../widgets/ethiyo_brand.dart';
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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _sheetFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _heroScale = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _sheetSlide = Tween<Offset>(begin: const Offset(0, 48), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.18, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _sheetFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.18, 0.65, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.28, 0.90, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
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
    final r = context.responsive;

    return Scaffold(
      backgroundColor: Colors.white,
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
              constraints: BoxConstraints(maxWidth: r.maxFormWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomInset = MediaQuery.paddingOf(context).bottom;
                  final availableHeight = constraints.maxHeight - bottomInset;
                  // Dynamic hero height: expands naturally on tall screens to show the
                  // bus illustration, keeping the form cohesive without any artificial gaps.
                  final heroHeight = (availableHeight - 430.0).clamp(170.0, 360.0);
                  final logoWidth = r.authLogoWidth;
                  final hPadding = r.horizontalGutter;

                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: bottomInset + 16),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Animated Hero scene at top
                            AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) => Opacity(
                                opacity: _heroFade.value,
                                child: Transform.scale(
                                  scale: _heroScale.value,
                                  child: child,
                                ),
                              ),
                              child: SrAuthHero(
                                showLogo: false,
                                heroHeight: heroHeight,
                                title: '',
                                subtitle: '',
                              ),
                            ),

                            // Form sheet with entrance animation & balanced responsive spacing
                            AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) => Opacity(
                                opacity: _sheetFade.value,
                                child: Transform.translate(
                                  offset: _sheetSlide.value + const Offset(0, -28),
                                  child: child,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Animated Centered Logo nested nicely inside the curve with small breathing space
                                    Center(
                                      child: AnimatedBuilder(
                                        animation: _animController,
                                        builder: (context, child) => Opacity(
                                          opacity: _logoFade.value,
                                          child: Transform.scale(
                                            scale: _logoScale.value,
                                            child: child,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 6, bottom: 8),
                                          child: EthiyoLogo(width: logoWidth),
                                        ),
                                      ),
                                    ),

                                    SrFadeIn(
                                      delay: const Duration(milliseconds: 60),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Welcome back',
                                            style: (r.isCompactWidth
                                                    ? theme.textTheme.titleLarge
                                                    : theme.textTheme.headlineSmall)
                                                ?.copyWith(
                                              color: AppColors.brandDeep,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Sign in to your account',
                                            style: TextStyle(
                                              color: AppColors.slate,
                                              fontSize: r.isCompactWidth ? 13 : 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: r.isShortScreen ? 12 : 18),
                                    if (sessionMessage != null && _error == null)
                                      _Banner(message: sessionMessage, color: AppColors.amber, icon: Icons.info_outline_rounded),
                                    TextFormField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
                                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                                    ),
                                    SizedBox(height: r.isShortScreen ? 10 : 14),
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
                                          tooltip: _obscure ? 'Show password' : 'Hide password',
                                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                        ),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                    ),
                                    AnimatedSize(
                                      duration: SrMotion.of(context, SrMotion.base),
                                      curve: SrMotion.curve,
                                      alignment: Alignment.topCenter,
                                      child: _error == null
                                          ? const SizedBox(width: double.infinity)
                                          : Padding(
                                              padding: const EdgeInsets.only(top: 12),
                                              child: _Banner(message: _error!, color: AppColors.red, icon: Icons.error_outline_rounded),
                                            ),
                                    ),
                                    SizedBox(height: r.isShortScreen ? 14 : 18),
                                    SrPrimaryButton(
                                      label: 'Sign in',
                                      icon: Icons.arrow_forward_rounded,
                                      busy: _busy,
                                      onPressed: _busy ? null : _submit,
                                    ),
                                    const SizedBox(height: 4),
                                    Center(
                                      child: TextButton(
                                        onPressed: _busy ? null : () => Navigator.of(context).push(srFadeRoute(const ForgotPasswordScreen())),
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const _OrDivider(),
                                    SizedBox(height: r.isShortScreen ? 8 : 12),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                                      label: const Text('New parent? Sign up'),
                                      onPressed: _busy ? null : () => Navigator.of(context).push(srFadeRoute(const ParentRegisterScreen())),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline message box: icon + text on a pale tint (never colour alone).
class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color, required this.icon});
  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(SrRadius.input),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.onTint(color), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: AppColors.onTint(color), height: 1.35, fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('or', style: TextStyle(color: AppColors.slate, fontSize: 13.5)),
          ),
          Expanded(child: Divider()),
        ],
      );
}
