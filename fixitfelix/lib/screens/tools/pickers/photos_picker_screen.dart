import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/tools/photos/photos_bloc.dart';
import '../../../blocs/tools/photos/photos_event.dart';
import '../../../blocs/tools/photos/photos_state.dart';
import '../../../models/tools/tool_photo.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Multi-select picker over the user's existing Photos tool. Pop
/// returns the chosen [ToolPhoto] snapshots — caller is responsible
/// for embedding them onto the quote/invoice.
class PhotosPickerScreen extends StatefulWidget {
  const PhotosPickerScreen({
    super.key,
    this.initialSelectedIds = const {},
    this.singleSelect = false,
    this.title,
  });

  /// Photos already attached on the parent quote/invoice — pre-tick
  /// them so the user can deselect.
  final Set<String> initialSelectedIds;

  /// When true, picking one photo immediately pops the screen with
  /// that single selection — no checkboxes, no confirm bar. Used by
  /// flows where exactly one photo is needed (e.g. an expense
  /// receipt).
  final bool singleSelect;

  /// AppBar title override. Defaults to "Attach photos".
  final String? title;

  @override
  State<PhotosPickerScreen> createState() => _PhotosPickerScreenState();
}

class _PhotosPickerScreenState extends State<PhotosPickerScreen> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelectedIds};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PhotosBloc>().add(const PhotosStartWatching());
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _pickSingle(ToolPhoto photo) {
    Navigator.of(context).pop<List<ToolPhoto>>([photo]);
  }

  Future<void> _addNew() async {
    await Navigator.of(context).pushNamed('/tools/photos/upload');
  }

  void _confirm(List<ToolPhoto> all) {
    final picked = all.where((p) => _selected.contains(p.id)).toList();
    Navigator.of(context).pop<List<ToolPhoto>>(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title ?? 'Attach photos'),
        actions: [
          IconButton(
            tooltip: 'Upload new',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _addNew,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<PhotosBloc, PhotosState>(
        builder: (context, state) {
          if (state.status == PhotosStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (state.items.isEmpty) {
            return _EmptyState(onTap: _addNew);
          }
          return Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    8,
                    8,
                    widget.singleSelect ? 12 : 92,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: state.items.length,
                  itemBuilder: (_, i) {
                    final p = state.items[i];
                    final isPicked = _selected.contains(p.id);
                    return _PhotoTile(
                      photo: p,
                      // In single-select mode there's no per-tile
                      // checkmark — every tap just confirms.
                      selected: widget.singleSelect ? false : isPicked,
                      onTap: () {
                        if (widget.singleSelect) {
                          _pickSingle(p);
                        } else {
                          _toggle(p.id);
                        }
                      },
                    );
                  },
                ),
              ),
              if (!widget.singleSelect)
                _ConfirmBar(
                  count: _selected.length,
                  onTap: () => _confirm(state.items),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  final ToolPhoto photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: _brand, width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: photo.url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade200),
              errorWidget: (_, __, ___) => Icon(
                LucideIcons.imageOff,
                color: Colors.grey.shade500,
              ),
            ),
            if (selected)
              Container(color: _brand.withValues(alpha: 0.18)),
            Positioned(
              top: 6,
              right: 6,
              child: _CheckBadge(selected: selected),
            ),
            if (photo.title.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: Text(
                    photo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _brand : Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: selected ? _brand : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              count == 0 ? 'Done' : 'Attach ($count)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.image, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No photos yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload one to attach it',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Upload photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _brand),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
