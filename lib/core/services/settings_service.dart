import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  // Standardwerte
  static const int defaultWpm = 300;
  static const int defaultBackgroundColor = 0xFF121212;
  static const int defaultTextColor = 0xFFEEEEEE;
  static const int defaultOrpColor = 0xFFE53935;
  static const List<int> defaultOrpColors = [
    0xFFB03030, // Weinrot
    0xFF2E7048, // Tannengrün
    0xFF2E5E9E, // Kornblumenblau
    0xFF9E4820, // Terrakotta
    0xFF6A3890, // Amethyst
    0xFF1E7878, // Petrol
    // 6 für Nacht – abgestimmt auf #5FA9B9 (gleiche Sättigung & Helligkeit)
    0xFFBA8C5E, // Karamell (H=30°)
    0xFF8CBA5E, // Salbeigelb (H=90°)
    0xFF5EBA8C, // Smaragdmint (H=150°)
    0xFF5E8CBA, // Stahlblau (H=210°)
    0xFF8C5EBA, // Violett (H=270°)
    0xFFBA5E8C, // Mauve (H=330°)
  ];
  static const bool defaultOrpBold = false;
  static const bool defaultOrpEnabled = true;
  static const bool defaultOrpCentered = false;
  static const bool defaultOrpDotEnabled = true;
  static const double defaultOrpDotSpacing = 25;
  static const String defaultFontFamily = 'Nunito';
  static const List<String> allFonts = [
    'Inter',
    'Readex',
    'Nunito',
    'Atkinson',
    'Lexie',
    'Cause',
    'Literata',
    'Lora',
    'Baskerville',
    'Zilla'
  ];
  static const List<String> defaultSelectedFonts = [
    'Nunito',
    'Lexie',
    'Readex',
    'Literata',
  ];
  static const double defaultFontSize = 30.0;
  static const int defaultChapterPauseMs = 2500;
  static const int defaultMinDisplayMs = 50;
  static const double defaultChapterTitleFontSize = 30.0;
  static const int defaultReferenceWpm = 300;
  static const int defaultSentenceMs = 250;
  static const int defaultParagraphMs = 500;
  static const int defaultCommaMs = 100;
  static const int defaultLengthScaleThreshold = 13;
  static const int defaultLengthScaleFactor = 3;
  static const bool defaultScalingEnabled = true;
  static const String defaultActiveColorProfile = 'a';

  static const Map<String, List<int>> defaultProfileColors = {
    // Dunkle Schrift (helle Profile)
    'a': [
      0xFF8C8880,
      0xFF1A1A1A,
      0xFFB8B4AC,
    ], // Papier: Mittelgrau, Fastschwarz, Hellgrau
    'b': [
      0xFF8C7A62,
      0xFF2A1A08,
      0xFFB0A080,
    ], // Pergament: Warmes Braun, Dunkelbraun, Helles Tan
    // Helle Schrift (dunkle Profile)
    'c': [
      0xFF0D1117,
      0xFFE6EDF3,
      0xFF1C2333,
    ], // Nacht: Tiefes Marine, Kühlweiß, Dunkles Stahlblau
    'd': [
      0xFF111111,
      0xFFE8E6E0,
      0xFF242424,
    ], // Asche: Schwarz, Warmweiß, Anthrazit
    'e': [
      0xFF0B1510,
      0xFFCCD8C4,
      0xFF192B1E,
    ], // Moos: Nachtgrün, Salbei, Dunkelwald
  };

  static const Map<String, String> defaultProfileNames = {
    'a': 'Papier',
    'b': 'Pergament',
    'c': 'Nacht',
    'd': 'Asche',
    'e': 'Moos',
  };

  //Spotlight
  static const bool defaultSpotlightEnabled = true;
  static const int defaultSpotlightHeight = 110;
  static const int defaultSpotlightColor = 0xFF2A2A2A;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get activeColorProfile =>
      _prefs.getString('${_p}active_color_profile') ??
      defaultActiveColorProfile;
  Future<void> setActiveColorProfile(String profile) async {
    await _prefs.setString('${_p}active_color_profile', profile);
  }

  // Präfix für aktuelles Profil
  String get _p => 'p1_';

  // Präfix für aktives Farbprofil
  String get _cp => '${_p}color_${activeColorProfile}_';

  // Farbprofil-Namen
  String colorProfileName(String profile) =>
      _prefs.getString('${_p}color_${profile}_name') ??
      defaultProfileNames[profile] ??
      'Profil ${profile.toUpperCase()}';
  Future<void> setColorProfileName(String profile, String name) async {
    await _prefs.setString('${_p}color_${profile}_name', name);
  }

  // WPM
  int get wpm => _prefs.getInt('${_p}wpm') ?? defaultWpm;
  Future<void> setWpm(int value) async {
    await _prefs.setInt('${_p}wpm', value.clamp(50, 1000));
  }

  // Spotlight (global, nicht profilgebunden)
  bool get spotlightEnabled =>
      _prefs.getBool('${_p}spotlight_enabled') ?? defaultSpotlightEnabled;
  Future<void> setSpotlightEnabled(bool value) async {
    await _prefs.setBool('${_p}spotlight_enabled', value);
  }

  int get spotlightHeight =>
      _prefs.getInt('${_p}spotlight_height') ?? defaultSpotlightHeight;
  Future<void> setSpotlightHeight(int value) async {
    await _prefs.setInt('${_p}spotlight_height', value);
  }

  int _profileDefault(int idx) {
    final colors = defaultProfileColors[activeColorProfile];
    if (colors == null) return defaultProfileColors['a']![idx];
    return colors[idx];
  }

  // Farben (profilgebunden)
  Color get spotlightColor =>
      Color(_prefs.getInt('${_cp}spotlight_color') ?? _profileDefault(2));
  Future<void> setSpotlightColor(Color color) async {
    await _prefs.setInt('${_cp}spotlight_color', color.toARGB32());
  }

  Color get backgroundColor =>
      Color(_prefs.getInt('${_cp}background_color') ?? _profileDefault(0));
  Future<void> setBackgroundColor(Color color) async {
    await _prefs.setInt('${_cp}background_color', color.toARGB32());
  }

  Color get textColor =>
      Color(_prefs.getInt('${_cp}text_color') ?? _profileDefault(1));
  Future<void> setTextColor(Color color) async {
    await _prefs.setInt('${_cp}text_color', color.toARGB32());
  }

  // ORP Farbe (global, nicht profilgebunden)
  Color get orpColor =>
      Color(_prefs.getInt('${_p}orp_color') ?? defaultOrpColor);
  Future<void> setOrpColor(Color color) async {
    await _prefs.setInt('${_p}orp_color', color.toARGB32());
  }

  // ORP Bold (global)
  bool get orpBold => _prefs.getBool('${_p}orp_bold') ?? defaultOrpBold;
  Future<void> setOrpBold(bool value) async {
    await _prefs.setBool('${_p}orp_bold', value);
  }

  bool get orpEnabled =>
      _prefs.getBool('${_p}orp_enabled') ?? defaultOrpEnabled;
  Future<void> setOrpEnabled(bool value) async {
    await _prefs.setBool('${_p}orp_enabled', value);
  }

  bool get orpCentered =>
      _prefs.getBool('${_p}orp_centered') ?? defaultOrpCentered;
  Future<void> setOrpCentered(bool value) async {
    await _prefs.setBool('${_p}orp_centered', value);
  }

  // ORP Dot (global)
  bool get orpDotEnabled =>
      _prefs.getBool('${_p}orp_dot_enabled') ?? defaultOrpDotEnabled;
  Future<void> setOrpDotEnabled(bool value) async {
    await _prefs.setBool('${_p}orp_dot_enabled', value);
  }

  double get orpDotSpacing =>
      _prefs.getDouble('${_p}orp_dot_spacing') ?? defaultOrpDotSpacing;
  Future<void> setOrpDotSpacing(double value) async {
    await _prefs.setDouble('${_p}orp_dot_spacing', value.clamp(0.0, 50.0));
  }

  // Schrift
  String get fontFamily =>
      _prefs.getString('${_p}font_family') ?? defaultFontFamily;
  Future<void> setFontFamily(String value) async {
    await _prefs.setString('${_p}font_family', value);
  }

  // Ausgewählte Fonts für Reader (min 2, max 10)
  List<String> get selectedFonts {
    final stored = _prefs.getString('${_p}selected_fonts');
    if (stored == null || stored.isEmpty) return defaultSelectedFonts;
    final list = stored.split(',').where((f) => allFonts.contains(f)).toList();
    return list.length >= 2 ? list : defaultSelectedFonts;
  }

  Future<void> setSelectedFonts(List<String> fonts) async {
    final valid = fonts.where((f) => allFonts.contains(f)).toList();
    if (valid.length < 2) return;
    final clamped = valid.take(10).toList();
    await _prefs.setString('${_p}selected_fonts', clamped.join(','));
  }

  double get fontSize => _prefs.getDouble('${_p}font_size') ?? defaultFontSize;
  Future<void> setFontSize(double value) async {
    await _prefs.setDouble('${_p}font_size', value);
  }

  double get chapterTitleFontSize =>
      _prefs.getDouble('${_p}chapter_title_font_size') ??
      defaultChapterTitleFontSize;
  Future<void> setChapterTitleFontSize(double value) async {
    await _prefs.setDouble('${_p}chapter_title_font_size', value);
  }

  // Pausen Zeiten
  int get referenceWpm =>
      _prefs.getInt('${_p}reference_wpm') ?? defaultReferenceWpm;
  Future<void> setReferenceWpm(int value) async {
    await _prefs.setInt('${_p}reference_wpm', value.clamp(50, 1000));
  }

  bool get scalingEnabled =>
      _prefs.getBool('${_p}scaling_enabled') ?? defaultScalingEnabled;
  Future<void> setScalingEnabled(bool value) async {
    await _prefs.setBool('${_p}scaling_enabled', value);
  }

  int get sentenceMs => _prefs.getInt('${_p}sentence_ms') ?? defaultSentenceMs;
  Future<void> setSentenceMs(int value) async {
    await _prefs.setInt('${_p}sentence_ms', value);
  }

  int get paragraphMs =>
      _prefs.getInt('${_p}paragraph_ms') ?? defaultParagraphMs;
  Future<void> setParagraphMs(int value) async {
    await _prefs.setInt('${_p}paragraph_ms', value);
  }

  int get commaMs => _prefs.getInt('${_p}comma_ms') ?? defaultCommaMs;
  Future<void> setCommaMs(int value) async {
    await _prefs.setInt('${_p}comma_ms', value);
  }

  // Kapitel
  int get chapterPauseMs =>
      _prefs.getInt('${_p}chapter_pause_ms') ?? defaultChapterPauseMs;
  Future<void> setChapterPauseMs(int value) async {
    await _prefs.setInt('${_p}chapter_pause_ms', value);
  }

  int get lengthScaleThreshold =>
      _prefs.getInt('${_p}length_scale_threshold') ??
      defaultLengthScaleThreshold;
  Future<void> setLengthScaleThreshold(int value) async {
    await _prefs.setInt('${_p}length_scale_threshold', value);
  }

  int get lengthScaleFactor =>
      _prefs.getInt('${_p}length_scale_factor') ?? defaultLengthScaleFactor;
  Future<void> setLengthScaleFactor(int value) async {
    await _prefs.setInt('${_p}length_scale_factor', value);
  }

  // Mindestanzeigedauer
  int get minDisplayMs =>
      _prefs.getInt('${_p}min_display_ms') ?? defaultMinDisplayMs;
  Future<void> setMinDisplayMs(int value) async {
    await _prefs.setInt('${_p}min_display_ms', value);
  }

  // Claude API Key (global, nicht profilgebunden)
  String get claudeApiKey => _prefs.getString('claude_api_key') ?? '';
  Future<void> setClaudeApiKey(String value) async {
    await _prefs.setString('claude_api_key', value);
  }

  // ORP Farbpalette (6 Slots, global)
  Color orpPaletteColor(int slot) {
    final value = _prefs.getInt('orp_palette_$slot');
    if (value != null) return Color(value);
    return Color(defaultOrpColors[slot.clamp(0, 11)]);
  }

  Future<void> setOrpPaletteColor(int slot, Color color) async {
    await _prefs.setInt('orp_palette_$slot', color.toARGB32());
  }

  int get activeOrpColorSlot => _prefs.getInt('active_orp_slot') ?? 0;
  Future<void> setActiveOrpColorSlot(int slot) async {
    await _prefs.setInt('active_orp_slot', slot);
    // Aktive ORP Farbe direkt setzen
    await setOrpColor(orpPaletteColor(slot));
  }

  // Books Read Counter
  int get booksReadCount => _prefs.getInt('books_read_count') ?? 0;
  Future<void> incrementBooksRead() async {
    await _prefs.setInt('books_read_count', booksReadCount + 1);
  }

  // Tagesziel Celebration
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get goalCelebrationShownToday =>
      _prefs.getString('goal_celebration_date') == _todayKey;

  Future<void> markGoalCelebrationShown() async {
    await _prefs.setString('goal_celebration_date', _todayKey);
  }

  // Buch-spezifischer Basis-Overhead (kalibriert)
  double? bookBaseOverhead(int bookId) =>
      _prefs.containsKey('book_${bookId}_base_overhead')
      ? _prefs.getDouble('book_${bookId}_base_overhead')
      : null;

  Future<void> setBookBaseOverhead(int bookId, double value) async {
    await _prefs.setDouble('book_${bookId}_base_overhead', value);
  }

  Future<void> removeBookBaseOverhead(int bookId) async {
    await _prefs.remove('book_${bookId}_base_overhead');
  }

  /// Alle Farbeinstellungen auf Defaults zurücksetzen
  Future<void> resetAllColors() async {
    for (final profile in ['a', 'b', 'c', 'd', 'e']) {
      await _prefs.remove('${_p}color_${profile}_background_color');
      await _prefs.remove('${_p}color_${profile}_text_color');
      await _prefs.remove('${_p}color_${profile}_spotlight_color');
      await _prefs.remove('${_p}color_${profile}_name');
    }
    for (int i = 0; i < 12; i++) {
      await _prefs.remove('orp_palette_$i');
    }
    await _prefs.remove('${_p}orp_color');
    await _prefs.remove('active_orp_slot');
  }

  // Lesemodus
  static const bool defaultParagraphMode = false;
  bool get paragraphMode =>
      _prefs.getBool('${_p}paragraph_mode') ?? defaultParagraphMode;
  Future<void> setParagraphMode(bool value) async {
    await _prefs.setBool('${_p}paragraph_mode', value);
  }

  static const double defaultParagraphLineHeight = 1.8;
  double get paragraphLineHeight =>
      _prefs.getDouble('${_p}paragraph_line_height') ?? defaultParagraphLineHeight;
  Future<void> setParagraphLineHeight(double value) async {
    await _prefs.setDouble('${_p}paragraph_line_height', value.clamp(1.2, 2.5));
  }

  static const double defaultParagraphFontSize = 18.0;
  double get paragraphFontSize =>
      _prefs.getDouble('${_p}paragraph_font_size') ?? defaultParagraphFontSize;
  Future<void> setParagraphFontSize(double value) async {
    await _prefs.setDouble('${_p}paragraph_font_size', value.clamp(12.0, 40.0));
  }
}
