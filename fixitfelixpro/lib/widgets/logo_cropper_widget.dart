import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/utils/image_validator.dart';

/// A widget that allows users to pick, zoom, and crop a logo image
/// within a fixed-size box. Returns cropped bytes for later upload.
class LogoCropperWidget extends StatefulWidget {
  /// The fixed width of the crop box
  final double boxWidth;

  /// The fixed height of the crop box
  final double boxHeight;

  /// Initial logo URL (if editing existing template)
  final String? initialLogoUrl;

  /// Callback when logo is cropped and ready (returns bytes for upload)
  final ValueChanged<Uint8List?> onLogoCropped;

  const LogoCropperWidget({
    super.key,
    this.boxWidth = 200,
    this.boxHeight = 60,
    this.initialLogoUrl,
    required this.onLogoCropped,
  });

  @override
  State<LogoCropperWidget> createState() => LogoCropperWidgetState();
}

class LogoCropperWidgetState extends State<LogoCropperWidget> {
  final GlobalKey _cropKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _currentLogoUrl;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;

  // Track image dimensions for proper scaling
  Size? _imageSize;
  bool _isLoading = false;
  bool _hasLocalImage = false;

  @override
  void initState() {
    super.initState();
    _currentLogoUrl = widget.initialLogoUrl;
    if (widget.initialLogoUrl != null && widget.initialLogoUrl!.isNotEmpty) {
      _loadInitialImage();
    }
  }

