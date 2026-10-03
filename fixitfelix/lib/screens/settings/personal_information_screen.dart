import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/utils/common_toasts.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.userDetails;
    _firstCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastCtrl = TextEditingController(text: user?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phoneNumber ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (first.length < 2) {
      CommonToasts.error(context, 'Enter a valid first name');
      return;
    }
    if (last.length < 2) {
      CommonToasts.error(context, 'Enter a valid last name');
      return;
    }
    if (phone.length < 7) {
      CommonToasts.error(context, 'Enter a valid phone number');
      return;
    }

    setState(() => _saving = true);
    context.read<AuthBloc>().add(
      UpdateUserDetailsRequested(
        updates: {
          'firstName': first,
          'lastName': last,
          'phoneNumber': phone,
        },
      ),
    );

    // The update is fire-and-forget on the BLoC side (stream listener
    // reconciles state). Give it a tick, show success, then pop.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    CommonToasts.success(context, 'Profile updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        if (!mounted) return;
        setState(() => _saving = false);
        CommonToasts.error(context, state.errorMessage ?? 'Update failed');
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.background,
          foregroundColor: colorScheme.foreground,
          elevation: 0,
          title: const Text('Personal Information'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _saving ? colorScheme.mutedForeground : colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel('First name'),
              ShadInput(
                controller: _firstCtrl,
                placeholder: const Text('First name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Last name'),
              ShadInput(
                controller: _lastCtrl,
                placeholder: const Text('Last name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Phone number'),
              ShadInput(
                controller: _phoneCtrl,
                placeholder: const Text('Phone number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Email'),
              ShadInput(
                controller: _emailCtrl,
                readOnly: true,
                enabled: false,
                placeholder: const Text('Email'),
              ),
              const SizedBox(height: 6),
              Text(
                'Email cannot be changed',
                style: theme.textTheme.small.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
