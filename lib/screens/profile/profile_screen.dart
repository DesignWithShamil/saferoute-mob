import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/config/env.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/parent_controller.dart';
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  user.fullName.isEmpty ? '?' : user.fullName.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
              Text(user.email),
              const SizedBox(height: 8),
              StatusChip(label: UserRole.label(user.role), color: AppColors.brand),
            ],
          ),
        ),
        SectionCard(
          title: 'Personal information',
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              if (_profileError != null) ...[
                const SizedBox(height: 8),
                Text(_profileError!, style: const TextStyle(color: AppColors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _profileBusy ? null : () => _saveProfile(auth),
                child: Text(_profileBusy ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Change password',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Current password')),
                  ButtonSegment(value: true, label: Text('Email code')),
                ],
                selected: {_useEmailOtp},
                onSelectionChanged: (s) => setState(() => _useEmailOtp = s.first),
              ),
              const SizedBox(height: 12),
              if (_useEmailOtp) ...[
                Text('Code sent to ${user.email}', style: Theme.of(context).textTheme.bodySmall),
                TextButton(
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
                TextField(
                  controller: _otp,
                  decoration: const InputDecoration(labelText: 'Verification code'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
              ] else
                TextField(controller: _oldPw, decoration: const InputDecoration(labelText: 'Current password'), obscureText: true),
              const SizedBox(height: 8),
              TextField(controller: _newPw, decoration: const InputDecoration(labelText: 'New password'), obscureText: true),
              const SizedBox(height: 8),
              TextField(controller: _confirmPw, decoration: const InputDecoration(labelText: 'Confirm new password'), obscureText: true),
              if (_passwordError != null) ...[
                const SizedBox(height: 8),
                Text(_passwordError!, style: const TextStyle(color: AppColors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _passwordBusy ? null : () => _savePassword(auth),
                child: Text(_passwordBusy ? 'Updating…' : 'Update password'),
              ),
            ],
          ),
        ),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (user.isParent && parent != null) ...[
                if (parent.error != null)
                  ListTile(
                    leading: const Icon(Icons.error_outline, color: AppColors.red),
                    title: const Text('Could not load linked children'),
                    subtitle: Text(parent.error!),
                    trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: parent.load),
                  )
                else if (parent.loading)
                  const ListTile(title: Text('Loading linked schools…'))
                else
                  for (final child in parent.children)
                    ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(child.school.name),
                      subtitle: Text([
                        child.student.fullName,
                        if (child.school.contactPhone.isNotEmpty) child.school.contactPhone,
                      ].join(' · ')),
                    ),
              ] else if (auth.school != null)
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text(auth.school!.name),
                  subtitle: auth.school!.contactPhone.isEmpty ? null : Text(auth.school!.contactPhone),
                ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Push notifications'),
                subtitle: Text(services.notificationService.isPushAvailable
                    ? 'Enabled on this device'
                    : Env.firebaseConfigured
                        ? 'Unavailable (Firebase failed to start)'
                        : 'Not configured in this build – alerts are still listed in the app'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.red),
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
      ],
    );
  }
}