  Future<void> _loadInitialImage() async {
    if (_currentLogoUrl == null || _currentLogoUrl!.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Load image from URL
      final networkImage = NetworkImage(_currentLogoUrl!);
      final imageStream = networkImage.resolve(ImageConfiguration.empty);

      imageStream.addListener(
        ImageStreamListener(
          (info, _) async {
            final codec = await ui.instantiateImageCodec(
              (await info.image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
            final frame = await codec.getNextFrame();

            if (mounted) {
              setState(() {
                _imageSize = Size(
                  frame.image.width.toDouble(),
                  frame.image.height.toDouble(),
                );
                _calculateInitialScale();
                _isLoading = false;
              });
            }
          },
          onError: (_, __) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading initial image: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateInitialScale() {
    if (_imageSize == null) return;

    // Calculate scale to fit image in box (cover mode)
    final widthRatio = widget.boxWidth / _imageSize!.width;
    final heightRatio = widget.boxHeight / _imageSize!.height;
    _scale = widthRatio > heightRatio ? widthRatio : heightRatio;
    _baseScale = _scale;
    _offset = Offset.zero;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        final bytes = await pickedFile.readAsBytes();

        // Validate file size
        final validationError = await ImageValidator.validateLogoBytes(bytes);

        if (validationError != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast.destructive(
                title: const Text('Image Too Large'),
                description: Text(validationError),
              ),
            );
          }
          return;
        }

        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();

        setState(() {
          _imageBytes = bytes;
          _imageSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
          _calculateInitialScale();
          _isLoading = false;
          _hasLocalImage = true;
        });

        // Wait for render then capture cropped bytes
        await Future.delayed(const Duration(milliseconds: 300));
        await _captureCroppedBytes();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error picking image: $e');
    }
  }

  /// Capture the cropped image bytes from the RepaintBoundary
  Future<Uint8List?> _captureCroppedBytes() async {
    if (_imageBytes == null) return null;

    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('LogoCropper: boundary is null, cannot capture');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('LogoCropper: byteData is null');
        return null;
      }

      final croppedBytes = byteData.buffer.asUint8List();

      // Notify parent with cropped bytes
      widget.onLogoCropped(croppedBytes);

      return croppedBytes;
    } catch (e) {
      debugPrint('Error capturing cropped image: $e');
      return null;
    }
  }

  /// Public method to get cropped bytes for upload
  Future<Uint8List?> getCroppedBytes() async {
    if (!_hasLocalImage || _imageBytes == null) return null;
    return _captureCroppedBytes();
  }

  /// Check if there's a new local image to upload
  bool get hasLocalImage => _hasLocalImage;

  /// Get current logo URL (for existing logos)
  String? get currentLogoUrl => _currentLogoUrl;

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageSize = null;
      _currentLogoUrl = null;
      _scale = 1.0;
      _offset = Offset.zero;
      _hasLocalImage = false;
    });

    widget.onLogoCropped(null);
  }

  void _zoomIn() {
    setState(() {
      _scale = (_scale * 1.2).clamp(0.5, 5.0);
    });
    // Re-capture after zoom
    if (_hasLocalImage) {
      Future.delayed(const Duration(milliseconds: 100), _captureCroppedBytes);
    }
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale / 1.2).clamp(0.5, 5.0);
    });
    // Re-capture after zoom
    if (_hasLocalImage) {
      Future.delayed(const Duration(milliseconds: 100), _captureCroppedBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final hasImage = _imageBytes != null || _currentLogoUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company Logo',
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        // Crop Box
        Container(
          width: widget.boxWidth,
          height: widget.boxHeight,
          decoration: BoxDecoration(
            color: colorScheme.secondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.border, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _imageBytes != null
                ? _buildCropArea()
                : _currentLogoUrl != null
                ? _buildUrlImage()
                : _buildPlaceholder(colorScheme, theme),
          ),
        ),
        const SizedBox(height: 12),
        // Controls
        Row(
          children: [
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: _pickImage,
              leading: Icon(
                hasImage ? LucideIcons.refreshCw : LucideIcons.image,
                size: 14,
              ),
              child: Text(hasImage ? 'Change' : 'Upload'),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: _zoomOut,
                child: const Icon(LucideIcons.zoomOut, size: 16),
              ),
              const SizedBox(width: 4),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: _zoomIn,
                child: const Icon(LucideIcons.zoomIn, size: 16),
              ),
              const SizedBox(width: 8),
              ShadButton.destructive(
                size: ShadButtonSize.sm,
                onPressed: _removeImage,
                child: const Icon(LucideIcons.trash2, size: 14),
              ),
            ],
          ],
        ),
        if (hasImage) ...[
          const SizedBox(height: 4),
          Text(
            'Drag image to position, pinch or use buttons to zoom',
            style: theme.textTheme.small.copyWith(
              fontSize: 11,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholder(ShadColorScheme colorScheme, ShadThemeData theme) {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.image,
              size: 24,
              color: colorScheme.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add logo',
              style: theme.textTheme.small.copyWith(
                fontSize: 11,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlImage() {
    return GestureDetector(
      onScaleStart: (details) {
        _baseScale = _scale;
        _baseOffset = _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_baseScale * details.scale).clamp(0.5, 5.0);
          _offset = _baseOffset + details.focalPointDelta;

          // Clamp offset
          final maxOffsetX = widget.boxWidth / 2 + 50;
          final maxOffsetY = widget.boxHeight / 2 + 50;
          _offset = Offset(
            _offset.dx.clamp(-maxOffsetX, maxOffsetX),
            _offset.dy.clamp(-maxOffsetY, maxOffsetY),
          );
        });
      },
      child: Container(
        width: widget.boxWidth,
        height: widget.boxHeight,
        color: Colors.white,
        child: ClipRect(
          child: Transform.translate(
            offset: _offset,
            child: Transform.scale(
              scale: _scale,
              child: CachedNetworkImage(
                imageUrl: _currentLogoUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    const Icon(LucideIcons.imageOff),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropArea() {
    return RepaintBoundary(
      key: _cropKey,
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _scale;
          _baseOffset = _offset;
        },
        onScaleUpdate: (details) {
          setState(() {
            // Handle pinch zoom
            _scale = (_baseScale * details.scale).clamp(0.5, 5.0);

            // Handle pan/drag
            _offset = _baseOffset + details.focalPointDelta;

            // Clamp offset to keep image within reasonable bounds
            if (_imageSize != null) {
              final scaledWidth = _imageSize!.width * _scale;
              final scaledHeight = _imageSize!.height * _scale;
              final maxOffsetX = (scaledWidth - widget.boxWidth) / 2 + 50;
              final maxOffsetY = (scaledHeight - widget.boxHeight) / 2 + 50;
              _offset = Offset(
                _offset.dx.clamp(-maxOffsetX, maxOffsetX),
                _offset.dy.clamp(-maxOffsetY, maxOffsetY),
              );
            }
          });
        },
        onScaleEnd: (_) {
          // Re-capture after drag/zoom ends
          if (_hasLocalImage) {
            Future.delayed(
              const Duration(milliseconds: 100),
              _captureCroppedBytes,
            );
          }
        },
        child: Container(
          width: widget.boxWidth,
          height: widget.boxHeight,
          color: Colors.white,
          child: ClipRect(
            child: Transform.translate(
              offset: _offset,
              child: Transform.scale(
                scale: _scale,
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
