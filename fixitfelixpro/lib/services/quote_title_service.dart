import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Generates a short, professional quote title from the picked
/// services/materials by calling OpenRouter. Returns `null` when the
/// API key is missing or the call fails — callers should have a local
/// fallback title.
class QuoteTitleService {
  static const _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const _model = 'qwen/qwen3.5-flash-02-23';

  Future<String?> generate({
    required List<String> itemNames,
    String? customerName,
  }) async {
    final key = dotenv.env['OPENROUTER_API_KEY']?.trim();
    if (key == null || key.isEmpty) return null;
    if (itemNames.isEmpty) return null;

    final itemList = itemNames.map((n) => '- $n').join('\n');
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content':
              'You write quote titles for a UK tradesman job-management '
                  'app. Reply with the title only — no surrounding quotes, '
                  'no period, 3 to 6 words, Title Case.',
        },
        {
          'role': 'user',
          'content':
              'Generate a concise title for a quote with these items.\n'
                  'Customer: ${customerName ?? '—'}\n'
                  'Items:\n$itemList',
        },
      ],
      'max_tokens': 30,
      'temperature': 0.4,
    });

    try {
      final resp = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://fixitfelixsoftwaresolutions.com',
              'X-Title': 'Fix It Felix Pro',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        debugPrint(
          'QuoteTitleService HTTP ${resp.statusCode}: ${resp.body}',
        );
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      final msg = first['message'];
      if (msg is! Map) return null;
      final raw = msg['content']?.toString().trim();
      if (raw == null || raw.isEmpty) return null;

      // Strip surrounding quotes / trailing punctuation that some
      // models include in spite of the instructions.
      final cleaned = raw
          .replaceAll(RegExp(r'^["“‘]+|["”’.]+$'), '')
          .trim();
      return cleaned.isEmpty ? null : cleaned;
    } catch (e) {
      debugPrint('QuoteTitleService failed: $e');
      return null;
    }
  }
}
