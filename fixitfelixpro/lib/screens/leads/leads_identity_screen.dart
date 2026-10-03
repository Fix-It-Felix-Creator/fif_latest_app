import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'leads_about_screen.dart';
import 'leads_application.dart';
import 'leads_ui.dart';

/// Proving who you are.
///
/// Collected here rather than relied on from signup. The application used to
/// tell the reviewer that ID was "already on your account" — it is not: no
/// tradesperson account on this project has ever had a document, a selfie or a
/// National Insurance number stored against it. Approval was being granted on
/// a self-typed scheme number and nothing else.
///
/// Asking at the moment somebody requests to be sent into a stranger's home is
/// also simply the better moment: it is when the question has a reason, and
/// when the person has a motive to answer it.
class LeadsIdentityScreen extends StatefulWidget {
  const LeadsIdentityScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsIdentityScreen> createState() => _LeadsIdentityScreenState();
}

class _LeadsIdentityScreenState extends State<LeadsIdentityScreen> {
  final _picker = ImagePicker();

  LeadsApplicationDraft get draft => widget.draft;

  Future<void> _pick(LeadsDocumentSlot slot) async {
    // A selfie goes straight to the front camera. Offering a library for it
    // invites a photo of somebody else, or an old one — and the whole point
    // of the shot is that it was taken just now, by the person holding the
    // phone. A document is different: plenty of people already have a photo
    // of their passport, and making them dig it out again helps nobody.
    if (slot == LeadsDocumentSlot.selfie) {
      await _capture(ImageSource.camera, slot, front: true);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: leadsBrand),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: leadsBrand),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _capture(source, slot);
  }

  Future<void> _capture(
    ImageSource source,
    LeadsDocumentSlot slot, {
    bool front = false,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      // Only meaningful with the camera, and ignored for the gallery.
      preferredCameraDevice:
          front ? CameraDevice.front : CameraDevice.rear,
      // Resized on the way in rather than on the way out. A modern phone
      // camera produces 4-6MB a shot, and three of those is a slow upload on
      // a van's signal for no readable gain — 1600px is more than enough to
      // read a passport number.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      draft.setDocument(slot, file.path);
      draft.touch();
    });
  }

  void _clear(LeadsDocumentSlot slot) {
    setState(() {
      draft.setDocument(slot, null);
      draft.touch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = draft.documentType;

    return LeadsStepScaffold(
      step: draft.stepIdentity,
      totalSteps: draft.totalSteps,
      title: 'Prove it is you',
      subtitle: 'One photo ID and a selfie. Our team checks the two match '
          'before approving you — customers are letting a stranger in.',
      actionLabel: 'Continue',
      footnote: draft.identityComplete
          ? null
          : type == null
              ? 'Choose which document you will use.'
              : draft.missingDocumentSlots.isNotEmpty
                  ? 'Add ${_slotLabel(draft.missingDocumentSlots.first)}.'
                  : 'Add a selfie.',
      onAction: draft.identityComplete
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsAboutScreen(draft: draft),
                ),
              )
          : null,
      child: Column(
        children: [
          const LeadsCaption('Which document'),
          LeadsCard(
            children: [
              for (var i = 0; i < LeadsDocumentType.values.length; i++) ...[
                if (i > 0) const LeadsDivider(),
                _TypeRow(
                  type: LeadsDocumentType.values[i],
                  selected: type == LeadsDocumentType.values[i],
                  onTap: () => setState(() {
                    draft.setDocumentType(LeadsDocumentType.values[i]);
                    draft.touch();
                  }),
                ),
              ],
            ],
          ),

          if (type != null) ...[
            const LeadsCaption('Photos of it'),
            for (final slot in type.slots)
              _UploadTile(
                label: _slotLabel(slot),
                hint: _slotHint(slot),
                path: draft.documentPaths[slot],
                onPick: () => _pick(slot),
                onClear: () => _clear(slot),
              ),

            const LeadsCaption('And a selfie'),
            _UploadTile(
              label: 'A photo of your face',
              hint: 'Opens the front camera. Good light, no sunglasses or hat',
              path: draft.selfiePath,
              onPick: () => _pick(LeadsDocumentSlot.selfie),
              onClear: () => _clear(LeadsDocumentSlot.selfie),
            ),
          ],

          const LeadsNotice(
            icon: LucideIcons.lock,
            text: 'These are stored privately and seen only by the person '
                'reviewing your application. They are never shown to '
                'customers.',
          ),
        ],
      ),
    );
  }

  static String _slotLabel(LeadsDocumentSlot slot) => switch (slot) {
        LeadsDocumentSlot.front => 'The photo page',
        LeadsDocumentSlot.back => 'The back',
        LeadsDocumentSlot.selfie => 'a selfie',
      };

  static String _slotHint(LeadsDocumentSlot slot) => switch (slot) {
        LeadsDocumentSlot.front =>
          'All four corners in frame, nothing covering the text',
        LeadsDocumentSlot.back => 'The side with the address or signature',
        LeadsDocumentSlot.selfie => '',
      };
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final LeadsDocumentType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circleDot : LucideIcons.circle,
              size: 19,
              color: selected ? leadsBrand : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              type.slots.length == 1 ? '1 photo' : '2 photos',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo, with a thumbnail once taken.
class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.label,
    required this.hint,
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String hint;
  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final taken = path != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: taken ? const Color(0xFFA7F3D0) : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: taken ? null : onPick,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // The photo itself once there is one. A tick alone would say it
              // worked without saying what was captured, and a thumb-covered
              // passport looks fine as a tick.
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: taken
                      ? Image.file(File(path!), fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            LucideIcons.camera,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (taken)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Retake',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(LucideIcons.refreshCw,
                          size: 16, color: Colors.grey.shade600),
                      onPressed: onPick,
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.x,
                          size: 16, color: Color(0xFFB91C1C)),
                      onPressed: onClear,
                    ),
                  ],
                )
              else
                const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: leadsBrand,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
