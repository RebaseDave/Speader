import 'package:epubx/epubx.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:convert';

class ParsedBook {
  final String title;
  final String? author;
  final List<ParsedChapter> chapters;
  final Map<String, List<int>> images;
  ParsedBook({
    required this.title,
    this.author,
    required this.chapters,
    required this.images,
  });
}

class ParsedChapter {
  final String? title;
  final int indexInBook;
  final List<String> rawTokens;

  ParsedChapter({
    required this.title,
    required this.indexInBook,
    required this.rawTokens,
  });
}

class EpubParser {
  Future<ParsedBook> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();

    // Klassenbasierte Kursivierung ermitteln – unabhängig davon, ob epubx
    // das Buch überhaupt einlesen kann.
    final italicClassNames = _collectItalicClassNames(bytes);

    EpubBook epub;
    try {
      epub = await EpubReader.readBook(bytes);
    } catch (_) {
      return await _parseFallback(filePath, bytes, italicClassNames);
    }

    final title = epub.Title ?? 'Unbekannter Titel';
    final author = epub.Author?.isNotEmpty == true ? epub.Author : null;
    final chapters = <ParsedChapter>[];
    int chapterIndex = 0;

    // Gültige Bilddateinamen (> 10KB) für Token-Filterung vorberechnen
    final validImageNames = <String>{};
    final allEpubImages = epub.Content?.Images;
    if (allEpubImages != null) {
      for (final entry in allEpubImages.entries) {
        final content = entry.value.Content;
        if (content != null && content.length >= 10240) {
          final fileName = entry.key.split('/').last;
          if (fileName.isNotEmpty) validImageNames.add(fileName);
        }
      }
    }

    // Bereits verarbeitete Content-Hashes um Duplikate zu vermeiden
    final seenContentHashes = <int>{};

    // Kapitel-Hierarchie rekursiv traversieren
    void traverseChapter(EpubChapter chapter) {
      final content = chapter.HtmlContent;
      if (content != null && content.trim().isNotEmpty) {
        final hash = content.hashCode;
        if (!seenContentHashes.contains(hash)) {
          seenContentHashes.add(hash);
          final parsed = _parseChapter(chapter, chapterIndex, validImageNames, italicClassNames);
          if (parsed != null) {
            chapters.add(parsed);
            chapterIndex++;
          }
        }
      }
      for (final sub in chapter.SubChapters ?? []) {
        traverseChapter(sub);
      }
    }

    for (final chapter in epub.Chapters ?? []) {
      traverseChapter(chapter);
    }

    // Fallback: Spine direkt lesen wenn Chapters leer oder sehr wenig Content
    final totalChapterWords = chapters.fold<int>(
      0,
      (sum, c) => sum + c.rawTokens.where((t) => !t.startsWith('__')).length,
    );

    if (chapters.isEmpty || totalChapterWords < 1000) {
      chapters.clear();
      chapterIndex = 0;
      seenContentHashes.clear();

      final htmlFiles = epub.Content?.Html;
      if (htmlFiles != null) {
        // Spine-Reihenfolge aus Manifest
        final spineIds =
            epub.Schema?.Package?.Spine?.Items
                ?.map((item) => item.IdRef ?? '')
                .where((id) => id.isNotEmpty)
                .toList() ??
            [];

        final manifestItems = epub.Schema?.Package?.Manifest?.Items ?? [];
        final idToHref = <String, String>{
          for (final item in manifestItems)
            if (item.Id != null && item.Href != null) item.Id!: item.Href!,
        };

        // Keys in Spine-Reihenfolge
        final orderedKeys = <String>[];
        for (final id in spineIds) {
          final href = idToHref[id];
          if (href == null) continue;
          final key = htmlFiles.keys.firstWhere(
            (k) => k.endsWith(href) || href.endsWith(k),
            orElse: () => '',
          );
          if (key.isNotEmpty && !orderedKeys.contains(key)) {
            orderedKeys.add(key);
          }
        }

        // Fallback: alle HTML-Files wenn Spine-Mapping leer
        final keys = orderedKeys.isNotEmpty
            ? orderedKeys
            : htmlFiles.keys.toList();

        for (final key in keys) {
          final htmlContent = htmlFiles[key];
          if (htmlContent?.Content == null) continue;

          final content = htmlContent!.Content!;
          final hash = content.hashCode;
          if (seenContentHashes.contains(hash)) continue;
          seenContentHashes.add(hash);

          // Fußnoten-Files überspringen
          if (_isFootnoteFile(content)) continue;

          final text = _htmlToText(content, validImageNames, italicClassNames);
          final tokens = _tokenize(text);
          if (tokens.length < 10) continue;

          chapters.add(
            ParsedChapter(
              title: null,
              indexInBook: chapterIndex,
              rawTokens: tokens,
            ),
          );
          chapterIndex++;
        }
      }
    }

