import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;

import '../../core/config/config_service.dart';
import '../../core/services/supabase_service.dart';

/// Result from [AccountRepository.requestDeletion].
class DeletionRequestResult {
  const DeletionRequestResult({
    required this.success,
    this.deletionRequestedAt,
    this.recoveryWindowEndsAt,
    this.personalDataRetainedUntil,
    this.recoveryWaitDays,
    this.personalDataRetentionDays,
    this.subscriptionsCancelled,
    this.errorMessage,
  });

  final bool success;
  final int? deletionRequestedAt;
  final int? recoveryWindowEndsAt;
  final int? personalDataRetainedUntil;
  final int? recoveryWaitDays;
  final int? personalDataRetentionDays;
  final int? subscriptionsCancelled;
  final String? errorMessage;
}

/// Result from [AccountRepository.recoverAccount].
class RecoverAccountResult {
  const RecoverAccountResult({required this.success, this.errorMessage});
  final bool success;
  final String? errorMessage;
}

/// Result from [AccountRepository.downloadPersonalData].
class DataExportResult {
  const DataExportResult({
    required this.success,
    this.filePath,
    this.sizeBytes,
    this.errorMessage,
  });

  final bool success;
  final String? filePath;
  final int? sizeBytes;
  final String? errorMessage;
}

/// Thin wrapper around the `/account/*` backend endpoints.
class AccountRepository {
  AccountRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => ConfigService().stripeBackendUrl;

  /// Bearer token for the `/account/*` endpoints.
  ///
  /// Was a Firebase ID token; now the Supabase session access token. The
  /// endpoints move to Edge Functions in Phase 5 — this repository only ever
  /// spoke HTTP, so the base URL and shapes stay as they are.
  Future<String?> _authToken() async {
    return SupabaseService().auth.currentSession?.accessToken;
  }

  /// Headers shared by every authenticated call. Includes the `x-app-mode`
  /// hint so the backend's Stripe wrapper picks the right (test vs live)
  /// secret for any subscription/customer side-effects.
  Map<String, String> _authHeaders(String token, {bool json = true}) => {
    'Authorization': 'Bearer $token',
    if (json) 'Content-Type': 'application/json',
    'x-app-mode': ConfigService().isProduction ? 'production' : 'staging',
  };

  Future<DeletionRequestResult> requestDeletion() async {
    try {
      final token = await _authToken();
      if (token == null) {
        return const DeletionRequestResult(
          success: false,
          errorMessage: 'Not signed in',
        );
      }
      final res = await _client.post(
        Uri.parse('$_baseUrl/account/request-deletion'),
        headers: _authHeaders(token),
        body: '{}',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return DeletionRequestResult(
          success: true,
          deletionRequestedAt: (data['deletionRequestedAt'] as num?)?.toInt(),
          recoveryWindowEndsAt:
              (data['recoveryWindowEndsAt'] as num?)?.toInt(),
          personalDataRetainedUntil:
              (data['personalDataRetainedUntil'] as num?)?.toInt(),
          recoveryWaitDays: (data['recoveryWaitDays'] as num?)?.toInt(),
          personalDataRetentionDays:
              (data['personalDataRetentionDays'] as num?)?.toInt(),
          subscriptionsCancelled:
              (data['subscriptionsCancelled'] as num?)?.toInt(),
        );
      }
      final error = jsonDecode(res.body) as Map<String, dynamic>;
      return DeletionRequestResult(
        success: false,
        errorMessage:
            error['message']?.toString() ?? 'Failed to request deletion',
      );
    } catch (e) {
      debugPrint('AccountRepository.requestDeletion failed: $e');
      return DeletionRequestResult(success: false, errorMessage: '$e');
    }
  }

  Future<RecoverAccountResult> recoverAccount() async {
    try {
      final token = await _authToken();
      if (token == null) {
        return const RecoverAccountResult(
          success: false,
          errorMessage: 'Not signed in',
        );
      }
      final res = await _client.post(
        Uri.parse('$_baseUrl/account/recover'),
        headers: _authHeaders(token),
        body: '{}',
      );
      if (res.statusCode == 200) {
        return const RecoverAccountResult(success: true);
      }
      final error = jsonDecode(res.body) as Map<String, dynamic>;
      return RecoverAccountResult(
        success: false,
        errorMessage: error['message']?.toString() ?? 'Recovery failed',
      );
    } catch (e) {
      debugPrint('AccountRepository.recoverAccount failed: $e');
      return RecoverAccountResult(success: false, errorMessage: '$e');
    }
  }

  /// Download the full personal-data export as a JSON file on disk.
  /// Returns the local path to the saved file.
  Future<DataExportResult> downloadPersonalData() async {
    try {
      final token = await _authToken();
      if (token == null) {
        return const DataExportResult(
          success: false,
          errorMessage: 'Not signed in',
        );
      }
      final res = await _client.get(
        Uri.parse('$_baseUrl/account/export-data'),
        headers: _authHeaders(token, json: false),
      );
      if (res.statusCode != 200) {
        String msg = 'Download failed (HTTP ${res.statusCode})';
        try {
          final err = jsonDecode(res.body) as Map<String, dynamic>;
          msg = err['message']?.toString() ?? msg;
        } catch (_) {}
        return DataExportResult(success: false, errorMessage: msg);
      }

      // Temporary directory so the OS clears it automatically. The user's
      // copy of the data lives wherever they choose via the share sheet.
      final dir = await path_provider.getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/fixitfelix-data-$stamp.json');
      await file.writeAsBytes(res.bodyBytes, flush: true);

      return DataExportResult(
        success: true,
        filePath: file.path,
        sizeBytes: res.bodyBytes.length,
      );
    } catch (e) {
      debugPrint('AccountRepository.downloadPersonalData failed: $e');
      return DataExportResult(success: false, errorMessage: '$e');
    }
  }
}
