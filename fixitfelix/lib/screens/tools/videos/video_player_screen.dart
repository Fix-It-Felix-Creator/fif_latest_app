import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:video_player/video_player.dart';

import '../../../blocs/tools/videos/videos_bloc.dart';
import '../../../core/utils/common_dialogs.dart';
import '../../../models/tools/tool_video.dart';

class VideoPlayerArgs {
  const VideoPlayerArgs({
    required this.videos,
    required this.initialIndex,
  });

  final List<ToolVideo> videos;
  final int initialIndex;
}

/// Full-screen video player with horizontal swipe between videos.
/// One [VideoPlayerController] is initialised per visible page; the
/// previous controller is paused on swipe so we don't drain the
/// network or play two clips at once. The chrome (AppBar + caption)
/// hides on tap.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  final List<ToolVideo> videos;
  final int initialIndex;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController _pageCtrl;
  late int _index;
  bool _chromeVisible = true;

  /// One controller per index, lazily built. Letting `video_player`
  /// hold a controller per page would balloon memory; we only
  /// initialise on demand.
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageCtrl = PageController(initialPage: _index);
    _ensureController(_index, autoPlay: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _ensureController(int i, {bool autoPlay = false}) async {
    if (i < 0 || i >= widget.videos.length) return;
    if (_controllers.containsKey(i)) return;
    final v = widget.videos[i];
    final c = VideoPlayerController.networkUrl(Uri.parse(v.url));
    _controllers[i] = c;
    try {
      await c.initialize();
      if (!mounted) return;
      setState(() {});
      if (autoPlay && _index == i) {
        c.play();
      }
    } catch (_) {
      // Surface as a centred error placeholder; nothing else useful
      // we can do at this point.
      if (mounted) setState(() {});
    }
  }

  void _onPageChanged(int i) {
    final prev = _controllers[_index];
    prev?.pause();
    setState(() => _index = i);
    _ensureController(i, autoPlay: true);
    // Pre-warm neighbouring page so the next swipe is instant.
    _ensureController(i + 1);
    _ensureController(i - 1);
  }

  void _togglePlay() {
    final c = _controllers[_index];
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  Future<void> _confirmDelete(ToolVideo video) async {
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete video?',
      message: 'This will remove the video permanently.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed || !mounted) return;
    context.read<VideosBloc>().add(VideoDeleteRequested(video));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.videos;
    if (videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No videos', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final current = videos[_index.clamp(0, videos.length - 1)];
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
                '${_index + 1} of ${videos.length}',
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
              itemCount: videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) {
                final c = _controllers[i];
                if (c == null || !c.value.isInitialized) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return Center(
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                );
              },
            ),

            // Tap-anywhere → toggle play/pause when chrome is visible
            // and the controller is ready. Tap also toggles chrome
            // (handled by the parent GestureDetector) — both behaviors
            // coexist.
            if (_chromeVisible &&
                _controllers[_index]?.value.isInitialized == true)
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controllers[_index]!.value.isPlaying
                          ? LucideIcons.pause
                          : LucideIcons.play,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
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
