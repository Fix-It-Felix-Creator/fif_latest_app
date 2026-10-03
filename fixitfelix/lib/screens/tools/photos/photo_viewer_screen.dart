import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/tools/photos/photos_bloc.dart';
import '../../../blocs/tools/photos/photos_event.dart';
import '../../../core/utils/common_dialogs.dart';
import '../../../models/tools/tool_photo.dart';

class PhotoViewerArgs {
  const PhotoViewerArgs({
    required this.photos,
    required this.initialIndex,
  });

  final List<ToolPhoto> photos;
  final int initialIndex;
}

/// Full-screen photo viewer with horizontal swipe between photos
/// (PageView) and pinch-zoom on each (InteractiveViewer). Title and
/// description overlay at the bottom; tap toggles the chrome
/// (AppBar + caption) to give an unobstructed view of the image.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<ToolPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageCtrl;
  late int _index;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageCtrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(ToolPhoto photo) async {
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete photo?',
      message: 'This will remove the photo permanently.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed || !mounted) return;
    context.read<PhotosBloc>().add(PhotoDeleteRequested(photo));
    // The list shrinks under us — pop back to grid for a cleaner UX
    // than trying to re-anchor on the next/prev photo.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No photos',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final current = photos[_index.clamp(0, photos.length - 1)];
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                '${_index + 1} of ${photos.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: () => _confirmDelete(current),
                ),
                const SizedBox(width: 4),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final p = photos[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: p.url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        LucideIcons.imageOff,
                        size: 56,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_chromeVisible &&
                (current.title.isNotEmpty ||
                    current.description.isNotEmpty))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    20 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (current.title.isNotEmpty)
                        Text(
                          current.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (current.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          current.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
