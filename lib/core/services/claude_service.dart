import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ClaudeService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';
  static const _maxTokens = 800;
  static const _systemPrompt =
      'Du bist ein verständlicher Erklärer. Antworte ausschließlich mit der '
      'Erklärung, ohne Einleitung, Überschrift oder Kommentar. '
      'Antworte immer auf Deutsch.';

  static int _callsToday = 0;
  static DateTime? _callsDate;
  static const _maxCallsPerDay = 20;

  static Future<ClaudeResult> explain(String topic, String apiKey) async {
    if (apiKey.trim().isEmpty) return ClaudeResult.noKey();

    final now = DateTime.now();

    if (_callsDate == null || !_isSameDay(_callsDate!, now)) {
      _callsToday = 0;
      _callsDate = now;
    }

    if (_callsToday >= _maxCallsPerDay) return ClaudeResult.rateLimit();

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': _maxTokens,
              'system': _systemPrompt,
              'messages': [
                {
                  'role': 'user',
                  'content':
                      'Erkläre das Folgende in 250 bis 350 Wörtern auf Deutsch. '
                      'Beginne mit einer kurzen Einordnung was es ist, '
                      'und erkläre es dann umfassend und sinnvoll. '
                      'Thema: $topic',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = (data['content'] as List)
            .whereType<Map>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join();
        if (text.trim().isNotEmpty) {
          _callsToday++;
          _callsDate = now;
          return ClaudeResult.success(text.trim());
        }
      } else if (response.statusCode == 401) {
        return ClaudeResult.invalidKey();
      } else if (response.statusCode == 429) {
        return ClaudeResult.rateLimit();
      }
      return ClaudeResult.error('Unbekannter Fehler (${response.statusCode})');
    } on SocketException {
      return ClaudeResult.noInternet();
    } on Exception {
      return ClaudeResult.error('Anfrage fehlgeschlagen');
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // --- Kapitelzusammenfassung (Haiku) ---
  static const _summaryModel = 'claude-sonnet-4-6';
  static const _summaryMaxTokens = 4096;
  static const _maxSummariesPerDay = 5;
  static int _summaryCallsToday = 0;
  static DateTime? _summaryCallsDate;
  static const _summarySystemPrompt =
      'Du fasst Buchkapitel prägnant und fokussiert zusammen. Schreibe fließenden Prosatext. '
      'Beginne sofort mit dem ersten Inhalt – keine Überschrift, kein Markdown. '
      'Keine Einleitungsformulierungen wie "In diesem Kapitel" oder "Das Kapitel". '
      'Schließe jeden Gedanken vollständig ab, bevor du zum nächsten übergehst. '
      'Konzentriere dich nur auf die absoluten Kernereignisse und die wichtigsten Figurenentwicklungen. '
      'Kürze Nebenhandlungen, lange Dialoge und Detailbeschreibungen drastisch weg. '
      'Die Zusammenfassung soll extrem kompakt sein und sich nach etwa 15-20% der Länge des Originaltextes richten. '
      'Gib Szenen, Figuren und Entwicklungen vollständig, aber stark gerafft wieder. '
      'Halte dich ausschließlich an das, was im Text explizit steht – keine Interpretationen, keine Ergänzungen, keine Wertungen. '
      'Wenn eine Motivation oder Reaktion nicht wörtlich im Text steht, erwähne sie nicht. '
      'Schreibe abwechslungsreich – vermeide Wortwiederholungen innerhalb weniger Sätze. '
      'Antworte vollständig auf Deutsch.';

  static Future<ClaudeResult> summarizeChapter(
    String chapterText,
    String apiKey,
  ) async {
    if (apiKey.trim().isEmpty) return ClaudeResult.noKey();
    if (chapterText.trim().isEmpty) {
      return ClaudeResult.error('Kapitel enthält keinen Text.');
    }

    final now = DateTime.now();
    if (_summaryCallsDate == null || !_isSameDay(_summaryCallsDate!, now)) {
      _summaryCallsToday = 0;
      _summaryCallsDate = now;
    }
    if (_summaryCallsToday >= _maxSummariesPerDay) {
      return ClaudeResult.rateLimit();
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _summaryModel,
              'max_tokens': _summaryMaxTokens,
              'system': _summarySystemPrompt,
              'messages': [
                {
                  'role': 'user',
                  'content':
                      'Fasse das folgende Kapitel zusammen:\n\n$chapterText',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = (data['content'] as List)
            .whereType<Map>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join();
        if (text.trim().isNotEmpty) {
          _summaryCallsToday++;
          _summaryCallsDate = now;
          return ClaudeResult.success(text.trim());
        }
      } else if (response.statusCode == 401) {
        return ClaudeResult.invalidKey();
      } else if (response.statusCode == 429) {
        return ClaudeResult.rateLimit();
      }
      return ClaudeResult.error('Unbekannter Fehler (${response.statusCode})');
    } on SocketException {
      return ClaudeResult.noInternet();
    } on Exception {
      return ClaudeResult.error('Anfrage fehlgeschlagen');
    }
  }
}

enum ClaudeStatus { success, noKey, invalidKey, noInternet, rateLimit, error }

class ClaudeResult {
  final ClaudeStatus status;
  final String? text;
  final String? message;

  ClaudeResult._({required this.status, this.text, this.message});

  factory ClaudeResult.success(String text) =>
      ClaudeResult._(status: ClaudeStatus.success, text: text);
  factory ClaudeResult.noKey() => ClaudeResult._(status: ClaudeStatus.noKey);
  factory ClaudeResult.invalidKey() =>
      ClaudeResult._(status: ClaudeStatus.invalidKey);
  factory ClaudeResult.noInternet() =>
      ClaudeResult._(status: ClaudeStatus.noInternet);
  factory ClaudeResult.rateLimit() =>
      ClaudeResult._(status: ClaudeStatus.rateLimit);
  factory ClaudeResult.error(String message) =>
      ClaudeResult._(status: ClaudeStatus.error, message: message);
}
