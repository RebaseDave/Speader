import 'package:flutter/material.dart';

/// Zentrale Farbpalette für Speader.
///
/// Diese Extension ist der EINE Knopf, über den das gesamte App-Theme
/// gesteuert wird (main.dart -> ThemeData -> extensions: [AppColors.dark]).
/// Wer eine Farbe im Interface ändern will, ändert sie NUR hier – nicht
/// in den einzelnen Feature-Dateien.
///
/// Ausnahmen, die absichtlich NICHT über diese Klasse laufen:
/// - Alle Colors.white-Abstufungen (white70/54/38/24/12/10) bleiben
///   projektweit hart codiert, siehe userPreferences-Entscheidung.
/// - Der Hue-Regenbogen in hsl_sliders.dart (reine Spektralfarben,
///   kein Theme-Bezug).
/// - Die Flamm-Partikel in goal_celebration_overlay.dart (Spezialeffekt,
///   bewusst hart codiert gelassen).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// App-weiter Haupthintergrund. Scaffold.backgroundColor & AppBar-Hintergrund
  /// auf praktisch jedem Screen (Library, Reader, Scoreboard-Screens,
  /// Companion-Screen, Config, Archive-Setup etc.). Bisher 0xFF0A1628.
  final Color background;

  /// Karten-/Container-Hintergrund eine Stufe heller als [background].
  /// Genutzt für: Explain/Dictionary/Summary-Sheets, Companion-Karten,
  /// Scoreboard-Game-Type-Karten, Sticky-Footer in Basic/Wizard-Scoreboard,
  /// Wizard-Header, Tabellen-Header-Zeile, Ping-Pong-Score-Container.
  /// Bisher 0xFF112240.
  final Color surface;

  /// Hintergrund für Dialoge/BottomSheets, die über dem Content schweben
  /// (AlertDialogs zum Löschen/Bestätigen, Reader-Settings-Sheet,
  /// Dictionary-Eingabedialog, Config-Umbenennen/Zurücksetzen-Dialoge,
  /// Session-löschen-Dialog in library_screen). Bisher 0xFF1A1A2E
  /// (an einer Stelle in library_screen war es 0xFF16213E – bewusst
  /// vereinheitlicht statt eigenes Mini-Token).
  final Color surfaceElevated;

  /// Etwas helleres Feld speziell für Text-Eingaben innerhalb eines
  /// bereits [surface]-farbenen Containers (z.B. Punkte-Eingabefelder
  /// im Footer von Basic- und Wizard-Scoreboard). Sorgt dafür, dass das
  /// Eingabefeld sich vom umgebenden Footer abhebt. Bisher 0xFF1A2A40.
  final Color surfaceInput;

  /// Dunklere Variante für einzelne hervorgehobene Zeilen/Flächen,
  /// z.B. die Totals-Zeile in der Basic-Scoreboard-Tabelle. Bisher 0xFF0D1C35.
  final Color surfaceSubtle;

  /// Primäre Akzentfarbe der App (Cyan). Steuert: ColorScheme.primary/secondary,
  /// Switch/Slider/TextButton-Theme in main.dart, aktive Companion-Rahmen
  /// und -Glow, "Sammlung"-Button-Outline, normale (nicht-prestige) Level-Farbe
  /// bei Companions. Bisher 0xFF00B4D8.
  final Color accent;

  /// Grün für "erreicht/erfolgreich": Streak-Banner bei erreichtem Tagesziel,
  /// Wochen-Balkendiagramm & Zahl bei erreichtem Ziel, Statistik-Legende
  /// "Tagesziel", Heatmap-Startfarbe (100% des Ziels), WPM-Chart-Zielinie
  /// & Absatzmodus-Linienfarbe. Bisher 0xFF4CAF50.
  final Color success;

  /// Dunkleres Grün als Endpunkt des Heatmap-Farbverlaufs bei 500% des
  /// Tagesziels (siehe _heatColor in stats_sheet.dart). Bisher 0xFF1B5E20.
  final Color successDark;

  /// Gold für Prestige/Feier-Momente: Prestige-Level-Icon & -Text bei
  /// Companions (Screen, Collection-Sheet, Level-Up-Overlay). Bisher 0xFFFFD700.
  final Color gold;

  /// Rot für destruktive Aktionen & Fehlerzustände: Lösch-Icons/-Hintergründe
  /// bei Dismissible-Swipes (Bücher, Sessions, Spiele), "Löschen/Entfernen/
  /// Zurücksetzen"-Buttons in Bestätigungsdialogen, ORP-Fokuswort-Hervorhebung,
  /// "API-Key nicht gesetzt"-Hinweis in config_screen. Bisher redAccent /
  /// 0xFFE53935 / Colors.red.shade300 (Farbton vereinheitlicht).
  final Color danger;

  /// Orange für Warnungen & "brennende" Motive: Streak-Flamme (Banner &
  /// Stats-Sheet) wenn aktiv, Ping-Pong-Spieltyp-Karte, Flamm-Glow/-Text im
  /// Goal-Celebration-Overlay (die einzelnen Konfetti-Partikel bleiben
  /// bewusst hart codiert). Bisher Colors.orange.
  final Color warning;

  /// Lila für den Wizard-Spieltyp: Game-Type-Karte, gesamter Ansage-/
  /// Stiche-Text im Wizard-Scoreboard-Screen. Ursprünglich zwei leicht
  /// unterschiedliche Töne (Colors.deepPurple[300] und ein separates
  /// pastelliges 0xFFB39DDB) – bewusst auf einen Ton vereinheitlicht statt
  /// zwei Shade-Varianten zu pflegen. Bisher Colors.deepPurple.
  final Color purpleAccent;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceInput,
    required this.surfaceSubtle,
    required this.accent,
    required this.success,
    required this.successDark,
    required this.gold,
    required this.danger,
    required this.warning,
    required this.purpleAccent,
  });

  static const dark = AppColors(
    background: Color(0xFF0A1628),
    surface: Color(0xFF112240),
    surfaceElevated: Color(0xFF1A1A2E),
    surfaceInput: Color(0xFF1A2A40),
    surfaceSubtle: Color(0xFF0D1C35),
    accent: Color(0xFF00B4D8),
    success: Color(0xFF4CAF50),
    successDark: Color(0xFF1B5E20),
    gold: Color(0xFFFFD700),
    danger: Color(0xFFE53935),
    warning: Colors.orange,
    purpleAccent: Colors.deepPurple,
  );

  /// Test-Theme "Midnight Sage" – entspanntes, tiefes Moos-/Salbegrün.
  /// Extrem augenschonend, organisch und ruhig für nächtliche Lese-Sessions.
   static const midnightSage = AppColors(
    background: Color(0xFF111815),       // Sehr dunkles, fast schwarzes Waldgrün
    surface: Color(0xFF1B2621),          // Dunkles Salbeigrün für Container
    surfaceElevated: Color(0xFF24332C),  // Etwas helleres Grün für Dialoge/Sheets
    surfaceInput: Color(0xFF2C3F36),     // Deutlich abgesetztes Feld für Inputs
    surfaceSubtle: Color(0xFF0C110F),    // Extrem dunkler Ton für Tabellen-Totals
    accent: Color(0xFF81B29A),           // Entspanntes, mattes Mintgrün/Salbei als Hauptakzent
    success: Color(0xFF6B8E23),          // Gedämpftes Olive/Grün für Ziele
    successDark: Color(0xFF3B4F18),      // Dunkles Waldmeistergrün für d. Heatmap-Endpunkt
    gold: Color(0xFFE5BA73),             // Sanftes, mattes Gold für Prestige (weniger grell)
    danger: Color(0xFFC85A53),           // Pastelliges Terrakotta-Rot für destruktive Aktionen
    warning: Color(0xFFCC7A3D),          // Kräftigeres Bernstein-Orange, deutlich von gold abgesetzt
    purpleAccent: Color(0xFF9B8CB4),     // Gedämpftes Lavendel für den Wizard-Spieltyp
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceInput,
    Color? surfaceSubtle,
    Color? accent,
    Color? success,
    Color? successDark,
    Color? gold,
    Color? danger,
    Color? warning,
    Color? purpleAccent,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceInput: surfaceInput ?? this.surfaceInput,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      successDark: successDark ?? this.successDark,
      gold: gold ?? this.gold,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      purpleAccent: purpleAccent ?? this.purpleAccent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceInput: Color.lerp(surfaceInput, other.surfaceInput, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successDark: Color.lerp(successDark, other.successDark, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      purpleAccent: Color.lerp(purpleAccent, other.purpleAccent, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}