import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../models/job_request.dart';
import '../../models/services/service_catalog.dart';
import '../../repositories/job_requests/job_requests_repository.dart';
import '../../widgets/inset_group.dart';
import '../customers/address_search_screen.dart';
import 'service_tile.dart';

const _pageBg = Color(0xFFF5F5F7);
const _brand = Color(0xFFF64C13);

/// The last step: where, when, what was chosen, and confirm.
///
/// Address first. It is the only field that can block the button, and the one
/// most likely to already be filled from the profile — leading with it means
/// the common case is "check and confirm" rather than "scroll and hunt".
///
/// UI only. Confirm does not write anything — there is no customer-side job
/// record in the schema yet, and inventing one here would be a shape the
/// backend then has to live with. It shows what would be submitted and says
/// plainly that nothing was sent.
class JobSummaryScreen extends StatefulWidget {
  const JobSummaryScreen({
    super.key,
    required this.service,
    required this.selections,
  });

  final ServiceSummary service;

  /// The path through the question tree, outermost first.
  final List<FlowOption> selections;

  @override
  State<JobSummaryScreen> createState() => _JobSummaryScreenState();
}

class _JobSummaryScreenState extends State<JobSummaryScreen> {
  final _descriptionCtrl = TextEditingController();
  final _repository = JobRequestsRepository();

  JobUrgency _urgency = JobUrgency.soon;
  _JobLocation? _location;
  bool _posting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to the address already on the profile — most jobs are at the
    // home we already know about, and re-typing it is the commonest reason a
    // form like this gets abandoned.
    //
    // `location` rather than `address`: both describe the same place, but only
    // location carries the coordinates, and a job with no coordinates cannot
    // be offered to anyone.
    final details = context.read<AuthBloc>().state.userDetails;
    final loc = details?.location;
    final address = details?.address;
    final formatted = (loc?.address.trim().isNotEmpty ?? false)
        ? loc!.address.trim()
        : (address?.formatted.trim() ?? '');
    if (formatted.isNotEmpty) {
      _location = _JobLocation(
        formatted: formatted,
        line1: address?.addressLine1,
        line2: address?.addressLine2,
        city: address?.city,
        county: address?.county,
        postcode: address?.postcode,
        latitude: loc?.latitude,
        longitude: loc?.longitude,
      );
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<AddressResult>(
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );
    if (!mounted || result == null) return;
    if (result.formatted.trim().isEmpty) return;
    setState(() {
      _location = _JobLocation(
        formatted: result.formatted.trim(),
        line1: result.line1,
        line2: result.line2,
        city: result.city,
        county: result.county,
        postcode: result.postcode,
        latitude: result.latitude,
        longitude: result.longitude,
      );
      _error = null;
    });
  }

  bool get _ready => _location != null;

