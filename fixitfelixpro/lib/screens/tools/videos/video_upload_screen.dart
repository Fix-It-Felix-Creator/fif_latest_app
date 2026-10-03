import 'dart:io' show File, Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/utils/common_dialogs.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../repositories/tools/videos_repository.dart';
import '../../../services/video_number_sequence.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _picked;
  String? _thumbnailPath; // local temp file from video_thumbnail
  bool _generatingThumb = false;
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
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    // Suggest the next "VIDxxxxxx" title only when the field is empty;
    // we don't burn a number until upload succeeds, so cancelling is
    // free.
    String? suggestion;
    if (_titleCtrl.text.trim().isEmpty) {
      final next = await VideoNumberSequence.peek();
      suggestion = VideoNumberSequence.format(next);
    }
    if (!mounted) return;
    setState(() {
      _picked = File(picked.path);
      _thumbnailPath = null;
      _generatingThumb = true;
      if (suggestion != null) _titleCtrl.text = suggestion;
    });
    // Best-effort thumbnail generation for the in-screen preview.
    // Uses the same `video_thumbnail` package as the upload repo, but
    // a separate temp file — the repo will regenerate at upload time
    // (cheap; the alternative is plumbing the path through which adds
    // coupling we don't need).
    _generatePreviewThumbnail(picked.path);
  }

  Future<void> _generatePreviewThumbnail(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final out = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 75,
      );
      if (!mounted) return;
      setState(() {
        _thumbnailPath = out;
        _generatingThumb = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _generatingThumb = false);
    }
  }

  Future<void> _showSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Add a video'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickFromSource(ImageSource.camera);
              },
              child: const Text('Record video'),
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
              title: const Text('Record video'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.video, color: _brand),
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
    final repo = VideosRepository();
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
      CommonToasts.error(context, 'Could not upload the video');
      return;
    }
    // Advance the VID counter only on success — cancel/fail leaves
    // the next pick on the same number.
    await VideoNumberSequence.consume();
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
      title: 'Discard video?',
      message: 'You haven\'t uploaded yet.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final size = _picked == null ? 0 : (_picked!.lengthSync());
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
          title: const Text('New video'),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _picked == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.videotape,
                                    size: 32,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to choose a video',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _PickedVideoPreview(
                              thumbnailPath: _thumbnailPath,
                              generating: _generatingThumb,
                              sizeLabel: _fmtSize(size),
                            ),
                    ),
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

/// Preview pane shown after the user picks a video. Renders the
/// extracted first-frame poster cover-fit, with a centred play badge
/// and a size pill in the bottom-right. While the thumbnail is being
/// generated the layout shows a subtle loading spinner so the screen
/// doesn't visibly jump when the poster lands.
class _PickedVideoPreview extends StatelessWidget {
  const _PickedVideoPreview({
    required this.thumbnailPath,
    required this.generating,
    required this.sizeLabel,
  });

  final String? thumbnailPath;
  final bool generating;
  final String sizeLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailPath != null)
          Image.file(File(thumbnailPath!), fit: BoxFit.cover)
        else
          Container(color: Colors.grey.shade100),

        if (generating && thumbnailPath == null)
          Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey.shade500,
              ),
            ),
          ),

        if (thumbnailPath != null)
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.play,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),

        if (sizeLabel.isNotEmpty)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                sizeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
