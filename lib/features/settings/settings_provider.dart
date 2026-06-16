import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/settings_service.dart';

class SettingsState {
  final int wpm;
  final Color backgroundColor;
  final Color textColor;
  final Color orpColor;
  final String fontFamily;
  final double fontSize;
  final bool orpBold;
  final bool orpEnabled;
  final double chapterTitleFontSize;
  final int referenceWpm;
  final int sentenceMs;
  final int paragraphMs;
  final int commaMs;
  final int chapterPauseMs;
  final int minDisplayMs;
  final bool scalingEnabled;
  final String activeColorProfile;
  final Map<String, String> colorProfileNames;
  final bool spotlightEnabled;
  final int spotlightHeight;
  final Color spotlightColor;
  final bool orpDotEnabled;
  final double orpDotSpacing;
  final bool orpCentered;
  final int lengthScaleThreshold;
  final int lengthScaleFactor;
  final bool paragraphMode;
  final double paragraphLineHeight;
  final double paragraphFontSize;

  const SettingsState({
    required this.wpm,
    required this.backgroundColor,
    required this.textColor,
    required this.orpColor,
    required this.fontFamily,
    required this.fontSize,
    required this.chapterTitleFontSize,
    required this.orpBold,
    required this.orpEnabled,
    required this.referenceWpm,
    required this.sentenceMs,
    required this.paragraphMs,
    required this.commaMs,
    required this.chapterPauseMs,
    required this.minDisplayMs,
    required this.scalingEnabled,
    required this.activeColorProfile,
    required this.colorProfileNames,
    required this.spotlightEnabled,
    required this.spotlightHeight,
    required this.spotlightColor,
    required this.orpDotEnabled,
    required this.orpDotSpacing,
    required this.orpCentered,
    required this.lengthScaleThreshold,
    required this.lengthScaleFactor,
    required this.paragraphMode,
    required this.paragraphLineHeight,
    required this.paragraphFontSize,
  });

  factory SettingsState.fromService(SettingsService s) {
    return SettingsState(
      wpm: s.wpm,
      backgroundColor: s.backgroundColor,
      textColor: s.textColor,
      orpColor: s.orpColor,
      fontFamily: s.fontFamily,
      fontSize: s.fontSize,
      chapterTitleFontSize: s.chapterTitleFontSize,
      orpBold: s.orpBold,
      orpEnabled: s.orpEnabled,
      referenceWpm: s.referenceWpm,
      sentenceMs: s.sentenceMs,
      paragraphMs: s.paragraphMs,
      commaMs: s.commaMs,
      chapterPauseMs: s.chapterPauseMs,
      minDisplayMs: s.minDisplayMs,
      scalingEnabled: s.scalingEnabled,
      spotlightEnabled: s.spotlightEnabled,
      spotlightHeight: s.spotlightHeight,
      spotlightColor: s.spotlightColor,
      orpDotEnabled: s.orpDotEnabled,
      orpDotSpacing: s.orpDotSpacing,
      orpCentered: s.orpCentered,
      lengthScaleThreshold: s.lengthScaleThreshold,
      lengthScaleFactor: s.lengthScaleFactor,
      paragraphMode: s.paragraphMode,
      paragraphLineHeight: s.paragraphLineHeight,
      paragraphFontSize: s.paragraphFontSize,
      activeColorProfile: s.activeColorProfile,
      colorProfileNames: {
        'a': s.colorProfileName('a'),
        'b': s.colorProfileName('b'),
        'c': s.colorProfileName('c'),
        'd': s.colorProfileName('d'),
        'e': s.colorProfileName('e'),
      },
    );
  }

