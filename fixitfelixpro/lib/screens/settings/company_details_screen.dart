import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/utils/common_toasts.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class CompanyDetailsScreen extends StatefulWidget {
  const CompanyDetailsScreen({super.key});

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _vatNumberCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _websiteFocus = FocusNode();
  final _vatNumberFocus = FocusNode();

  bool _vatRegistered = false;
  String? _pendingLogoPath; // local file the user just picked
  String? _existingLogoUrl; // already uploaded
  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  void _hydrate() {
    if (_hydrated) return;
    final user = context.read<AuthBloc>().state.userDetails;
    if (user == null) return;
    final company = user.companyDetails;
    setState(() {
      _nameCtrl.text = company?.companyName ?? '';
      _phoneCtrl.text = user.phoneNumber;
      _websiteCtrl.text = company?.website ?? '';
      _vatNumberCtrl.text = company?.vatNumber ?? '';
      _vatRegistered = company?.vatRegistered ?? false;
      _existingLogoUrl = company?.companyLogoUrl;
      _hydrated = true;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _vatNumberCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _websiteFocus.dispose();
    _vatNumberFocus.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;
    setState(() => _pendingLogoPath = picked.path);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      CommonToasts.error(context, 'Company name is required');
      return;
    }

    setState(() => _saving = true);
    context.read<AuthBloc>().add(
      SaveBusinessProfileRequested(
        companyName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty
            ? null
            : _websiteCtrl.text.trim(),
        vatRegistered: _vatRegistered,
        vatNumber: _vatRegistered && _vatNumberCtrl.text.trim().isNotEmpty
            ? _vatNumberCtrl.text.trim()
            : null,
        logoImagePath: _pendingLogoPath,
      ),
    );

    // Give the stream listener a beat to propagate before popping.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    CommonToasts.success(context, 'Company details saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        if (!mounted) return;
        setState(() => _saving = false);
        CommonToasts.error(context, state.errorMessage ?? 'Save failed');
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text('Company Details'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _saving ? Colors.grey : _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final email = state.userDetails?.email ?? '';
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _LogoPicker(
                    pendingLogoPath: _pendingLogoPath,
                    existingLogoUrl: _existingLogoUrl,
                    onTap: _pickLogo,
                  ),
                  const SizedBox(height: 20),

                  _Group(
                    child: TextField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _phoneFocus.requestFocus(),
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Company name',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  _Group(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.mail,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              email.isEmpty ? '—' : email,
                              style: TextStyle(
                                fontSize: 15,
                                color: email.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  _Group(
                    child: TextField(
                      controller: _phoneCtrl,
                      focusNode: _phoneFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _websiteFocus.requestFocus(),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Phone',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  _Group(
                    child: TextField(
                      controller: _websiteCtrl,
                      focusNode: _websiteFocus,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Website',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  _Group(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Are you VAT registered?',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          Switch.adaptive(
                            value: _vatRegistered,
                            onChanged: (v) =>
                                setState(() => _vatRegistered = v),
                            activeThumbColor: _brand,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_vatRegistered)
                    _Group(
                      child: _InlineRow(
                        label: 'VAT number',
                        controller: _vatNumberCtrl,
                        focusNode: _vatNumberFocus,
                      ),
                    ),

                  const _SectionSpacer(label: 'Business address'),

                  _Group(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context)
                          .pushNamed('/settings/address'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.mapPin,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.userDetails?.address.isValid == true
                                    ? state.userDetails!.address.formatted
                                    : 'Set your address',
                                style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      state.userDetails?.address.isValid == true
                                          ? Colors.black87
                                          : Colors.grey.shade500,
                                ),
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.pendingLogoPath,
    required this.existingLogoUrl,
    required this.onTap,
  });

  final String? pendingLogoPath;
  final String? existingLogoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLogo = pendingLogoPath != null || existingLogoUrl != null;
    Widget avatar;
    if (pendingLogoPath != null) {
      avatar = Image.file(
        File(pendingLogoPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (existingLogoUrl != null) {
      avatar = CachedNetworkImage(
        imageUrl: existingLogoUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(color: Colors.grey.shade200),
        errorWidget: (_, __, ___) => Center(
          child: Icon(
            LucideIcons.building2,
            color: Colors.grey.shade400,
            size: 32,
          ),
        ),
      );
    } else {
      avatar = Center(
        child: Icon(
          LucideIcons.building2,
          size: 36,
          color: Colors.grey.shade400,
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: avatar,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onTap,
          icon: Icon(
            hasLogo ? LucideIcons.pencil : LucideIcons.plus,
            size: 16,
            color: _brand,
          ),
          label: Text(
            hasLogo ? 'Change logo' : 'Add logo',
            style: const TextStyle(
              color: _brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineRow extends StatelessWidget {
  const _InlineRow({
    required this.label,
    required this.controller,
    required this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => focusNode.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                textAlign: TextAlign.right,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                decoration: const InputDecoration(
                  hintText: '—',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _SectionSpacer extends StatelessWidget {
  const _SectionSpacer({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
