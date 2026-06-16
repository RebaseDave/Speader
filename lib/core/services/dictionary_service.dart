import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class DictionaryService {
  static const _maxTokens = 350;
  static const _systemPrompt =
      'Du bist ein präzises deutsches Wörterbuch. '
      'Antworte ausschließlich mit der Definition in 2-3 Sätzen, '
      'ohne Einleitung oder Kommentar, immer auf Deutsch.';

  static final Map<String, DateTime> _lastCallTimes = {};

  static Future<DictionaryResult> lookup(String word, {String? sentence}) async {
    if (word.length < 2) return DictionaryResult.notFound();

    final apiKey = SettingsService.instance.claudeApiKey;
    if (apiKey.isEmpty) return DictionaryResult.noKey();

    // Cooldown: gleiches Wort nicht öfter als alle 5 Sekunden
    final normalized = word.toLowerCase();
    final lastCall = _lastCallTimes[normalized];
    if (lastCall != null) {
      final diff = DateTime.now().difference(lastCall).inSeconds;
      if (diff < 5) return DictionaryResult.rateLimit();
    }
    _lastCallTimes[normalized] = DateTime.now();

    try {
      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'max_tokens': _maxTokens,
              'system': _systemPrompt,
              'messages': [
                {
                  'role': 'user',
                  'content': sentence != null && sentence.isNotEmpty
                      ? 'Definiere das Wort „$word" im folgenden Kontext: „$sentence"'
                      : 'Definiere: $word',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = (data['content'] as List)
            .whereType<Map>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join();
        if (text.trim().isNotEmpty) return DictionaryResult.found(text.trim());
      } else if (response.statusCode == 401) {
        return DictionaryResult.invalidKey();
      } else if (response.statusCode == 429) {
        return DictionaryResult.rateLimit();
      }
      return DictionaryResult.notFound();
    } on SocketException {
      return DictionaryResult.noInternet();
    } on Exception {
      return DictionaryResult.notFound();
    }
  }
}

enum DictionaryStatus {
  found,
  notFound,
  noInternet,
  noKey,
  invalidKey,
  rateLimit,
}

class DictionaryResult {
  final DictionaryStatus status;
  final String? definition;

  DictionaryResult._({required this.status, this.definition});

  factory DictionaryResult.found(String definition) => DictionaryResult._(
    status: DictionaryStatus.found,
    definition: definition,
  );
  factory DictionaryResult.notFound() =>
      DictionaryResult._(status: DictionaryStatus.notFound);
  factory DictionaryResult.noInternet() =>
      DictionaryResult._(status: DictionaryStatus.noInternet);
  factory DictionaryResult.noKey() =>
      DictionaryResult._(status: DictionaryStatus.noKey);
  factory DictionaryResult.invalidKey() =>
      DictionaryResult._(status: DictionaryStatus.invalidKey);
  factory DictionaryResult.rateLimit() =>
      DictionaryResult._(status: DictionaryStatus.rateLimit);
}
