import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/avatar_helper.dart';

const _brand = Color(0xFFF64C13);

/// What [ContactImportScreen] hands back via `Navigator.pop`.
///
/// Deliberately mirrors the fields of the New-customer form rather than the
/// contact record: the screen's job is to answer "what should the form say",
/// so the caller does not have to know anything about the contacts plugin.
class ContactImportResult {
  const ContactImportResult({
    required this.name,
    this.email = '',
    this.phone = '',
    this.line1 = '',
    this.city = '',
    this.postcode = '',
    this.county,
    this.formattedAddress,
  });

  final String name;
  final String email;
  final String phone;
  final String line1;
  final String city;
  final String postcode;
  final String? county;
  final String? formattedAddress;

  bool get hasAddress =>
      line1.isNotEmpty || city.isNotEmpty || postcode.isNotEmpty;
}

/// Pick one device contact to prefill the New-customer form.
///
/// Contacts are loaded in two passes on purpose. The list needs only display
/// names, and asking for properties makes the platform join phones, emails and
/// addresses for EVERY contact — slow enough to be visible on a large address
/// book. `getAll()` defaults to names only, and the full record is fetched for
/// the single contact the user actually taps.
class ContactImportScreen extends StatefulWidget {
  const ContactImportScreen({super.key});

  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

enum _Stage { loading, denied, ready, failed }

class _ContactImportScreenState extends State<ContactImportScreen> {
  final _searchCtrl = TextEditingController();

  _Stage _stage = _Stage.loading;
  List<Contact> _all = const [];
  String _query = '';
  bool _opening = false;

  /// iOS 18+ lets someone grant access to a hand-picked subset. That is a
  /// success, not a denial, but the list will look wrong (someone's contact
  /// "missing") unless we say why.
  bool _limited = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _stage = _Stage.loading);

    // PermissionType.read, not readWrite: this feature only ever reads, and
    // the difference is a "read your contacts" versus "read and change your
    // contacts" prompt.
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!mounted) return;

    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      setState(() => _stage = _Stage.denied);
      return;
    }

    try {
      final contacts = await FlutterContacts.getAll();
      if (!mounted) return;

      // A contact with no name is unusable as a customer name and cannot be
      // told apart from any other row in the list.
      final named =
          contacts
              .where((c) => (c.displayName ?? '').trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => (a.displayName ?? '').toLowerCase().compareTo(
                (b.displayName ?? '').toLowerCase(),
              ),
            );

      setState(() {
        _all = named;
        _limited = status == PermissionStatus.limited;
        _stage = _Stage.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.failed);
    }
  }

  List<Contact> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((c) => (c.displayName ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _choose(Contact summary) async {
    if (_opening) return;
    setState(() => _opening = true);

    // The id is what the detail fetch keys on; without it the summary (name
    // only) is all this contact will ever give us.
    final id = summary.id;

    Contact? full;
    try {
      full = id == null
          ? null
          : await FlutterContacts.get(
              id,
              properties: {
                ContactProperty.name,
                ContactProperty.phone,
                ContactProperty.email,
                ContactProperty.address,
              },
            );
    } catch (_) {
      full = null;
    }
    if (!mounted) return;
    setState(() => _opening = false);

    // Falling back to the summary keeps the name usable even if the detail
    // fetch fails — better a prefilled name than a dead tap.
    Navigator.of(context).pop(_toResult(full ?? summary));
  }

  static ContactImportResult _toResult(Contact c) {
    final address = c.addresses.isEmpty ? null : c.addresses.first;

    return ContactImportResult(
      name: (c.displayName ?? '').trim(),
      phone: _preferred(
        c.phones.map((p) => (label: p.label.label, value: p.number)).toList(),
        PhoneLabel.mobile,
      ),
      email: _preferred(
        c.emails.map((e) => (label: e.label.label, value: e.address)).toList(),
        EmailLabel.home,
      ),
      line1: _clean(address?.street),
      city: _clean(address?.city),
      postcode: _clean(address?.postalCode),
      county: _blankToNull(address?.state),
      formattedAddress: _blankToNull(address?.formatted),
    );
  }

  /// First value carrying [preferred] as its label, else the first value at
  /// all. Tradespeople want the mobile when a contact has both a mobile and a
  /// landline, and that is the common case.
  static String _preferred<T extends Enum>(
    List<({T label, String value})> items,
    T preferred,
  ) {
    if (items.isEmpty) return '';
    for (final i in items) {
      if (i.label == preferred && i.value.trim().isNotEmpty) {
        return i.value.trim();
      }
    }
    return items.first.value.trim();
  }

  static String _clean(String? s) => s?.trim() ?? '';

  static String? _blankToNull(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Import from contacts'),
      ),
      body: switch (_stage) {
        _Stage.loading => const Center(
          child: CircularProgressIndicator(color: _brand, strokeWidth: 2),
        ),
        _Stage.denied => _Message(
          icon: LucideIcons.userX,
          title: 'Contacts access is off',
          body:
              'Fix It Felix needs permission to read your contacts before '
              'it can fill in a customer for you.',
          actionLabel: 'Open Settings',
          onAction: FlutterContacts.permissions.openSettings,
          secondaryLabel: 'Try again',
          onSecondary: _load,
        ),
        _Stage.failed => _Message(
          icon: LucideIcons.triangleAlert,
          title: 'Could not read your contacts',
          body:
              'Something went wrong reading the address book on this '
              'device.',
          secondaryLabel: 'Try again',
          onSecondary: _load,
        ),
        _Stage.ready => _list(),
      },
    );
  }

  Widget _list() {
    if (_all.isEmpty) {
      return _Message(
        icon: LucideIcons.users,
        title: _limited ? 'No contacts shared' : 'No contacts on this device',
        body: _limited
            ? 'You chose which contacts Fix It Felix can see, and none were '
                  'selected. Pick some in Settings, or type the details in by '
                  'hand.'
            : 'Add someone to your phone contacts first, or type the '
                  "customer's details in by hand.",
        actionLabel: _limited ? 'Open Settings' : null,
        onAction: _limited ? FlutterContacts.permissions.openSettings : null,
        secondaryLabel: 'Try again',
        onSecondary: _load,
      );
    }

    final visible = _visible;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: Colors.grey.shade500,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_limited) const _LimitedAccessNote(),
          if (_opening)
            const LinearProgressIndicator(
              minHeight: 2,
              color: _brand,
              backgroundColor: Color(0xFFF5F5F7),
            ),
          if (visible.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No contact matches "${_query.trim()}"',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: visible.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 68,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (_, i) {
                  final name = (visible[i].displayName ?? '').trim();
                  return ListTile(
                    onTap: _opening ? null : () => _choose(visible[i]),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: avatarColorFor(name),
                      child: Text(
                        initialsFromName(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LimitedAccessNote extends StatelessWidget {
  const _LimitedAccessNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.info, size: 18, color: Color(0xFFB45309)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Only the contacts you allowed are shown.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
            TextButton(
              onPressed: FlutterContacts.permissions.openSettings,
              style: TextButton.styleFrom(
                foregroundColor: _brand,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Change', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: _brand),
                child: Text(actionLabel!),
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(foregroundColor: _brand),
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