  Future<void> _post() async {
    final where = _location;
    if (where == null || _posting) return;

    setState(() {
      _posting = true;
      _error = null;
    });

    final id = await _repository.post(
      serviceId: widget.service.id,
      serviceName: widget.service.name,
      selections: [
        for (final s in widget.selections)
          JobRequestSelection(id: s.id, name: s.name),
      ],
      description: _descriptionCtrl.text.trim(),
      urgency: _urgency,
      formattedAddress: where.formatted,
      line1: where.line1,
      line2: where.line2,
      city: where.city,
      county: where.county,
      postcode: where.postcode,
      latitude: where.latitude,
      longitude: where.longitude,
    );

    if (!mounted) return;
    setState(() {
      _posting = false;
      _submitted = id != null;
      _error = id == null
          ? 'That job could not be posted. Check your connection and try again.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Confirm your job'),
      ),
      body: _submitted
          ? _Submitted(service: widget.service)
          : ListView(
              padding: const EdgeInsets.only(top: 2, bottom: 24),
              // Scrolling the page away also puts the keyboard away — the
              // other half of "I am done typing now".
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const SectionHeader('Where'),
                InsetGroup(
                  children: [
                    _PickerRow(
                      label: 'Address',
                      icon: LucideIcons.mapPin,
                      value: _location?.formatted,
                      placeholder: 'Select an address',
                      onTap: _pickAddress,
                    ),
                  ],
                ),

                const SectionHeader('When'),
                _UrgencyToggle(
                  value: _urgency,
                  onChanged: (u) => setState(() => _urgency = u),
                ),

                const SectionHeader('What you need'),
                InsetGroup(
                  children: [
                    _ServiceRow(service: widget.service),
                    if (widget.selections.isNotEmpty) ...[
                      const HairlineDivider(),
                      _SelectionTrail(selections: widget.selections),
                    ],
                  ],
                ),

                const SectionHeader('Anything else we should know?'),
                InsetGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: TextField(
                        controller: _descriptionCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        minLines: 3,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Describe the problem, how to get in, or '
                              'anything a tradesperson should bring.',
                          hintStyle: TextStyle(
                            color: Colors.black.withValues(alpha: 0.28),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: _submitted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else if (!_ready) ...[
                      Text(
                        'Choose an address to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else if (!_location!.hasCoordinates) ...[
                      // Not a blocker — the job is still real and staff can
                      // geocode it — but it is the one thing that stops it
                      // reaching a tradesperson on its own, so it is said out
                      // loud rather than discovered later by nobody calling.
                      Text(
                        'We could not pin this address on the map, so nearby '
                        'tradespeople will not be alerted automatically. '
                        'Picking it from the search again usually fixes it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _ready && !_posting ? _post : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          // From the theme, not a bare TextStyle. A
                          // `styleFrom` textStyle REPLACES the resolved label
                          // style rather than merging with it, so a const
                          // TextStyle here carries fontFamily: null and the
                          // button renders in the platform default font while
                          // the rest of the screen is Montserrat.
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                          elevation: 0,
                        ),
                        child: _posting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirm and post job'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The chosen service, as a header row.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service});

  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: ServiceArtwork(service: service, radius: 8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if ((service.subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    service.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole path through the questions, not just the leaf.
///
/// "Heating & Hot Water › Install new boiler › Combi boiler" is the job. A
/// tradesperson reading only the last part would be quoting blind.
class _SelectionTrail extends StatelessWidget {
  const _SelectionTrail({required this.selections});

  final List<FlowOption> selections;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < selections.length; i++)
            Padding(
              padding: EdgeInsets.only(
                left: i * 14.0,
                bottom: i == selections.length - 1 ? 0 : 6,
              ),
              child: Row(
                children: [
                  Icon(
                    i == selections.length - 1
                        ? LucideIcons.circleCheck
                        : LucideIcons.cornerDownRight,
                    size: 14,
                    color: i == selections.length - 1
                        ? _brand
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selections[i].name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: i == selections.length - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Urgency as one segmented control rather than three stacked cards.
///
/// The three-card version cost about 150pt for what is a single choice out of
/// three, and pushed everything below it off the first screen. This is the
/// Pro app's toggle: grey trough, white pill for the selection, and the full
/// sentence as a caption so nothing is lost to the short labels.
class _UrgencyToggle extends StatelessWidget {
  const _UrgencyToggle({required this.value, required this.onChanged});

  final JobUrgency value;
  final ValueChanged<JobUrgency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFF3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (final u in JobUrgency.values)
                  Expanded(child: _segment(u)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              value.detail,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(JobUrgency u) {
    final selected = value == u;
    return GestureDetector(
      onTap: () => onChanged(u),
      // Opaque so the whole segment is tappable, not just the glyphs in it.
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          u.short,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? _brand : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _Submitted extends StatelessWidget {
  const _Submitted({required this.service});

  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.check,
                  size: 30, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              'Your ${service.name.toLowerCase()} job is posted',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'We are looking for tradespeople near you. You can follow it, '
              'and cancel it, from the Jobs tab.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.value,
    this.placeholder,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                hasValue ? value! : (placeholder ?? ''),
                textAlign: TextAlign.right,
                // Two lines, not one: a UK address wrapped to "12 Alexandra
                // Road, Hounslow, TW3…" is the field failing at the only job
                // it has, which is letting someone check the address.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: hasValue ? _brand : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where the job is, with everything the row needs to be matched on.
///
/// Its own type rather than a bare string because the coordinates travel with
/// the address and must not get separated from it — an address picked from the
/// search carries a pin, and losing that on the way to the insert is how a job
/// ends up reaching nobody.
class _JobLocation {
  const _JobLocation({
    required this.formatted,
    this.line1,
    this.line2,
    this.city,
    this.county,
    this.postcode,
    this.latitude,
    this.longitude,
  });

  final String formatted;
  final String? line1;
  final String? line2;
  final String? city;
  final String? county;
  final String? postcode;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}
