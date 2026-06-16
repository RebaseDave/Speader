import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/claude_service.dart';
import '../../core/services/settings_service.dart';

enum ExplainStatus { idle, loading, done, error }

class ExplainState {
  final ExplainStatus status;
  final String? topic;
  final String? text;
  final String? errorMessage;

  const ExplainState({
    this.status = ExplainStatus.idle,
    this.topic,
    this.text,
    this.errorMessage,
  });
}

class ExplainNotifier extends Notifier<ExplainState> {
  @override
  ExplainState build() => const ExplainState();

  Future<void> explain(String topic) async {
    final apiKey = SettingsService.instance.claudeApiKey;
    if (apiKey.isEmpty) {
      state = ExplainState(
        status: ExplainStatus.error,
        topic: topic,
        errorMessage: 'Kein API Key hinterlegt.',
      );
      return;
    }

    state = ExplainState(status: ExplainStatus.loading, topic: topic);

    final result = await ClaudeService.explain(topic, apiKey);

    switch (result.status) {
      case ClaudeStatus.success:
        state = ExplainState(
          status: ExplainStatus.done,
          topic: topic,
          text: result.text,
        );
      case ClaudeStatus.noKey:
        state = ExplainState(
          status: ExplainStatus.error,
          topic: topic,
          errorMessage: 'Kein API Key hinterlegt.',
        );
      case ClaudeStatus.invalidKey:
        state = ExplainState(
          status: ExplainStatus.error,
          topic: topic,
          errorMessage: 'API Key ungültig.',
        );
      case ClaudeStatus.noInternet:
        state = ExplainState(
          status: ExplainStatus.error,
          topic: topic,
          errorMessage: 'Kein Internet.',
        );
      case ClaudeStatus.rateLimit:
        state = ExplainState(
          status: ExplainStatus.error,
          topic: topic,
          errorMessage: 'Tageslimit erreicht – bitte später versuchen.',
        );
      case ClaudeStatus.error:
        state = ExplainState(
          status: ExplainStatus.error,
          topic: topic,
          errorMessage: result.message ?? 'Fehler bei der Anfrage.',
        );
    }
  }

  void reset() => state = const ExplainState();
}

final explainProvider = NotifierProvider<ExplainNotifier, ExplainState>(
  ExplainNotifier.new,
);