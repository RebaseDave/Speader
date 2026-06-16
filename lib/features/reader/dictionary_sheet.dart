import 'package:flutter/material.dart';
import '../../core/services/dictionary_service.dart';

class DictionarySheet extends StatefulWidget {
  final String word;
  final String? sentence;
  const DictionarySheet({super.key, required this.word, this.sentence});

  @override
  State<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<DictionarySheet> {
  DictionaryResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await DictionaryService.lookup(widget.word, sentence: widget.sentence);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF112240),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.word,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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
            _buildBody(),
            const SizedBox(height: 8),
          ],
        ),
      );
  }

  Widget _buildBody() {
    if (_result == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_result!.status) {
      case DictionaryStatus.found:
        return Text(
          _result!.definition!,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.5,
          ),
        );
      case DictionaryStatus.noInternet:
        return const _StatusMessage(
          icon: Icons.wifi_off,
          text: 'Kein Internet – Wörterbuch nicht verfügbar.',
        );
      case DictionaryStatus.notFound:
        return _StatusMessage(
          icon: Icons.search_off,
          text: 'Kein Eintrag für „${widget.word}" gefunden.',
        );
      case DictionaryStatus.noKey:
        return const _StatusMessage(
          icon: Icons.key_off,
          text: 'Kein API Key hinterlegt – bitte in den Einstellungen eintragen.',
        );
      case DictionaryStatus.invalidKey:
        return const _StatusMessage(
          icon: Icons.key_off,
          text: 'API Key ungültig.',
        );
      case DictionaryStatus.rateLimit:
        return const _StatusMessage(
          icon: Icons.timer_off,
          text: 'Zu viele Anfragen – bitte kurz warten.',
        );
    }
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatusMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}