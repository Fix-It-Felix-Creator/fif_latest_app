import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'image_validator.dart';

/// Result of a smart compression attempt.
class CompressionResult {
  final File file;
  final bool wasCompressed;
  final int originalSize;
  final int finalSize;

  const CompressionResult({
    required this.file,
    required this.wasCompressed,
    required this.originalSize,
    required this.finalSize,
  });

  double get reductionPercent =>
      originalSize > 0 ? (1 - finalSize / originalSize) * 100 : 0;
}

/// Result of a smart compression attempt on raw bytes.
class BytesCompressionResult {
  final Uint8List bytes;
  final bool wasCompressed;
  final int originalSize;
  final int finalSize;

  const BytesCompressionResult({
    required this.bytes,
    required this.wasCompressed,
    required this.originalSize,
    required this.finalSize,
  });
}

/// A single compression phase: quality level + resolution scale factor.
class _CompressionPhase {
  final int quality;

  /// 1.0 = original dimensions, 0.75 = 75%, 0.5 = 50%.
  final double resolutionScale;

  const _CompressionPhase(this.quality, this.resolutionScale);
}

/// Smart image compressor that only compresses images exceeding size limits.
///
/// Uses progressive compression: tries gentle compression first, then
/// gradually increases aggressiveness until the image fits within limits.
/// Integrates with [ImageValidator] for size limits per image type.
class ImageCompressor {
  /// Compress a file only if it exceeds the size limit for [imageType].
  ///
  /// [imageType] matches keys in [ImageLimitsConfigModel.getLimitByType]:
  /// 'profile', 'job', 'logo', 'identity', 'selfie', 'portfolio', 'chat', etc.
  ///
  /// Returns [CompressionResult] on success, or `null` if the image
  /// cannot be compressed to fit within the limit.
  static Future<CompressionResult?> compressIfNeeded(
    File file,
    String imageType,
  ) async {
    final limits = await ImageValidator.getLimits();
    final config = limits.getLimitByType(imageType);
    final originalSize = await file.length();

    // Already within limit — skip compression entirely
    if (config.isFileSizeWithinLimit(originalSize)) {
      return CompressionResult(
        file: file,
        wasCompressed: false,
        originalSize: originalSize,
        finalSize: originalSize,
      );
    }

    debugPrint(
      'ImageCompressor: File ${_formatBytes(originalSize)} exceeds '
      '${config.formattedMaxSize} limit for $imageType — compressing...',
    );

    // Decode image to get original dimensions
    final originalBytes = await file.readAsBytes();
    final dimensions = await _getImageDimensions(originalBytes);
    final origWidth = dimensions.$1;
    final origHeight = dimensions.$2;

    // Try each phase until it fits
    for (final phase in _compressionPhases) {
      final targetWidth = (origWidth * phase.resolutionScale).round();
      final targetHeight = (origHeight * phase.resolutionScale).round();

      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: phase.quality,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) continue;

      if (config.isFileSizeWithinLimit(compressed.length)) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(compressed);

        debugPrint(
          'ImageCompressor: Compressed to ${_formatBytes(compressed.length)} '
          '(q${phase.quality}, ${(phase.resolutionScale * 100).toInt()}% res, '
          '-${((1 - compressed.length / originalSize) * 100).toStringAsFixed(0)}%)',
        );

        return CompressionResult(
          file: tempFile,
          wasCompressed: true,
          originalSize: originalSize,
          finalSize: compressed.length,
        );
      }
    }

    debugPrint(
      'ImageCompressor: Could not compress ${_formatBytes(originalSize)} '
      'to within ${config.formattedMaxSize} limit.',
    );
    return null;
  }

  /// Compress bytes only if they exceed the size limit for [imageType].
  ///
  /// Used for bytes-based flows (e.g., logo cropper).
  /// Returns [BytesCompressionResult] on success, or `null` if the bytes
  /// cannot be compressed to fit within the limit.
  static Future<BytesCompressionResult?> compressBytesIfNeeded(
    Uint8List bytes,
    String imageType,
  ) async {
    final limits = await ImageValidator.getLimits();
    final config = limits.getLimitByType(imageType);

    // Already within limit
    if (config.isFileSizeWithinLimit(bytes.length)) {
      return BytesCompressionResult(
        bytes: bytes,
        wasCompressed: false,
        originalSize: bytes.length,
        finalSize: bytes.length,
      );
    }

    debugPrint(
      'ImageCompressor: Bytes ${_formatBytes(bytes.length)} exceeds '
      '${config.formattedMaxSize} limit for $imageType — compressing...',
    );

    final dimensions = await _getImageDimensions(bytes);
    final origWidth = dimensions.$1;
    final origHeight = dimensions.$2;

    for (final phase in _compressionPhases) {
      final targetWidth = (origWidth * phase.resolutionScale).round();
      final targetHeight = (origHeight * phase.resolutionScale).round();

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: phase.quality,
        format: CompressFormat.jpeg,
      );

      if (config.isFileSizeWithinLimit(compressed.length)) {
        debugPrint(
          'ImageCompressor: Compressed bytes to ${_formatBytes(compressed.length)} '
          '(q${phase.quality}, ${(phase.resolutionScale * 100).toInt()}% res)',
        );

        return BytesCompressionResult(
          bytes: Uint8List.fromList(compressed),
          wasCompressed: true,
          originalSize: bytes.length,
          finalSize: compressed.length,
        );
      }
    }

    debugPrint(
      'ImageCompressor: Could not compress bytes ${_formatBytes(bytes.length)} '
      'to within ${config.formattedMaxSize} limit.',
    );
    return null;
  }

  /// Decode image bytes to get (width, height).
  /// Falls back to 1920x1920 if decoding fails.
  static Future<(int, int)> _getImageDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return (width, height);
    } catch (e) {
      debugPrint('ImageCompressor: Could not decode dimensions: $e');
      return (1920, 1920);
    }
  }

  /// Progressive compression phases — ordered from least to most aggressive.
  ///
  /// Strategy:
  /// - Phase 1: Quality reduction only (preserves original resolution)
  /// - Phase 2: Quality reduction + 75% resolution
  /// - Phase 3: Quality reduction + 50% resolution
  /// - Phase 4: Last resort — heavy quality + 50% resolution
  static const _compressionPhases = [
    // Phase 1: Quality reduction only (original resolution)
    _CompressionPhase(90, 1.0),
    _CompressionPhase(70, 1.0),
    _CompressionPhase(50, 1.0),
    // Phase 2: Quality reduction + 75% resolution
    _CompressionPhase(90, 0.75),
    _CompressionPhase(70, 0.75),
    _CompressionPhase(50, 0.75),
    // Phase 3: Quality reduction + 50% resolution
    _CompressionPhase(90, 0.5),
    _CompressionPhase(70, 0.5),
    _CompressionPhase(50, 0.5),
    // Phase 4: Last resort
    _CompressionPhase(30, 0.5),
  ];

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