  SettingsState copyWith({
    int? wpm,
    Color? backgroundColor,
    Color? textColor,
    Color? orpColor,
    String? fontFamily,
    double? fontSize,
    double? chapterTitleFontSize,
    bool? orpBold,
    bool? orpEnabled,
    int? referenceWpm,
    int? sentenceMs,
    int? paragraphMs,
    int? commaMs,
    int? chapterPauseMs,
    int? minDisplayMs,
    bool? scalingEnabled,
    String? activeColorProfile,
    Map<String, String>? colorProfileNames,
    bool? spotlightEnabled,
    int? spotlightHeight,
    Color? spotlightColor,
    bool? orpDotEnabled,
    double? orpDotSpacing,
    bool? orpCentered,
    int? lengthScaleThreshold,
    int? lengthScaleFactor,
    bool? paragraphMode,
    double? paragraphLineHeight,
    double? paragraphFontSize,
  }) {
    return SettingsState(
      wpm: wpm ?? this.wpm,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      orpColor: orpColor ?? this.orpColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      chapterTitleFontSize: chapterTitleFontSize ?? this.chapterTitleFontSize,
      orpBold: orpBold ?? this.orpBold,
      orpEnabled: orpEnabled ?? this.orpEnabled,
      referenceWpm: referenceWpm ?? this.referenceWpm,
      sentenceMs: sentenceMs ?? this.sentenceMs,
      paragraphMs: paragraphMs ?? this.paragraphMs,
      commaMs: commaMs ?? this.commaMs,
      chapterPauseMs: chapterPauseMs ?? this.chapterPauseMs,
      minDisplayMs: minDisplayMs ?? this.minDisplayMs,
      scalingEnabled: scalingEnabled ?? this.scalingEnabled,
      activeColorProfile: activeColorProfile ?? this.activeColorProfile,
      colorProfileNames: colorProfileNames ?? this.colorProfileNames,
      spotlightEnabled: spotlightEnabled ?? this.spotlightEnabled,
      spotlightHeight: spotlightHeight ?? this.spotlightHeight,
      spotlightColor: spotlightColor ?? this.spotlightColor,
      orpDotEnabled: orpDotEnabled ?? this.orpDotEnabled,
      orpDotSpacing: orpDotSpacing ?? this.orpDotSpacing,
      orpCentered: orpCentered ?? this.orpCentered,
      lengthScaleThreshold: lengthScaleThreshold ?? this.lengthScaleThreshold,
      lengthScaleFactor: lengthScaleFactor ?? this.lengthScaleFactor,
      paragraphMode: paragraphMode ?? this.paragraphMode,
      paragraphLineHeight: paragraphLineHeight ?? this.paragraphLineHeight,
      paragraphFontSize: paragraphFontSize ?? this.paragraphFontSize,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  SettingsService get _service => SettingsService.instance;

  @override
  SettingsState build() {
    return SettingsState.fromService(_service);
  }

  Future<void> setWpm(int value) async {
    await _service.setWpm(value);
    state = state.copyWith(wpm: value.clamp(50, 1000));
  }

  Future<void> setBackgroundColor(Color color) async {
    await _service.setBackgroundColor(color);
    state = state.copyWith(backgroundColor: color);
  }

  Future<void> setTextColor(Color color) async {
    await _service.setTextColor(color);
    state = state.copyWith(textColor: color);
  }

  Future<void> setOrpColor(Color color) async {
    await _service.setOrpColor(color);
    state = state.copyWith(orpColor: color);
  }

  Future<void> setActiveColorProfile(String profile) async {
    await _service.setActiveColorProfile(profile);
    // Alle Farben neu laden
    state = SettingsState.fromService(_service);
  }

  Future<void> setColorProfileName(String profile, String name) async {
    await _service.setColorProfileName(profile, name);
    final updated = Map<String, String>.from(state.colorProfileNames);
    updated[profile] = name;
    state = state.copyWith(colorProfileNames: updated);
  }

  //Spotlight Notifier
  Future<void> setSpotlightEnabled(bool value) async {
    await _service.setSpotlightEnabled(value);
    state = state.copyWith(spotlightEnabled: value);
  }

  Future<void> setSpotlightHeight(int value) async {
    await _service.setSpotlightHeight(value);
    state = state.copyWith(spotlightHeight: value);
  }

  Future<void> setSpotlightColor(Color color) async {
    await _service.setSpotlightColor(color);
    state = state.copyWith(spotlightColor: color);
  }

  Future<void> setFontFamily(String value) async {
    await _service.setFontFamily(value);
    state = state.copyWith(fontFamily: value);
  }

  Future<void> setFontSize(double value) async {
    await _service.setFontSize(value);
    state = state.copyWith(fontSize: value);
  }

  Future<void> setChapterTitleFontSize(double value) async {
    await _service.setChapterTitleFontSize(value);
    state = state.copyWith(chapterTitleFontSize: value);
  }

  Future<void> setOrpBold(bool value) async {
    await _service.setOrpBold(value);
    state = state.copyWith(orpBold: value);
  }

  Future<void> setOrpEnabled(bool value) async {
    await _service.setOrpEnabled(value);
    state = state.copyWith(orpEnabled: value);
  }

  Future<void> setOrpDotEnabled(bool value) async {
    await _service.setOrpDotEnabled(value);
    state = state.copyWith(orpDotEnabled: value);
  }

  Future<void> setOrpDotSpacing(double value) async {
    await _service.setOrpDotSpacing(value);
    state = state.copyWith(orpDotSpacing: value);
  }

  Future<void> setOrpCentered(bool value) async {
    await _service.setOrpCentered(value);
    state = state.copyWith(orpCentered: value);
  }

  Future<void> setLengthScaleThreshold(int value) async {
    await _service.setLengthScaleThreshold(value);
    state = state.copyWith(lengthScaleThreshold: value);
  }

  Future<void> setLengthScaleFactor(int value) async {
    await _service.setLengthScaleFactor(value);
    state = state.copyWith(lengthScaleFactor: value);
  }

  Future<void> setReferenceWpm(int value) async {
    await _service.setReferenceWpm(value);
    state = state.copyWith(referenceWpm: value);
  }

  Future<void> setSentenceMs(int value) async {
    await _service.setSentenceMs(value);
    state = state.copyWith(sentenceMs: value);
  }

  Future<void> setParagraphMs(int value) async {
    await _service.setParagraphMs(value);
    state = state.copyWith(paragraphMs: value);
  }

  Future<void> setCommaMs(int value) async {
    await _service.setCommaMs(value);
    state = state.copyWith(commaMs: value);
  }

  Future<void> setChapterPauseMs(int value) async {
    await _service.setChapterPauseMs(value);
    state = state.copyWith(chapterPauseMs: value);
  }

  Future<void> setMinDisplayMs(int value) async {
    await _service.setMinDisplayMs(value);
    state = state.copyWith(minDisplayMs: value);
  }

  Future<void> setScalingEnabled(bool value) async {
    await _service.setScalingEnabled(value);
    state = state.copyWith(scalingEnabled: value);
  }

  Future<void> setParagraphMode(bool value) async {
    await _service.setParagraphMode(value);
    state = state.copyWith(paragraphMode: value);
  }

  Future<void> setParagraphLineHeight(double value) async {
    await _service.setParagraphLineHeight(value);
    state = state.copyWith(paragraphLineHeight: value);
  }

  Future<void> setParagraphFontSize(double value) async {
    await _service.setParagraphFontSize(value);
    state = state.copyWith(paragraphFontSize: value);
  }

  void reload() {
    state = SettingsState.fromService(SettingsService.instance);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
