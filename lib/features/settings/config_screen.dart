import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/word_token.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/hsl_sliders.dart';
import '../../rsvp/display_timer.dart';
import '../../rsvp/orp_calculator.dart';
import '../reader/rsvp_display.dart';
import 'settings_provider.dart';
import '../../core/database/orp_dao.dart';
import '../../core/database/token_cache_dao.dart';
import '../../core/database/backup_service.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

const _previewText =
    'Der Mann mit dem Mikrofon\n\n'
    'Der Novemberregen klatschte gegen die Scheiben des Café Metropol, während Viktor Stein den Kaffee in seiner Tasse methodisch kalt werden ließ.\n\n'
    'Er saß an einem unauffälligen Ecktisch, die Zeitung aufgeschlagen — Wirtschaftsnachrichten, die staubtrockene dritte Seite.\n\n'
    'Seit nunmehr vierzehn Jahren operierte er als unbesungener Geheimdienstmitarbeiter im Staatsdienst, weit entfernt von jener glamourösen Traumwelt, die man aus modernen Kinofilmen kennt. '
    'Es gab in seinem Leben keinen eleganten Aston Martin, keine maßgeschneiderten Anzüge, keine lautlosen Schalldämpferwaffen und gewiss keinen geschüttelten Martini an Hotelbars. '
    'Viktor bevorzugte die absolute Anonymität, trank lauwarmes Koffeingetränk und steuerte werktags einen beigen Skoda, dessen optische Unattraktivität seine schärfste Waffe darstellte. '
    'Sein pragmatischer Abteilungsleiter pflegte diese Methode intern als eine "Verschleierungsstrategie durch demonstrative Langweiligkeit" zu bezeichnen, und Viktor hatte diesem Urteil nie widersprochen.\n\n'
    'Doch der heutige Spätnachmittag entzog sich der gewohnten Routine des bürokratischen Alltags. '
    'Vor ihm auf dem Holztisch ruhte ein schmuckloser, brauner Umschlag, den er vor exakt zwanzig Minuten mit einer fließenden Bewegung unter seinem Stuhl hervorgezogen hatte. '
    'Kein Absender störte das graue Papier, kein Name deutete auf die Herkunft hin, sondern lediglich eine einzige, in sauberer Druckschrift verfasste Zeile stach ihm ins Auge: '
    '„Hauptbahnhof. Punkt 18:00 Uhr. Die Frau mit dem leuchtend gelben Schal kennt die kritische Sicherheitslücke."\n\n'
    'Viktor faltete das Presseerzeugnis mit routinierten Handgriffen zusammen, denn irgendwo in den tiefen Strukturen der Bundesbehörde für Informationsschutz existierte ein massives Datenleck, das seine Abteilung bereits seit Wochen in Atem hielt. '
    'Sein präziser Kernauftrag lautete, die anonyme Person zu identifizieren, welche hochsensible Regierungsdaten an eine noch unidentifizierte ausländische Nachrichtenorganisation transferierte. '
    'Drei zermürbende Monate voller lückenloser Observationen, komplexer Datenauswertungen und chronischem Schlahmangel lagen hinter ihm, und nun manifestierte sich die heiße Spur in einem Umschlag. '
    'Er beglich die Rechnung wortlos am Tresen, schlug den Kragen seines Mantels hoch und trat hinaus in die nasskalte Dunkelheit.\n\n'
    'Der geschäftige Hauptbahnhof präsentierte sich um Viertel vor sechs als ein unüberschaubares, dynamisches Personenbahnhöfegewimmel aus gestressten Pendlern, rollenden Koffern und kollektiver Schlechtwetterlaune. '
    'Viktor positionierte sich mit sicherem Abstand neben einem überladenen Zeitschriftenstand und demonstrierte jene Geduld, die er im Laufe der Jahre zu einer regelrechten Kunstform perfektioniert hatte. '
    'Während die meisten Zivilisten in Momenten des Stillstands reflexartig ihr Mobiltelefon aus der Tasche ziehen, besaß Viktor die seltene Gabe, minutenlang so unbeweglich wie ein grauer Briefkasten auszuharren. '
    'Exakt um 17:58 Uhr erfasste sein geschulter Blick das Zielobjekt unter der flackernden Anzeigetafel.\n\n'
    'Gelber Schal. Schätzungsweise Mitte vierzig. Sie trug eine edle Lederaktentasche, die für den alltäglichen Arbeitseinsatz viel zu neu wirkte, und fixierte die Abfahrtszeiten der Züge mit demonstrativer Desinteressiertheit. '
    'Viktor verlagerte sein Gewicht und bewegte sich mit beiläufigen Schritten durch die Menschenströme in ihre unmittelbare Richtung. '
    'Als er sich schließlich direkt neben ihr befand, murmelte er, ohne den Blickkontakt zu suchen: „Unerwartet schlechtes Wetter heute." '
    '„Nur für manche", entgegnete sie prompt mit monotoner Stimme.\n\n'
    'Es war die exakte, im Protokoll festgelegte Codewortantwort, woraufhin er seine angespannten Schultern um ein unmerkliches Minimum absinken ließ. '
    '„Sie verfügen über brisante Informationen", stellte er nüchtern fest. '
    '„Und Sie besitzen hoffentlich die notwendigen Zuhörfähigkeiten", erwiderte sie, während sie die Tasche geschlossen hielt, ihm jedoch einen modifizierten USB-Stick reichte. '
    'Die Übergabe erfolgte so beiläufig und unscheinbar wie der Austausch einer gewöhnlichen Supermarktquittung inmitten des dichten Berufsverkehrs.\n\n'
    '„Der gesuchte Maulwurf entspricht keineswegs dem Profil, das Sie in Ihren Akten vermuten", flüsterte sie rasch, während sie den Blick ins Leere richtete. '
    '„Es handelt sich um die amtierende Personaldatenbankadministratorin der gesamten Behörde — zweite Etage, das hintere Büro ohne jegliches Namensschild." '
    'Viktor ließ den winzigen Datenträger lautlos in seine tiefe Manteltasche gleiten und fragte mit gedämpfter Stimme: „Welches Motiv treibt Sie an, uns zu helfen?"\n\n'
    'Sie wandte ihm für einen flüchtigen Moment das Gesicht zu und sah ihn zum ersten Mal direkt an. '
    '„Weil ich drei qualvolle Jahre für diese Frau gearbeitet habe und sie fälschlicherweise nur für eine unangenehme Vorgesetzte hielt. '
    'Nun stellt sich heraus: Sie ist nicht nur menschlich unangenehm, sondern eine eiskalte Landesverräterin." '
    'Nach diesen Worten drehte sie sich schwungvoll um und schmolz regelrecht in der anonymen Masse der Reisenden dahin. '
    'Es gab keinen cineastischen Abgang im Nebel und keinen dramatischen Blick zurück über die Schulter — sie war einfach verschwunden, wie eine gewöhnliche Pendlerin, die rechtzeitig ihren Anschlusszug erreicht hat.\n\n'
    'Eine knappe Stunde später saß Viktor in der vertrauten Enge seines Skodas und koppelte den USB-Stick an seinen speziell verschlüsselten Dienstlaptop. '
    'Die geschützten Verzeichnisse öffneten sich nacheinander auf dem Bildschirm: lückenlose Zugangsprotokolle, detaillierte Verbindungsdaten und chronologische Zeitstempel. '
    'Das gesamte Datenmaterial war von einer beängstigenden Akribie geprägt und bezeugte eine fast schon bewundernswerte, kriminelle Organisationsstruktur. '
    '„Gefährdungsbeurteilung", prangte in fetten Lettern als Überschrift über einem zentralen Hauptdokument.\n\n'
    'Die Zielperson hatte tatsächlich eine mathematische Risikoanalyse darüber angefertigt, wie viele Monate sie im inneren Zirkel unentdeckt operieren könnte. '
    'Viktor überflog die Berechnungen mit kühlem Blick; sie hatte sich selbst eine Frist von maximal eineinhalb Jahren eingeräumt. '
    'Dank der behördlichen Trägheit waren daraus letztendlich zwei Jahre und drei Monate geworden.\n\n'
    'Er begann umgehend mit der Formulierung seines offiziellen Abschlussberichts, wobei er bewusst auf blumige Adjektive oder dramatische Schilderungen verzichtete. '
    'Verdächtige Subjektsidentifizierung erfolgreich abgeschlossen. Beweismaterial vollumfänglich gesichert. Empfehle die sofortige Einleitung einer umfassenden Sicherheitsüberprüfung. '
    'Diese ausgeprägte Vorliebe für die trockene Bürokratiesprache zählte seit jeher zu seinen effektivsten, heimlichen Werkzeugen. '
    'Niemand im Hauptquartier liest Berichte wirklich gründlich, die sich in ihrer Tonalität kaum von den Allgemeinen Geschäftsbedingungen eines Versicherungsvertrags unterscheiden.\n\n'
    'Sein Mobiltelefon vibrierte kurz auf dem Beifahrersitz und signalisierte eine eingehende Textnachricht seines Vorgesetzten: „Hervorragende Arbeit. Wie immer." '
    'Viktor tippte mit starren Fingern die knappe Antwort zurück: „Der Kaffee im Metropol war kalt." '
    'Dann betätigte er die Zündung des Skoda, schaltete die Scheinwerfer ein und steuerte den Wagen lautlos in die regnerische Nacht. '
    'Es gab keinen triumphalen Moment, keinen Applaus der Kollegen und keine Ordensauszeichnung.\n\n'
    'Morgen früh würde ein namenloses Zugriffsteam eine Verhaftung durchführen, während er bereits wieder in einem anderen Café Platz nehmen würde. '
    'Er würde eine andere Zeitung aufschlagen, ein neues Gesicht observieren und den nächsten kalten Kaffee ignorieren. '
    'Die operative Geheimdienstarbeit, so resümierte er im Stillen, besteht im Wesentlichen aus endlosem Warten mit gelegentlichen Unterbrechungen durch Ereignisse, die man niemals weitererzählen darf. '
    'Und genau diese absolute Bedeutungslosigkeit war es, die er an seinem Beruf so aufrichtig schätzte.';

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final List<WordToken> _tokens;
  int _tokenIndex = 0;
  Timer? _timer;
  late final PageController _pageController;
  int _currentPage = 0;
  bool _paused = true;
  bool _paragraphPreview = SettingsService.instance.paragraphMode;

  @override
  void initState() {
    super.initState();
    _tokens = _buildTokens();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    super.dispose();
  }

  List<WordToken> _buildTokens() {
    final result = <WordToken>[];
    final paragraphs = _previewText.trim().split('\n\n');

    for (int p = 0; p < paragraphs.length; p++) {
      final words = paragraphs[p].trim().split(RegExp(r'\s+'));
      final isLastParagraph = p == paragraphs.length - 1;

      for (int w = 0; w < words.length; w++) {
        final raw = words[w];
        if (raw.isEmpty) continue;
        final isLastInParagraph = w == words.length - 1;
        final isParagraphEnd = isLastInParagraph && !isLastParagraph;
        final isSentenceEnd =
            !isParagraphEnd &&
            (raw.endsWith('.') || raw.endsWith('!') || raw.endsWith('?'));
        final isCommaEnd = raw.endsWith(',') || raw.endsWith(';');
        final isDashEnd = raw.endsWith('–') || raw.endsWith('—');
        final normalized = raw.replaceAll(RegExp(r'[.,;:!?–—»«]+$'), '');
        final orp = OrpCalculator.calculate(
          normalized.isEmpty ? raw : normalized,
        );

        result.add(
          WordToken(
            raw: raw,
            normalized: normalized.isEmpty ? raw : normalized,
            orpIndex: orp,
            isSentenceEnd:
                isSentenceEnd || (isLastInParagraph && isLastParagraph),
            isCommaEnd: isCommaEnd,
            isParagraphEnd: isParagraphEnd,
            isDashEnd: isDashEnd,
            isChapterTitle: false,
            chapterIndex: 0,
          ),
        );
      }

      if (!isLastParagraph) {
        result.add(
          const WordToken(
            raw: '__BLANK__',
            normalized: '__BLANK__',
            orpIndex: 0,
            isSentenceEnd: false,
            isCommaEnd: false,
            isParagraphEnd: true,
            isDashEnd: false,
            isChapterTitle: false,
            chapterIndex: 0,
          ),
        );
      }
    }
    return result;
  }

  void _scheduleNext() {
    if (_paused) return;
    final token = _tokens[_tokenIndex];
    final ms = DisplayTimer(SettingsService.instance).calculateMs(token);
    _timer = Timer(Duration(milliseconds: ms.clamp(50, 5000)), () {
      if (!mounted) return;
      setState(() => _tokenIndex = (_tokenIndex + 1) % _tokens.length);
      _scheduleNext();
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_paused) _scheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Vollbild Reader
          Positioned.fill(
            child: _paragraphPreview
                ? _ParagraphPreview(tokens: _tokens)
                : GestureDetector(
                    onTap: () {
                      _timer?.cancel();
                      setState(() => _paused = !_paused);
                      if (!_paused) _scheduleNext();
                    },
                    child: Stack(
                      children: [
                        RsvpDisplay(
                          token: _tokens[_tokenIndex],
                          settings: SettingsService.instance,
                        ),
                        if (_paused)
                          const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white24,
                              size: 48,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Transparentes Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.35,
            child: Column(
              children: [
                // Page Dots
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final active = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),

                // Panel-Inhalt
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _PausenPanel(
                        onSettingsChanged: _restartTimer,
                        onParagraphModeChanged: (val) {
                          _timer?.cancel();
                          setState(() {
                            _paragraphPreview = val;
                            if (!val && !_paused) _scheduleNext();
                          });
                        },
                      ),
                      const _FarbprofilePanel(),
                      const _OrpFarbenPanel(),
                      const _FontsPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paragraph Preview
// ─────────────────────────────────────────────────────────────────────────────

class _ParagraphPreview extends ConsumerWidget {
  final List<WordToken> tokens;
  const _ParagraphPreview({required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsProvider);
    final s = SettingsService.instance;

    // Zweiten Absatz aus Token-Liste extrahieren (erster = Kapitelname)
    final buf = StringBuffer();
    int paraCount = 0;
    for (final t in tokens) {
      if (t.isBlank) continue;
      if (paraCount == 1) {
        if (buf.isNotEmpty && !buf.toString().endsWith('-')) buf.write(' ');
        buf.write(t.raw);
      }
      if (t.isParagraphEnd) {
        paraCount++;
        if (paraCount == 2) break;
      }
    }

    return Container(
      color: s.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: buf.toString(),
                    style: TextStyle(
                      fontFamily: s.fontFamily,
                      fontSize: s.paragraphFontSize,
                      height: s.paragraphLineHeight,
                      color: s.textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Panel 1: Pausen
// ─────────────────────────────────────────────────────────────────────────────

class _PausenPanel extends ConsumerWidget {
  final VoidCallback onSettingsChanged;
  final ValueChanged<bool> onParagraphModeChanged;
  const _PausenPanel({
    required this.onSettingsChanged,
    required this.onParagraphModeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        _SwitchRow(
          label: 'Absatz-Modus',
          value: s.paragraphMode,
          onChanged: (val) async {
            await SettingsService.instance.setParagraphMode(val);
            n.reload();
            onParagraphModeChanged(val);
          },
        ),
        const Divider(color: Colors.white12, height: 16),
        _StepRow(
          label: 'WPM',
          value: s.wpm,
          display: '${s.wpm}',
          step: 10,
          min: 50,
          max: 1000,
          onChanged: (v) {
            n.setWpm(v);
            onSettingsChanged();
          },
        ),
        const Divider(color: Colors.white12, height: 16),
        _SwitchRow(
          label: 'WPM-Skalierung',
          value: s.scalingEnabled,
          onChanged: (v) {
            n.setScalingEnabled(v);
            onSettingsChanged();
          },
        ),
        if (s.scalingEnabled)
          _StepRow(
            label: 'Referenz-WPM',
            value: s.referenceWpm,
            display: '${s.referenceWpm}',
            step: 10,
            min: 50,
            max: 1000,
            onChanged: (v) {
              n.setReferenceWpm(v);
              onSettingsChanged();
            },
          ),
        const Divider(color: Colors.white12, height: 16),
        _StepRow(
          label: 'Komma-Pause',
          value: s.commaMs,
          display: '${s.commaMs}ms',
          step: 25,
          min: 0,
          max: 1000,
          onChanged: (v) {
            n.setCommaMs(v);
            onSettingsChanged();
          },
        ),
        _StepRow(
          label: 'Satz-Pause',
          value: s.sentenceMs,
          display: '${s.sentenceMs}ms',
          step: 25,
          min: 0,
          max: 2000,
          onChanged: (v) {
            n.setSentenceMs(v);
            onSettingsChanged();
          },
        ),
        _StepRow(
          label: 'Absatz-Pause',
          value: s.paragraphMs,
          display: '${s.paragraphMs}ms',
          step: 50,
          min: 0,
          max: 4000,
          onChanged: (v) {
            n.setParagraphMs(v);
            onSettingsChanged();
          },
        ),
        _StepRow(
          label: 'Kapitel-Pause',
          value: s.chapterPauseMs,
          display: '${s.chapterPauseMs}ms',
          step: 100,
          min: 0,
          max: 10000,
          onChanged: (v) {
            n.setChapterPauseMs(v);
            onSettingsChanged();
          },
        ),
        const Divider(color: Colors.white12, height: 16),
        _StepRow(
          label: 'Längenskalierung',
          value: s.lengthScaleFactor,
          display: 'Faktor (%) ${s.lengthScaleFactor}',
          step: 1,
          min: 0,
          max: 10,
          onChanged: (v) {
            n.setLengthScaleFactor(v);
            onSettingsChanged();
          },
        ),
        _StepRow(
          label: 'Skalierung ab',
          value: s.lengthScaleThreshold,
          display: 'ab ${s.lengthScaleThreshold} Zeichen',
          step: 1,
          min: 5,
          max: 20,
          onChanged: (v) {
            n.setLengthScaleThreshold(v);
            onSettingsChanged();
          },
        ),
        const Divider(color: Colors.white12, height: 16),
        const Divider(color: Colors.white12, height: 16),
        const _ApiKeyRow(),
        const SizedBox(height: 24),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push('/orp-editor'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: Colors.white38),
                SizedBox(width: 10),
                Text(
                  'Ausnahmen',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 18, color: Colors.white24),
              ],
            ),
          ),
        ),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        const _ResetColorsRow(),
        const SizedBox(height: 16),
        const _ResetOrpDbRow(),
        const SizedBox(height: 24),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        const _BackupExportRow(),
        const SizedBox(height: 16),
        const _BackupImportRow(),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel 2: Farbprofile
// ─────────────────────────────────────────────────────────────────────────────

class _FarbprofilePanel extends ConsumerStatefulWidget {
  const _FarbprofilePanel();

  @override
  ConsumerState<_FarbprofilePanel> createState() => _FarbprofilePanelState();
}

class _FarbprofilePanelState extends ConsumerState<_FarbprofilePanel> {
  String? _openType; // 'background' | 'spotlight' | 'text'

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile buttons
          Row(
            children: ['a', 'b', 'c', 'd', 'e'].map((p) {
              final isActive = s.activeColorProfile == p;
              final name = s.colorProfileNames[p] ?? p.toUpperCase();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      n.setActiveColorProfile(p);
                      setState(() => _openType = null);
                    },
                    onLongPress: () => _showRenameDialog(context, p, name, n),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white54,
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Color buttons
          Row(
            children: [
              _ColorButton(
                label: 'Hintergrund',
                color: s.backgroundColor,
                isOpen: _openType == 'background',
                onTap: () => setState(
                  () => _openType = _openType == 'background'
                      ? null
                      : 'background',
                ),
              ),
              const SizedBox(width: 6),
              _ColorButton(
                label: 'Spotlight',
                color: s.spotlightColor,
                isOpen: _openType == 'spotlight',
                onTap: () => setState(
                  () =>
                      _openType = _openType == 'spotlight' ? null : 'spotlight',
                ),
              ),
              const SizedBox(width: 6),
              _ColorButton(
                label: 'Text',
                color: s.textColor,
                isOpen: _openType == 'text',
                onTap: () => setState(
                  () => _openType = _openType == 'text' ? null : 'text',
                ),
              ),
            ],
          ),

          // Inline HSL
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _openType == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: HslSliders(
                      key: ValueKey(_openType),
                      initialColor: _colorFor(_openType!, s),
                      onChanged: (c) => _applyColor(_openType!, c, n),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String type, SettingsState s) {
    switch (type) {
      case 'background':
        return s.backgroundColor;
      case 'spotlight':
        return s.spotlightColor;
      default:
        return s.textColor;
    }
  }

  void _applyColor(String type, Color c, SettingsNotifier n) {
    switch (type) {
      case 'background':
        n.setBackgroundColor(c);
        break;
      case 'spotlight':
        n.setSpotlightColor(c);
        break;
      case 'text':
        n.setTextColor(c);
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel 3: ORP-Farben
// ─────────────────────────────────────────────────────────────────────────────

class _OrpFarbenPanel extends ConsumerStatefulWidget {
  const _OrpFarbenPanel();

  @override
  ConsumerState<_OrpFarbenPanel> createState() => _OrpFarbenPanelState();
}

class _OrpFarbenPanelState extends ConsumerState<_OrpFarbenPanel> {
  int? _openSlot;

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final service = SettingsService.instance;
    final n = ref.read(settingsProvider.notifier);
    final activeSlot = service.activeOrpColorSlot;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          ...List.generate(
            2,
            (row) => Padding(
              padding: EdgeInsets.only(bottom: row == 0 ? 10 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (col) {
                  final slot = row * 6 + col;
                  final color = service.orpPaletteColor(slot);
                  final isActive = slot == activeSlot;
                  final isOpen = slot == _openSlot;
                  return GestureDetector(
                    onTap: () async {
                      await service.setActiveOrpColorSlot(slot);
                      n.reload();
                      setState(() => _openSlot = isOpen ? null : slot);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? Colors.white
                              : isOpen
                              ? Colors.white54
                              : Colors.white24,
                          width: isActive ? 3 : 1.5,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _openSlot == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: HslSliders(
                      key: ValueKey(_openSlot),
                      initialColor: service.orpPaletteColor(_openSlot!),
                      onChanged: (c) async {
                        await service.setOrpPaletteColor(_openSlot!, c);
                        await service.setActiveOrpColorSlot(_openSlot!);
                        n.reload();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel 4: Fonts
// ─────────────────────────────────────────────────────────────────────────────

class _FontsPanel extends ConsumerStatefulWidget {
  const _FontsPanel();

  @override
  ConsumerState<_FontsPanel> createState() => _FontsPanelState();
}

class _FontsPanelState extends ConsumerState<_FontsPanel> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final service = SettingsService.instance;

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: SettingsService.allFonts.length,
      itemBuilder: (context, i) {
        final font = SettingsService.allFonts[i];
        final isActive = s.fontFamily == font;
        final selectedFonts = service.selectedFonts;
        final isSelected = selectedFonts.contains(font);
        final isLastSelected = isSelected && selectedFonts.length <= 2;

        return InkWell(
          onTap: () async {
            await service.setFontFamily(font);
            n.reload();
          },
          onLongPress: isLastSelected
              ? null
              : () async {
                  final current = service.selectedFonts.toList();
                  if (isSelected) {
                    current.remove(font);
                  } else {
                    current.add(font);
                  }
                  await service.setSelectedFonts(current);
                  n.reload();
                  setState(() {});
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    font,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 20,
                      color: isActive ? Colors.white : Colors.white70,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(
                    Icons.play_arrow,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.6)
                      : Colors.white24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ColorButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isOpen;
  final VoidCallback onTap;

  const _ColorButton({
    required this.label,
    required this.color,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isOpen
                ? Colors.white12
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: isOpen
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isOpen ? Icons.expand_less : Icons.expand_more,
                size: 13,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label, display;
  final int value, step, min, max;
  final ValueChanged<int> onChanged;

  const _StepRow({
    required this.label,
    required this.value,
    required this.display,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Colors.white54),
            onPressed: value <= min
                ? null
                : () => onChanged((value - step).clamp(min, max)),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: 80,
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Colors.white54),
            onPressed: value >= max
                ? null
                : () => onChanged((value + step).clamp(min, max)),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          // Reiner Tap-Button statt Switch: Switch hat einen eingebauten
          // Drag-Erkenner, der mit dem horizontalen Wisch-Wechsel des
          // umgebenden PageView kollidiert. Ein simpler Tap-Only-Button
          // konkurriert nicht mit der Wisch-Geste.
          GestureDetector(
            onTap: () => onChanged(!value),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 68,
              height: 32,
              decoration: BoxDecoration(
                color: value ? primary.withValues(alpha: 0.2) : Colors.white12,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: value ? primary : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  value ? 'An' : 'Aus',
                  style: TextStyle(
                    color: value ? primary : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyRow extends StatefulWidget {
  const _ApiKeyRow();

  @override
  State<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends State<_ApiKeyRow> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: SettingsService.instance.claudeApiKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = SettingsService.instance.claudeApiKey.isNotEmpty;

    if (!_editing) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Claude API-Key',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _editing = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                hasKey ? '••••••••' : 'Nicht gesetzt',
                style: TextStyle(
                  color: hasKey ? Colors.white54 : context.colors.danger,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Claude API-Key',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white12,
            hintText: 'sk-ant-...',
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text(
                'Abbrechen',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                await SettingsService.instance.setClaudeApiKey(
                  _ctrl.text.trim(),
                );
                setState(() => _editing = false);
              },
              child: Text(
                'Speichern',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void _showRenameDialog(
  BuildContext context,
  String profile,
  String currentName,
  SettingsNotifier notifier,
) {
  final controller = TextEditingController(text: currentName);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colors.surfaceElevated,
      title: const Text(
        'Profil umbenennen',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () {
            notifier.setColorProfileName(profile, controller.text.trim());
            Navigator.pop(ctx);
          },
          child: Text(
            'Speichern',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}

class _ResetColorsRow extends ConsumerWidget {
  const _ResetColorsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.colors.surfaceElevated,
            title: const Text(
              'Farben zurücksetzen',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Alle Farbprofile und die ORP-Palette werden auf die Standardwerte zurückgesetzt.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Zurücksetzen',
                  style: TextStyle(color: context.colors.danger),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await SettingsService.instance.resetAllColors();
          ref.read(settingsProvider.notifier).reload();
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.refresh, size: 18, color: Colors.white38),
            SizedBox(width: 10),
            Text(
              'Alle Farben zurücksetzen',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetOrpDbRow extends ConsumerWidget {
  const _ResetOrpDbRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.colors.surfaceElevated,
            title: const Text(
              'ORP-Datenbank zurücksetzen',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Alle gespeicherten ORP-Einträge und Token-Caches werden gelöscht. '
              'Bücher werden beim nächsten Öffnen neu verarbeitet.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Zurücksetzen',
                  style: TextStyle(color: context.colors.danger),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await OrpDao().clearOrpEntries();
          await TokenCacheDao().deleteAllCaches();
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.storage_outlined, size: 18, color: Colors.white38),
            SizedBox(width: 10),
            Text(
              'ORP-Datenbank zurücksetzen',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
class _BackupExportRow extends ConsumerStatefulWidget {
  const _BackupExportRow();

  @override
  ConsumerState<_BackupExportRow> createState() => _BackupExportRowState();
}

class _BackupExportRowState extends ConsumerState<_BackupExportRow> {
  bool _running = false;

  Future<void> _export() async {
    setState(() => _running = true);
    try {
      await BackupService().exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _running ? null : _export,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.upload_outlined, size: 18, color: Colors.white38),
            const SizedBox(width: 10),
            const Text(
              'Backup exportieren',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const Spacer(),
            if (_running)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackupImportRow extends ConsumerStatefulWidget {
  const _BackupImportRow();

  @override
  ConsumerState<_BackupImportRow> createState() => _BackupImportRowState();
}

class _BackupImportRowState extends ConsumerState<_BackupImportRow> {
  bool _running = false;

  Future<void> _import() async {
    setState(() => _running = true);
    try {
      final result = await BackupService().importBackup();
      if (!mounted) return;
      if (result == null) return; // Abgebrochen
      final message = result.errors.isEmpty
          ? '${result.sessionsImported} Lesesitzungen wiederhergestellt, '
              '${result.phantomBooksCreated} Bücher als Statistik-Platzhalter angelegt, '
              '${result.companionsMerged} Begleiter aktualisiert, '
              '${result.abbreviationsMerged} neue Abkürzungen übernommen.'
          : '${result.errors.length} Fehler:\n${result.errors.join('\n')}';
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.colors.surfaceElevated,
          title: const Text('Backup wiederhergestellt',
              style: TextStyle(color: Colors.white)),
          content: Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _running ? null : _import,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.download_outlined,
                size: 18, color: Colors.white38),
            const SizedBox(width: 10),
            const Text(
              'Backup importieren',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const Spacer(),
            if (_running)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}