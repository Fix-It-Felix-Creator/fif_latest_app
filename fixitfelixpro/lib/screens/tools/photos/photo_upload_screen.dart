import 'dart:io' show File, Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/utils/common_dialogs.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../repositories/tools/photos_repository.dart';
import '../../../services/photo_number_sequence.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _picked;
  bool _uploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (picked == null) return;
    // Suggest the next sequenced title (e.g. "IMG000005") only if the
    // field is empty — never overwrite the user's typing. The counter
    // doesn't advance until upload succeeds, so cancelling out won't
    // burn a number.
    String? suggestion;
    if (_titleCtrl.text.trim().isEmpty) {
      final next = await PhotoNumberSequence.peek();
      suggestion = PhotoNumberSequence.format(next);
    }
    if (!mounted) return;
    setState(() {
      _picked = File(picked.path);
      if (suggestion != null) _titleCtrl.text = suggestion;
    });
  }

  Future<void> _showSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Add a photo'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickFromSource(ImageSource.camera);
              },
              child: const Text('Take photo'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickFromSource(ImageSource.gallery);
              },
              child: const Text('Choose from library'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
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
              leading: const Icon(LucideIcons.camera, color: _brand),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: _brand),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromSource(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  bool get _canUpload =>
      !_uploading && _picked != null && _titleCtrl.text.trim().isNotEmpty;

  Future<void> _upload() async {
    if (!_canUpload) return;
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    final repo = PhotosRepository();
    final result = await repo.upload(
      file: _picked!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result == null) {
      CommonToasts.error(context, 'Could not upload the photo');
      return;
    }
    // Advance the IMG counter only on success — cancelling or failing
    // upload doesn't burn a number, so the next pick stays sequential.
    await PhotoNumberSequence.consume();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    if (!_uploading &&
        _picked == null &&
        _titleCtrl.text.isEmpty &&
        _descCtrl.text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    bool discard = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Discard photo?',
      message: 'You haven\'t uploaded yet.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_uploading && _picked == null && _titleCtrl.text.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: _uploading ? null : _confirmDiscard,
          ),
          title: const Text('New photo'),
          actions: [
            TextButton(
              onPressed: _canUpload ? _upload : null,
              child: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _brand,
                      ),
                    )
                  : Text(
                      'Upload',
                      style: TextStyle(
                        color: _canUpload ? _brand : Colors.grey.shade400,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              InkWell(
                onTap: _uploading ? null : _showSourceSheet,
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _picked == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.imagePlus,
                                  size: 32,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to choose a photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.file(_picked!, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (_uploading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: _brand,
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  enabled: !_uploading,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: _hintStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _descCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  enabled: !_uploading,
                  minLines: 3,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: _hintStyle,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
