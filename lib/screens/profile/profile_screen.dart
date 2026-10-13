import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/config/env.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';

/// Account settings for every mobile role — mirrors web `pages/shared/Profile.jsx`.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _oldPw = TextEditingController();
  final _otp = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _useEmailOtp = false;
  bool _otpSent = false;
  bool _otpSending = false;
  bool _profileBusy = false;
  bool _passwordBusy = false;
  String? _profileError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _oldPw.dispose();
    _otp.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  void _syncFromUser(AppUser user) {
    if (_name.text.isEmpty && _phone.text.isEmpty) {
      _name.text = user.fullName;
      _phone.text = user.phone;
    }
  }

  Future<void> _saveProfile(AuthController auth) async {
    setState(() {
      _profileBusy = true;
      _profileError = null;
    });
    final err = await auth.updateProfile(fullName: _name.text, phone: _phone.text);
    if (!mounted) return;
    setState(() {
      _profileBusy = false;
      if (err != null) {
        _profileError = err;
      } else {
        showSnack(context, 'Profile updated');
      }
    });
  }

  Future<void> _savePassword(AuthController auth) async {
    if (_newPw.text != _confirmPw.text) {
      setState(() => _passwordError = 'New passwords do not match.');
      return;
    }
    if (_newPw.text.length < 10) {
      setState(() => _passwordError = 'New password must be at least 10 characters.');
      return;
    }
    setState(() {
      _passwordBusy = true;
      _passwordError = null;
    });
    final err = await auth.changePassword(
      oldPassword: _useEmailOtp ? null : _oldPw.text,
      otp: _useEmailOtp ? _otp.text : null,
      newPassword: _newPw.text,
    );
    if (!mounted) return;
    setState(() {
      _passwordBusy = false;
      if (err != null) {
        _passwordError = err;
      } else {
        _oldPw.clear();
        _otp.clear();
        _newPw.clear();
        _confirmPw.clear();
        _otpSent = false;
        showSnack(context, 'Password changed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final services = context.read<AppServices>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    _syncFromUser(user);

    final parent = user.isParent ? context.watch<ParentController>() : null;

    final initial = user.fullName.isEmpty ? '?' : user.fullName.characters.first.toUpperCase();
    final schoolName = (user.isParent && parent != null)
        ? (parent.children.isNotEmpty ? parent.children.first.school.name : null)
        : auth.school?.name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        SrFadeIn(
          child: Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.brand, AppColors.brandDeep],
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.brand.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.slate),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip(label: UserRole.label(user.role), color: AppColors.brand),
                      if (schoolName != null && schoolName.isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 64),
                          child: _SchoolPill(name: schoolName),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SrFadeIn(
          delay: const Duration(milliseconds: 60),
          child: SectionCard(
            title: 'Personal information',
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                ),
                if (_profileError != null) ...[
                  const SizedBox(height: 10),
                  _ErrorText(_profileError!),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _profileBusy ? null : () => _saveProfile(auth),
                  child: Text(_profileBusy ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
        SrFadeIn(
          delay: const Duration(milliseconds: 120),
          child: SectionCard(
            title: 'Change password',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Current password', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: true, label: Text('Email code', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  selected: {_useEmailOtp},
                  onSelectionChanged: (s) => setState(() => _useEmailOtp = s.first),
                ),
                const SizedBox(height: 14),
                if (_useEmailOtp) ...[
                  Text(
                    'Code sent to ${user.email}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      onPressed: _otpSending
                          ? null
                          : () async {
                              setState(() {
                                _otpSending = true;
                                _passwordError = null;
                              });
                              final err = await auth.requestPasswordOtp(purpose: 'change_password');
                              if (!mounted) return;
                              setState(() {
                                _otpSending = false;
                                if (err != null) {
                                  _passwordError = err;
                                } else {
                                  _otpSent = true;
                                  showSnack(context, 'Verification code sent');
                                }
                              });
                            },
                      child: Text(_otpSending ? 'Sending…' : _otpSent ? 'Resend code' : 'Send verification code'),
                    ),
                  ),
                  TextField(
                    controller: _otp,
                    decoration: const InputDecoration(labelText: 'Verification code', prefixIcon: Icon(Icons.pin_outlined)),
                    keyboardType: TextInputType.number,
                  ),
                ] else
                  TextField(
                    controller: _oldPw,
                    decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPw,
                  decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_reset_outlined)),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPw,
                  decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined)),
                  obscureText: true,
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 10),
                  _ErrorText(_passwordError!),
                ],
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _passwordBusy ? null : () => _savePassword(auth),
                  child: Text(_passwordBusy ? 'Updating…' : 'Update password'),
                ),
              ],
            ),
          ),
        ),
        SrFadeIn(
          delay: const Duration(milliseconds: 180),
          child: SectionCard(
            title: 'Account details',
            child: Column(
              children: [
                if (user.isParent && parent != null) ...[
                  if (parent.error != null)
                    _InfoRow(
                      icon: Icons.error_outline,
                      color: AppColors.red,
                      title: 'Could not load linked children',
                      subtitle: parent.error!,
                      trailing: IconButton(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: const Icon(Icons.refresh),
                        onPressed: parent.load,
                      ),
                    )
                  else if (parent.loading)
                    const _InfoRow(icon: Icons.hourglass_empty, title: 'Loading linked schools…')
                  else
                    for (final child in parent.children)
                      _InfoRow(
                        icon: Icons.school_outlined,
                        title: child.school.name,
                        subtitle: [
                          child.student.fullName,
                          if (child.school.contactPhone.isNotEmpty) child.school.contactPhone,
                        ].join(' · '),
                      ),
                ] else if (auth.school != null)
                  _InfoRow(
                    icon: Icons.school_outlined,
                    title: auth.school!.name,
                    subtitle: auth.school!.contactPhone.isEmpty ? null : auth.school!.contactPhone,
                  ),
                _InfoRow(
                  icon: Icons.notifications_outlined,
                  title: 'Push notifications',
                  subtitle: services.notificationService.isPushAvailable
                      ? 'Enabled on this device'
                      : Env.firebaseConfigured
                          ? 'Unavailable (Firebase failed to start)'
                          : 'Not configured in this build – alerts are still listed in the app',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        SrFadeIn(
          delay: const Duration(milliseconds: 240),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () async {
              final warn = user.isDriver && await services.gps.isRunning;
              if (!context.mounted) return;
              final ok = await confirmDialog(
                context,
                title: 'Sign out?',
                message: warn
                    ? 'Live location sharing for the current trip will stop on this phone.'
                    : 'You will need to sign in again to use SafeRoute.',
                confirm: 'Sign out',
                destructive: warn,
              );
              if (ok) await auth.logout();
            },
          ),
        ),
      ],
    );
  }
}

class _SchoolPill extends StatelessWidget {
  const _SchoolPill({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.slate.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 14, color: AppColors.slate),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate),
              ),
            ),
          ],
        ),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.red, height: 1.3)),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color = AppColors.brand,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      );
}
