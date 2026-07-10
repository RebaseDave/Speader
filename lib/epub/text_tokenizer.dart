import '../core/models/word_token.dart';
import '../rsvp/orp_calculator.dart';
import 'sentence_detector.dart';

class TextTokenizer {
  final SentenceDetector _sentenceDetector;

  TextTokenizer(this._sentenceDetector);

  List<WordToken> tokenize(List<String> rawTokens, int chapterIndex) {
    final tokens = <WordToken>[];
    var insideItalic = false;

    for (int i = 0; i < rawTokens.length; i++) {
      final raw = rawTokens[i];

      // Kursiv-Marker → Zustand umschalten, kein eigenes Token
      if (SentenceDetector.isItalicStartMarker(raw)) {
        insideItalic = true;
        continue;
      }
      if (SentenceDetector.isItalicEndMarker(raw)) {
        insideItalic = false;
        continue;
      }

      // Absatz-Marker → letztes Wort als Absatzende markieren
      if (SentenceDetector.isParagraphMarker(raw)) {
        if (tokens.isNotEmpty) {
          final last = tokens.last;
          // Zweiter Absatz-Marker direkt hintereinander (kein Wort dazwischen)
          // = leerer Absatz im Original = Szenenwechsel. Eigenes Token dafür,
          // damit der Reader daraus eine eigene Seite bauen kann.
          if (last.isParagraphEnd && !last.isSceneBreak && !last.isChapterTitle) {
            tokens.add(
              WordToken(
                raw: '__SCENE_BREAK__',
                normalized: '__SCENE_BREAK__',
                orpIndex: 0,
                isSentenceEnd: false,
                isCommaEnd: false,
                isParagraphEnd: true,
                isDashEnd: false,
                isChapterTitle: false,
                chapterIndex: last.chapterIndex,
                isItalic: false,
              ),
            );
          } else {
            final removed = tokens.removeLast();
            tokens.add(
              WordToken(
                raw: removed.raw,
                normalized: removed.normalized,
                orpIndex: removed.orpIndex,
                isSentenceEnd: removed.isSentenceEnd,
                isCommaEnd: removed.isCommaEnd,
                isParagraphEnd: true,
                isDashEnd: removed.isDashEnd,
                isChapterTitle: removed.isChapterTitle,
                chapterIndex: removed.chapterIndex,
                isItalic: removed.isItalic,
              ),
            );
          }
        }
        continue;
      }

      // Kapitel-Marker → als einzelnes ChapterTitle-Token
      if (SentenceDetector.isChapterMarker(raw)) {
        final title = SentenceDetector.extractChapterTitle(raw);
        tokens.add(
          WordToken(
            raw: title,
            normalized: title.toLowerCase(),
            orpIndex: 0,
            isSentenceEnd: false,
            isCommaEnd: false,
            isParagraphEnd: false,
            isDashEnd: false,
            isChapterTitle: true,
            chapterIndex: chapterIndex,
          ),
        );
        continue;
      }

      // Normales Wort
      final normalized = OrpCalculator.normalize(raw);

      // Gedankenstrich als eigener Token
      if (SentenceDetector.isDashToken(raw)) {
        tokens.add(
          WordToken(
            raw: raw,
            normalized: raw,
            orpIndex: 0,
            isSentenceEnd: false,
            isCommaEnd: false,
            isDashEnd: true,
            isParagraphEnd: false,
            isChapterTitle: false,
            chapterIndex: chapterIndex,
            isItalic: insideItalic,
          ),
        );
        continue;
      }

      if (normalized.isEmpty) {
        final hasMeaningfulChar =
            RegExp(r'[.–—«»?!;…]').hasMatch(raw) || raw.contains('...');
        if (!hasMeaningfulChar) continue;

        final sentenceEnd =
            _sentenceDetector.isSentenceEnd(raw) ||
            _sentenceDetector.isEllipsis(raw);
        final commaEnd = _sentenceDetector.isCommaEnd(raw);
        final dashEnd =
            _sentenceDetector.isDashEnd(raw) ||
            SentenceDetector.isDashToken(raw);

        tokens.add(
          WordToken(
            raw: raw,
            normalized: raw,
            orpIndex: 0,
            isSentenceEnd: sentenceEnd,
            isCommaEnd: commaEnd,
            isDashEnd: dashEnd,
            isParagraphEnd: false,
            isChapterTitle: false,
            chapterIndex: chapterIndex,
            isItalic: insideItalic,
          ),
        );
        continue;
      }

      // Bindestrich- und Schrägstrich-Trennung
      final hasDash = raw.contains('-') && !raw.startsWith('-');
      final hasSlash =
          raw.contains('/') &&
          !raw.startsWith('/') &&
          raw.split('/').every((p) => RegExp(r'[a-zA-ZäöüÄÖÜß]').hasMatch(p));

      if (hasDash || hasSlash) {
        final separator = hasDash ? '-' : '/';
        final parts = raw.split(separator);
        for (int p = 0; p < parts.length; p++) {
          final part = p < parts.length - 1
              ? '${parts[p]}$separator'
              : parts[p];
          final normalizedPart = OrpCalculator.normalize(part);
          if (normalizedPart.isEmpty) continue;
          final orpIndex = OrpCalculator.rawIndex(
            part,
            normalizedPart,
            OrpCalculator.calculate(normalizedPart),
          );
          final isLast = p == parts.length - 1;

          // Blank-Token bei Wiederholung
          if (tokens.isNotEmpty &&
              tokens.last.normalized == normalizedPart &&
              !tokens.last.isBlank) {
            tokens.add(
              WordToken(
                raw: '',
                normalized: '__BLANK__',
                orpIndex: 0,
                isSentenceEnd: false,
                isCommaEnd: false,
                isDashEnd: false,
                isParagraphEnd: false,
                isChapterTitle: false,
                chapterIndex: chapterIndex,
                isItalic: insideItalic,
              ),
            );
          }

          tokens.add(
            WordToken(
              raw: part,
              normalized: normalizedPart,
              orpIndex: orpIndex,
              isSentenceEnd: isLast
                  ? _sentenceDetector.isSentenceEnd(raw)
                  : false,
              isCommaEnd: isLast ? _sentenceDetector.isCommaEnd(raw) : false,
              isDashEnd: false,
              isParagraphEnd: false,
              isChapterTitle: false,
              chapterIndex: chapterIndex,
              isItalic: insideItalic,
            ),
          );
        }
        continue;
      }

      final orpIndex = OrpCalculator.rawIndex(
        raw,
        normalized,
        OrpCalculator.calculate(normalized),
      );
      final sentenceEnd = _sentenceDetector.isSentenceEnd(raw);
      final commaEnd = _sentenceDetector.isCommaEnd(raw);
      final dashEnd = _sentenceDetector.isDashEnd(raw);

      // Blank-Token bei Wiederholung
      if (tokens.isNotEmpty &&
          tokens.last.normalized == normalized &&
          !tokens.last.isBlank) {
        tokens.add(
          WordToken(
            raw: '',
            normalized: '__BLANK__',
            orpIndex: 0,
            isSentenceEnd: false,
            isCommaEnd: false,
            isDashEnd: false,
            isParagraphEnd: false,
            isChapterTitle: false,
            chapterIndex: chapterIndex,
            isItalic: insideItalic,
          ),
        );
      }

      tokens.add(
        WordToken(
          raw: raw,
          normalized: normalized,
          orpIndex: orpIndex,
          isSentenceEnd: sentenceEnd,
          isCommaEnd: commaEnd,
          isDashEnd: dashEnd,
          isParagraphEnd: false,
          isChapterTitle: false,
          chapterIndex: chapterIndex,
          isItalic: insideItalic,
        ),
      );
    }

    return tokens;
  }
}