    // Bilder extrahieren (nur > 10KB, keine Dekorations-Grafiken)
    final images = <String, List<int>>{};
    final epubImages = epub.Content?.Images;
    if (epubImages != null) {
      for (final entry in epubImages.entries) {
        final content = entry.value.Content;
        if (content == null || content.length < 10240) continue;
        final fileName = entry.key.split('/').last;
        if (fileName.isNotEmpty && !images.containsKey(fileName)) {
          images[fileName] = content;
        }
      }
    }

    return ParsedBook(title: title, author: author, chapters: chapters, images: images);
  }

  ParsedChapter? _parseChapter(EpubChapter chapter, int index, Set<String> validImageNames, Set<String> italicClassNames) {
    final content = chapter.HtmlContent;
    if (content == null || content.trim().isEmpty) return null;

    if (_isFootnoteFile(content)) return null;

    final tokens = <String>[];

    final chapterTitle = chapter.Title?.trim();
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      tokens.add('__CHAPTER__:$chapterTitle');
    }

    final text = _htmlToText(content, validImageNames, italicClassNames);
    final contentTokens = _tokenize(text);

    if (contentTokens.isEmpty) return null;

    // Kapitelüberschrift am Anfang des Contents entfernen wenn sie dort wiederholt wird
    final filtered = _removeLeadingTitleRepetition(contentTokens, chapterTitle);

    tokens.addAll(filtered);

    return ParsedChapter(
      title: chapterTitle,
      indexInBook: index,
      rawTokens: tokens,
    );
  }

  List<String> _removeLeadingTitleRepetition(
    List<String> tokens,
    String? title,
  ) {
    if (title == null || title.isEmpty || tokens.isEmpty) return tokens;

    final titleWords = title
        .split(RegExp(r'\s+'))
        .map((w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    if (titleWords.isEmpty) return tokens;

    // Mindestanzahl gematchter Wörter – Schutz vor Zufallstreffern
    final minMatch = titleWords.length == 1 ? 1 : 2;
    const maxSearchTokens = 8;
    int realTokenCount = 0;

    for (int startIdx = 0; startIdx < tokens.length; startIdx++) {
      final t = tokens[startIdx];
      if (t.startsWith('__')) continue;

      realTokenCount++;
      if (realTokenCount > maxSearchTokens) break;

      // Probiere jede mögliche Startposition im Titel (Vollmatch UND Suffix-Match).
      // Das behandelt den Fall, wo ein Teil des Titels (z.B. "Kapitel Eins")
      // bereits durch h1–h6-Entfernung weggefallen ist und nur der Rest
      // ("Das Don-Salvara-Spiel") noch im Content steht.
      for (int titleStart = 0; titleStart < titleWords.length; titleStart++) {
        int matchCount = 0;
        int matchIdx = startIdx;
        int ti = titleStart;

        while (matchIdx < tokens.length && ti < titleWords.length) {
          final token = tokens[matchIdx];
          if (token.startsWith('__')) {
            matchIdx++;
            continue;
          }
          final normalized = token.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9äöüß]'),
            '',
          );
          if (normalized == titleWords[ti]) {
            matchCount++;
            ti++;
            matchIdx++;
          } else {
            break;
          }
        }

        // Erfolgreich wenn alle verbleibenden Titelwörter gefunden
        // UND Mindestanzahl Wörter gematcht wurde
        if (ti == titleWords.length && matchCount >= minMatch) {
          return tokens.sublist(matchIdx);
        }
      }
    }

    return tokens;
  }

  bool _isFootnoteFile(String html) {
    // Typische Fußnoten-Marker
    final lower = html.toLowerCase();
    final hasFootnoteType =
        lower.contains('epub:type="footnote"') ||
        lower.contains('epub:type="endnote"') ||
        lower.contains('role="doc-footnote"') ||
        lower.contains('role="doc-endnote"');
    if (!hasFootnoteType) return false;

    // Nur als Fußnote markieren wenn der echte Textinhalt sehr kurz ist
    final text = _htmlToText(html);
    final tokens = _tokenize(text);
    return tokens.length < 50;
  }

  /// Sammelt alle CSS-Klassennamen aus dem EPUB, deren Regel
  /// `font-style: italic` (oder `oblique`) setzt. Manche EPUBs (z.B. aus
  /// Calibre-Konvertierungen) nutzen dafür Klassen statt <i>/<em>-Tags.
  Set<String> _collectItalicClassNames(List<int> bytes) {
    final classNames = <String>{};
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (!file.isFile) continue;
        if (!file.name.toLowerCase().endsWith('.css')) continue;
        final css = utf8.decode(file.content as List<int>, allowMalformed: true);
        classNames.addAll(_extractItalicClassNames(css));
      }
    } catch (_) {
      // CSS nicht lesbar? Kein Beinbruch – <i>/<em>-Tags funktionieren weiterhin.
    }
    return classNames;
  }

  Set<String> _extractItalicClassNames(String css) {
    final result = <String>{};
    final ruleRegex = RegExp(r'\.([a-zA-Z0-9_-]+)\s*\{([^}]*)\}', dotAll: true);
    for (final match in ruleRegex.allMatches(css)) {
      final body = match.group(2) ?? '';
      if (RegExp(r'font-style\s*:\s*(italic|oblique)', caseSensitive: false)
          .hasMatch(body)) {
        result.add(match.group(1)!);
      }
    }
    return result;
  }

  String _htmlToText(String html, [Set<String>? validImageNames, Set<String>? italicClassNames]) {
    var text = html;

    // XML-Deklarationen entfernen
    text = text.replaceAll(RegExp(r'<\?xml[^>]*\?>'), '');

    // Kommentare entfernen
    text = text.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    // CDATA entfernen
    text = text.replaceAll(RegExp(r'<!\[CDATA\[.*?\]\]>', dotAll: true), '');

    // head entfernen
    text = text.replaceAll(
      RegExp(r'<head[^>]*>.*?</head>', caseSensitive: false, dotAll: true),
      '',
    );

    // Script und Style inkl. Inhalt entfernen
    text = text.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      '',
    );

    // SVG komplett entfernen (inkl. Inhalt – enthält Koordinaten und Pfade)
    text = text.replaceAll(
      RegExp(r'<svg[^>]*>.*?</svg>', caseSensitive: false, dotAll: true),
      '',
    );

    // Headings entfernen
    text = text.replaceAll(
      RegExp(r'<h[1-6][^>]*>.*?</h[1-6]>', caseSensitive: false, dotAll: true),
      '',
    );

    // Absätze markieren – p, div, br
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'</p>', caseSensitive: false),
      ' __PARAGRAPH__ ',
    );
    text = text.replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'</div>', caseSensitive: false),
      ' __PARAGRAPH__ ',
    );
    text = text.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      ' __PARAGRAPH__ ',
    );

    // Bilder als Marker erhalten (nur wenn Datei auch extrahiert wird)
    text = text.replaceAllMapped(
      RegExp(r'<img\b[^>]*?>', caseSensitive: false, dotAll: true),
      (match) {
        final imgTag = match.group(0)!;
        final srcMatch = RegExp(r'''src=["']([^"']+)["']''', caseSensitive: false)
            .firstMatch(imgTag);
        if (srcMatch == null) return '';
        final src = srcMatch.group(1)!.trim();
        final fileName = src.split('/').last.split('?').first;
        if (fileName.isEmpty) return '';
        if (validImageNames != null && !validImageNames.contains(fileName)) return '';
        return ' __IMAGE__:$fileName ';
      },
    );

    // Klassenbasierte Kursivierung (z.B. <span class="class_4843">) als
    // Marker erhalten, bevor der große Kehraus kommt.
    if (italicClassNames != null && italicClassNames.isNotEmpty) {
      for (final cls in italicClassNames) {
        for (final tag in ['span', 'p', 'div']) {
          text = text.replaceAllMapped(
            RegExp(
              '<$tag\\s+class="[^"]*\\b$cls\\b[^"]*"[^>]*>(.*?)</$tag>',
              caseSensitive: false,
              dotAll: true,
            ),
            (m) => ' __ITALIC_START__ ${m.group(1)} __ITALIC_END__ ',
          );
        }
      }
    }

    // Kursiv-Tags als Marker erhalten, bevor der große Kehraus kommt
    text = text.replaceAll(
      RegExp(r'<(em|i)\b[^>]*>', caseSensitive: false),
      ' __ITALIC_START__ ',
    );
    text = text.replaceAll(
      RegExp(r'</(em|i)>', caseSensitive: false),
      ' __ITALIC_END__ ',
    );

    // Alle anderen HTML-Tags entfernen
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // HTML-Entities ersetzen
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&apos;', "'");
    text = text.replaceAll('&shy;', '');
    text = text.replaceAll('&#173;', '');
    text = text.replaceAll('&mdash;', '—');
    text = text.replaceAll('&ndash;', '–');
    text = text.replaceAll('&hellip;', '…');
    text = text.replaceAll('&laquo;', '«');
    text = text.replaceAll('&raquo;', '»');
    text = text.replaceAll('&ldquo;', '\u201C');
    text = text.replaceAll('&rdquo;', '\u201D');
    text = text.replaceAll('&lsquo;', '\u2018');
    text = text.replaceAll('&rsquo;', '\u2019');
    text = text.replaceAll('&copy;', '©');
    text = text.replaceAll('&trade;', '™');
    text = text.replaceAll('&reg;', '®');
    text = text.replaceAll('&deg;', '°');
    text = text.replaceAll('&prime;', '′');
    text = text.replaceAll('&Prime;', '″');

    // Lateinische Akzentzeichen (Kleinbuchstaben)
    text = text.replaceAll('&agrave;', 'à');
    text = text.replaceAll('&aacute;', 'á');
    text = text.replaceAll('&acirc;', 'â');
    text = text.replaceAll('&atilde;', 'ã');
    text = text.replaceAll('&auml;', 'ä');
    text = text.replaceAll('&aring;', 'å');
    text = text.replaceAll('&aelig;', 'æ');
    text = text.replaceAll('&ccedil;', 'ç');
    text = text.replaceAll('&egrave;', 'è');
    text = text.replaceAll('&eacute;', 'é');
    text = text.replaceAll('&ecirc;', 'ê');
    text = text.replaceAll('&euml;', 'ë');
    text = text.replaceAll('&igrave;', 'ì');
    text = text.replaceAll('&iacute;', 'í');
    text = text.replaceAll('&icirc;', 'î');
    text = text.replaceAll('&iuml;', 'ï');
    text = text.replaceAll('&ntilde;', 'ñ');
    text = text.replaceAll('&ograve;', 'ò');
    text = text.replaceAll('&oacute;', 'ó');
    text = text.replaceAll('&ocirc;', 'ô');
    text = text.replaceAll('&otilde;', 'õ');
    text = text.replaceAll('&ouml;', 'ö');
    text = text.replaceAll('&oslash;', 'ø');
    text = text.replaceAll('&ugrave;', 'ù');
    text = text.replaceAll('&uacute;', 'ú');
    text = text.replaceAll('&ucirc;', 'û');
    text = text.replaceAll('&uuml;', 'ü');
    text = text.replaceAll('&yacute;', 'ý');
    text = text.replaceAll('&szlig;', 'ß');

    // Lateinische Akzentzeichen (Großbuchstaben)
    text = text.replaceAll('&Agrave;', 'À');
    text = text.replaceAll('&Aacute;', 'Á');
    text = text.replaceAll('&Acirc;', 'Â');
    text = text.replaceAll('&Atilde;', 'Ã');
    text = text.replaceAll('&Auml;', 'Ä');
    text = text.replaceAll('&Aring;', 'Å');
    text = text.replaceAll('&AElig;', 'Æ');
    text = text.replaceAll('&Ccedil;', 'Ç');
    text = text.replaceAll('&Egrave;', 'È');
    text = text.replaceAll('&Eacute;', 'É');
    text = text.replaceAll('&Ecirc;', 'Ê');
    text = text.replaceAll('&Euml;', 'Ë');
    text = text.replaceAll('&Igrave;', 'Ì');
    text = text.replaceAll('&Iacute;', 'Í');
    text = text.replaceAll('&Icirc;', 'Î');
    text = text.replaceAll('&Iuml;', 'Ï');
    text = text.replaceAll('&Ntilde;', 'Ñ');
    text = text.replaceAll('&Ograve;', 'Ò');
    text = text.replaceAll('&Oacute;', 'Ó');
    text = text.replaceAll('&Ocirc;', 'Ô');
    text = text.replaceAll('&Otilde;', 'Õ');
    text = text.replaceAll('&Ouml;', 'Ö');
    text = text.replaceAll('&Oslash;', 'Ø');
    text = text.replaceAll('&Ugrave;', 'Ù');
    text = text.replaceAll('&Uacute;', 'Ú');
    text = text.replaceAll('&Ucirc;', 'Û');
    text = text.replaceAll('&Uuml;', 'Ü');
    text = text.replaceAll('&Yacute;', 'Ý');

    // Hex-Entities entfernen
    text = text.replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '');
    // Numerische Entities entfernen
    text = text.replaceAll(RegExp(r'&#\d+;'), '');
    // Verbleibende benannte Entities entfernen
    text = text.replaceAll(RegExp(r'&[a-zA-Z]+;'), '');

    // Zero-Width Spaces und unsichtbare Zeichen entfernen
    text = text.replaceAll('\u200B', '');
    text = text.replaceAll('\u200C', '');
    text = text.replaceAll('\u200D', '');
    text = text.replaceAll('\uFEFF', '');

    // Unicode-Steuerzeichen entfernen
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Mehrfache Leerzeichen/Zeilenumbrüche normalisieren
    text = text.replaceAll(RegExp(r'\n+'), ' ');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    return text;
  }

  /// Nur Bilder aus dem EPUB extrahieren (für den Fall dass Token-Cache bereits existiert)
  Future<Map<String, List<int>>> parseImagesOnly(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    final images = <String, List<int>>{};
    final epubImages = epub.Content?.Images;
    if (epubImages != null) {
      for (final entry in epubImages.entries) {
        final content = entry.value.Content;
        if (content == null || content.length < 10240) continue;
        final fileName = entry.key.split('/').last;
        if (fileName.isNotEmpty && !images.containsKey(fileName)) {
          images[fileName] = content;
        }
      }
    }
    return images;
  }

  Future<ParsedBook> _parseFallback(
    String filePath,
    List<int> bytes,
    Set<String> italicClassNames,
  ) async {
    // Öffne EPUB manuell als ZIP und lese nur existierende HTML-Dateien
    final archive = ZipDecoder().decodeBytes(bytes);

    // Dateien nach Name indexieren
    final fileMap = <String, ArchiveFile>{};
    for (final file in archive) {
      if (file.isFile) fileMap[file.name] = file;
    }

    // OPF-Datei finden
    String? opfPath;
    final containerFile = fileMap['META-INF/container.xml'];
    if (containerFile != null) {
      final containerXml = utf8.decode(containerFile.content as List<int>);
      final match = RegExp(r'full-path="([^"]+\.opf)"').firstMatch(containerXml);
      opfPath = match?.group(1);
    }
    opfPath ??= fileMap.keys.firstWhere(
      (k) => k.endsWith('.opf'),
      orElse: () => '',
    );
    if (opfPath.isEmpty) {
      return ParsedBook(title: _titleFromPath(filePath), chapters: [], images: {});
    }

    final opfFile = fileMap[opfPath];
    if (opfFile == null) {
      return ParsedBook(title: _titleFromPath(filePath), chapters: [], images: {});
    }

    final opfXml = utf8.decode(opfFile.content as List<int>);
    final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

    // Titel aus OPF
    final titleMatch = RegExp(r'<dc:title[^>]*>([^<]+)</dc:title>', caseSensitive: false).firstMatch(opfXml);
    final title = _decodeXmlEntities(titleMatch?.group(1)?.trim() ?? _titleFromPath(filePath));
    
    // Autor aus OPF
    final authorMatch = RegExp(r'<dc:creator[^>]*>([^<]+)</dc:creator>', caseSensitive: false).firstMatch(opfXml);
    final author = _decodeXmlEntities(authorMatch?.group(1)?.trim() ?? '').isEmpty 
        ? null : _decodeXmlEntities(authorMatch?.group(1)?.trim() ?? '');

    // Spine-Reihenfolge aus OPF
    final manifestItems = <String, String>{};
    for (final m in RegExp(r'<item\s[^>]*id="([^"]+)"[^>]*href="([^"]+)"', caseSensitive: false).allMatches(opfXml)) {
      manifestItems[m.group(1)!] = m.group(2)!;
    }

    final spineRefs = <String>[];
    for (final m in RegExp(r'<itemref\s[^>]*idref="([^"]+)"', caseSensitive: false).allMatches(opfXml)) {
      final href = manifestItems[m.group(1)!];
      if (href != null) spineRefs.add(href);
    }

    // HTML-Dateien in Spine-Reihenfolge lesen (nur existierende)
    final chapters = <ParsedChapter>[];
    int chapterIndex = 0;
    final seenHashes = <int>{};

    for (final href in spineRefs) {
      final fullPath = opfDir + href;
      final normalizedPath = fullPath.replaceAll('../', '');
      ArchiveFile? file = fileMap[fullPath] ?? fileMap[normalizedPath];
      if (file == null) {
        final filename = href.split('/').last;
        for (final entry in fileMap.entries) {
          if (entry.key.endsWith(filename)) {
            file = entry.value;
            break;
          }
        }
      }
      if (file == null) continue; // Fehlende Datei überspringen statt crashen

      final content = utf8.decode(file.content as List<int>, allowMalformed: true);
      final hash = content.hashCode;
      if (seenHashes.contains(hash)) continue;
      seenHashes.add(hash);

      if (_isFootnoteFile(content)) continue;

      final text = _htmlToText(content, null, italicClassNames);
      final tokens = _tokenize(text);
      if (tokens.length < 10) continue;

      chapters.add(ParsedChapter(
        title: null,
        indexInBook: chapterIndex,
        rawTokens: tokens,
      ));
      chapterIndex++;
    }

    return ParsedBook(title: title, author: author, chapters: chapters, images: {});
  }

  String _titleFromPath(String path) =>
      path.split('/').last.replaceAll('.epub', '');

  String _decodeXmlEntities(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#38;', '&');

  List<String> _tokenize(String text) {
    final tokens = <String>[];
    for (final part in text.split(RegExp(r'\s+'))) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        tokens.add(trimmed);
      }
    }
    return tokens;
  }
}
