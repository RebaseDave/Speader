import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'summary_provider.dart';
import '../../core/theme/app_colors.dart';

class SummarySheet extends ConsumerStatefulWidget {
  const SummarySheet({super.key});

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<SummarySheet>
    with SingleTickerProviderStateMixin {
  AnimationController? _progressController;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(summaryProvider);
      if (state.status == SummaryStatus.loading) {
        _startProgress(state);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController?.dispose();
    super.dispose();
  }

  void _startProgress(SummaryState state) {
    final elapsed = state.loadingStartedAt != null
        ? DateTime.now().difference(state.loadingStartedAt!).inSeconds
        : 0;
    final remaining =
        (state.estimatedSeconds - elapsed).clamp(1, state.estimatedSeconds);
    final startValue =
        (elapsed / state.estimatedSeconds * 0.95).clamp(0.0, 0.94);

    _progressController?.dispose();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: remaining),
      value: startValue,
    )..animateTo(0.95, curve: Curves.easeOut);

    _countdownTimer?.cancel();
    setState(() => _remainingSeconds = remaining);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remainingSeconds = (_remainingSeconds - 1).clamp(0, 9999);
        });
      }
    });
  }

  void _finishProgress() {
    _countdownTimer?.cancel();
    _progressController?.animateTo(
      1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatRemaining(int seconds) {
    if (seconds >= 60) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '~${m}m ${s}s';
    }
    return '~${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(summaryProvider);

    ref.listen(summaryProvider, (previous, next) {
      if (next.status == SummaryStatus.loading &&
          previous?.status != SummaryStatus.loading) {
        _startProgress(next);
      } else if (next.status == SummaryStatus.done &&
          previous?.status == SummaryStatus.loading) {
        _finishProgress();
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.title ?? 'Zusammenfassung',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildBody(context, state),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SummaryState state) {
    switch (state.status) {
      case SummaryStatus.loading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Wird generiert… ${_formatRemaining(_remainingSeconds)}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _progressController ??
                    const AlwaysStoppedAnimation(0.0),
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressController?.value ?? 0.0,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                      minHeight: 4,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Sheet kann geschlossen werden – Generierung läuft weiter.',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        );
      case SummaryStatus.done:
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Text(
              state.summary ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        );
      case SummaryStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.white38, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.errorMessage ?? 'Fehler.',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      case SummaryStatus.idle:
        return const SizedBox.shrink();
    }
  }
}