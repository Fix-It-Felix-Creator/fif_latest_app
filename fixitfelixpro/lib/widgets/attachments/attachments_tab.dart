import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/tools/tool_file.dart';
import '../../models/tools/tool_photo.dart';
import '../../models/tools/tool_video.dart';

const _brand = Color(0xFFF64C13);

/// Attachment tab body shared by quote + invoice screens. Renders the
/// already-attached photo / video / file snapshots in three sections,
/// each with its own "Add" button that opens the corresponding picker.
class AttachmentsTab extends StatelessWidget {
  const AttachmentsTab({
    super.key,
    required this.photos,
    required this.videos,
    required this.files,
    required this.readOnly,
    required this.onAddPhotos,
    required this.onAddVideos,
    required this.onAddFiles,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
    required this.onRemoveFile,
  });

  final List<ToolPhoto> photos;
  final List<ToolVideo> videos;
  final List<ToolFile> files;
  final bool readOnly;
  final VoidCallback onAddPhotos;
  final VoidCallback onAddVideos;
  final VoidCallback onAddFiles;
  final ValueChanged<String> onRemovePhoto;
  final ValueChanged<String> onRemoveVideo;
  final ValueChanged<String> onRemoveFile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        _PhotosSection(
          photos: photos,
          readOnly: readOnly,
          onAdd: onAddPhotos,
          onRemove: onRemovePhoto,
        ),
        const SizedBox(height: 18),
        _VideosSection(
          videos: videos,
          readOnly: readOnly,
          onAdd: onAddVideos,
          onRemove: onRemoveVideo,
        ),
        const SizedBox(height: 18),
        _FilesSection(
          files: files,
          readOnly: readOnly,
          onAdd: onAddFiles,
          onRemove: onRemoveFile,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    required this.readOnly,
    required this.onAdd,
  });

  final String title;
  final IconData icon;
  final int count;
  final bool readOnly;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _brand),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const Spacer(),
        if (!readOnly)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 16, color: _brand),
            label: const Text(
              'Add',
              style: TextStyle(
                color: _brand,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.photos,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ToolPhoto> photos;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Photos',
          icon: LucideIcons.image,
          count: photos.length,
          readOnly: readOnly,
          onAdd: onAdd,
        ),
        const SizedBox(height: 8),
        if (photos.isEmpty)
          const _EmptyHint(
            label: 'Attach photos from your Tools section.',
            icon: LucideIcons.image,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: photos.length,
            itemBuilder: (_, i) {
              final p = photos[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: p.url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        LucideIcons.imageOff,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (!readOnly)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _RemoveBadge(onTap: () => onRemove(p.id)),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _VideosSection extends StatelessWidget {
  const _VideosSection({
    required this.videos,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ToolVideo> videos;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Videos',
          icon: LucideIcons.video,
          count: videos.length,
          readOnly: readOnly,
          onAdd: onAdd,
        ),
        const SizedBox(height: 8),
        if (videos.isEmpty)
          const _EmptyHint(
            label: 'Attach videos from your Tools section.',
            icon: LucideIcons.video,
          )
        else
          Column(
            children: [
              for (final v in videos) ...[
                _VideoRow(
                  video: v,
                  readOnly: readOnly,
                  onRemove: () => onRemove(v.id),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.video,
    required this.readOnly,
    required this.onRemove,
  });

  final ToolVideo video;
  final bool readOnly;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 76,
              height: 52,
              child: video.thumbnailUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        const Center(
                          child: Icon(
                            LucideIcons.play,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Icon(
                          LucideIcons.play,
                          color: Colors.grey.shade700,
                        ),
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
                  video.title.isEmpty ? 'Untitled' : video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (video.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    video.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!readOnly) ...[
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: Icon(LucideIcons.x, size: 18, color: Colors.grey.shade500),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilesSection extends StatelessWidget {
  const _FilesSection({
    required this.files,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ToolFile> files;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  IconData _iconFor(ToolFile f) {
    switch (f.family) {
      case 'pdf':
        return LucideIcons.fileText;
      case 'image':
        return LucideIcons.fileImage;
      case 'doc':
        return LucideIcons.fileText;
      case 'sheet':
        return LucideIcons.fileSpreadsheet;
      case 'archive':
        return LucideIcons.fileArchive;
      default:
        return LucideIcons.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Files',
          icon: LucideIcons.fileText,
          count: files.length,
          readOnly: readOnly,
          onAdd: onAdd,
        ),
        const SizedBox(height: 8),
        if (files.isEmpty)
          const _EmptyHint(
            label: 'Attach files from your Tools section.',
            icon: LucideIcons.fileText,
          )
        else
          Column(
            children: [
              for (final f in files) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF14B8A6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconFor(f),
                          color: const Color(0xFF14B8A6),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.title.isEmpty ? f.fileName : f.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!readOnly) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            LucideIcons.x,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: () => onRemove(f.id),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.6),
        ),
        child: const Icon(LucideIcons.x, color: Colors.white, size: 14),
      ),
    );
  }
}
