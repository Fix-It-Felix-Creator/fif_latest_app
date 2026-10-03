import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/app_config_store.dart';
import '../../models/config/image_limits_config_model.dart';

// Re-export for backward compatibility
export '../../models/config/image_limits_config_model.dart';

/// Utility class for validating image files before upload.
/// Fetches size limits from Firebase Realtime Database.
class ImageValidator {
  static ImageLimitsConfigModel? _cachedLimits;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Allowed file extensions
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocumentExtensions = ['pdf'];
  static const List<String> allowedExtraDocumentExtensions = [
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ];

  /// Initialize and fetch limits from Firebase
  static Future<void> initialize() async {
    await _fetchLimits();
  }

  /// Get current limits (fetches if not cached or expired)
  static Future<ImageLimitsConfigModel> getLimits() async {
    if (_shouldRefreshCache()) {
      await _fetchLimits();
    }
    return _cachedLimits ?? const ImageLimitsConfigModel();
  }

  /// Force refresh limits from Firebase
  static Future<void> refreshLimits() async {
    await _fetchLimits();
  }

  static bool _shouldRefreshCache() {
    if (_cachedLimits == null || _lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheDuration;
  }

  static Future<void> _fetchLimits() async {
    try {
      // Was RTDB `config/imageLimits`; now the `imageLimits` key in
      // app_config, which is publicly readable so limits are available
      // before sign-in.
      await AppConfigStore().load();
      final data = AppConfigStore().map('imageLimits');

      if (data != null && data.isNotEmpty) {
        _cachedLimits = ImageLimitsConfigModel.fromJson(data);
        _lastFetchTime = DateTime.now();
        debugPrint('ImageValidator: Loaded limits from app_config');
      } else {
        _cachedLimits = const ImageLimitsConfigModel();
        _lastFetchTime = DateTime.now();
        debugPrint('ImageValidator: Using default limits (no config in DB)');
      }
    } catch (e) {
      debugPrint('ImageValidator: Error fetching limits: $e');
      _cachedLimits ??= const ImageLimitsConfigModel();
    }
  }

  /// Get current limits synchronously (returns cached or defaults)
  static ImageLimitsConfigModel get limits =>
      _cachedLimits ?? const ImageLimitsConfigModel();

  /// Validates profile image file size.
  /// Returns null if valid, error message if invalid.
  static Future<String?> validateProfileImage(File file) async {
    final config = await getLimits();
    return _validateFileSize(
      file,
      config.profileImage.maxSizeBytes,
      config.profileImage.maxSizeMB,
      'Profile image',
    );
  }

  /// Validates identity document (passport, ID card, driver license) file size.
  /// Returns null if valid, error message if invalid.
  static Future<String?> validateIdentityDocument(File file) async {
    final config = await getLimits();
    return _validateFileSize(
      file,
      config.identityDocument.maxSizeBytes,
      config.identityDocument.maxSizeMB,
      'Document image',
    );
  }

  /// Validates selfie image file size.
  /// Returns null if valid, error message if invalid.
  static Future<String?> validateSelfie(File file) async {
    final config = await getLimits();
    return _validateFileSize(
      file,
      config.selfie.maxSizeBytes,
      config.selfie.maxSizeMB,
      'Selfie',
    );
  }

  /// Validates logo image file size.
  /// Returns null if valid, error message if invalid.
  static Future<String?> validateLogo(File file) async {
    final config = await getLimits();
    return _validateFileSize(
      file,
      config.logo.maxSizeBytes,
      config.logo.maxSizeMB,
      'Logo',
    );
  }

  /// Validates logo image from bytes.
  /// Returns null if valid, error message if invalid.
  static Future<String?> validateLogoBytes(List<int> bytes) async {
    final config = await getLimits();
    if (bytes.length > config.logo.maxSizeBytes) {
      final sizeMB = bytes.length / (1024 * 1024);
      return 'Logo size (${sizeMB.toStringAsFixed(1)} MB) exceeds the maximum '
          'allowed size of ${config.logo.maxSizeMB.toStringAsFixed(0)} MB. '
          'Please choose a smaller image.';
    }
    return null;
  }

  /// Validates extra document (certificate, license, etc.) file size.
  /// Returns null if valid, error message if invalid.
  static Future<String?> validateExtraDocument(File file) async {
    final config = await getLimits();
    return _validateFileSize(
      file,
      config.extraDocument.maxSizeBytes,
      config.extraDocument.maxSizeMB,
      'Document',
    );
  }

  /// Validates extra document file extension.
  /// Returns null if valid, error message if invalid.
  static String? validateExtraDocumentExtension(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    if (!allowedExtraDocumentExtensions.contains(extension)) {
      return 'Invalid file type. Allowed types: ${allowedExtraDocumentExtensions.join(', ')}';
    }
    return null;
  }

  /// Get file extension from path.
  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Check if file is an image.
  static bool isImageFile(String filePath) {
    final extension = getFileExtension(filePath);
    return allowedImageExtensions.contains(extension);
  }

  /// Check if file is a PDF.
  static bool isPdfFile(String filePath) {
    final extension = getFileExtension(filePath);
    return extension == 'pdf';
  }

  /// Generic file size validation helper.
  static Future<String?> _validateFileSize(
    File file,
    int maxSizeBytes,
    double maxSizeMB,
    String imageType,
  ) async {
    try {
      final fileSize = await file.length();
      if (fileSize > maxSizeBytes) {
        final sizeMB = fileSize / (1024 * 1024);
        return '$imageType size (${sizeMB.toStringAsFixed(1)} MB) exceeds the '
            'maximum allowed size of ${maxSizeMB.toStringAsFixed(0)} MB. '
            'Please choose a smaller image.';
      }
      return null;
    } catch (e) {
      return 'Failed to read file size. Please try again.';
    }
  }

  /// Get formatted file size string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get file size in MB.
  static double getFileSizeInMB(int bytes) {
    return bytes / (1024 * 1024);
  }

  /// Get max size in MB for display (profile image)
  static Future<double> get profileImageMaxSizeMB async {
    final config = await getLimits();
    return config.profileImage.maxSizeMB;
  }

  /// Get max size in MB for display (identity document)
  static Future<double> get identityDocumentMaxSizeMB async {
    final config = await getLimits();
    return config.identityDocument.maxSizeMB;
  }

  /// Get max size in MB for display (selfie)
  static Future<double> get selfieMaxSizeMB async {
    final config = await getLimits();
    return config.selfie.maxSizeMB;
  }

  /// Get max size in MB for display (logo)
  static Future<double> get logoMaxSizeMB async {
    final config = await getLimits();
    return config.logo.maxSizeMB;
  }

  /// Get max size in MB for display (extra document)
  static Future<double> get extraDocumentMaxSizeMB async {
    final config = await getLimits();
    return config.extraDocument.maxSizeMB;
  }
}
