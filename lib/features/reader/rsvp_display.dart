import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/word_token.dart';
import '../../core/services/settings_service.dart';

class RsvpDisplay extends StatelessWidget {
  final WordToken? token;
  final SettingsService settings;
  final String imageBasePath;

  const RsvpDisplay({
    super.key,
    required this.token,
    required this.settings,
    this.imageBasePath = '',
  });

  @override
  Widget build(BuildContext context) {
    if (token != null && token!.isImage) {
      final file = File('$imageBasePath/${token!.imageKey}');
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Center(
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.contain)
                : const Icon(
                    Icons.image_not_supported,
                    color: Colors.white38,
                    size: 64,
                  ),
          ),
        ),
      );
    }

    if (token == null) {
      return _buildBackground(
        context,
        child: Center(
          child: Text(
            'Bereit',
            style: TextStyle(
              color: settings.textColor.withValues(alpha: 0.4),
              fontSize: settings.fontSize,
            ),
          ),
        ),
      );
    }

    if (token!.isBlank) {
      return _buildBackground(context, child: const SizedBox());
    }

    if (token!.isChapterTitle) {
      return _buildBackground(
        context,
        child: Center(
          child: Text(
            token!.raw,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: settings.chapterTitleFontSize,
              color: settings.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return _buildBackground(context, child: _buildWord());
  }

  Widget _buildBackground(BuildContext context, {required Widget child}) {
    if (!settings.spotlightEnabled) {
      return Container(color: settings.backgroundColor, child: child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final screenHeight = constraints.maxHeight;
        final spotlightHeight = settings.spotlightHeight.toDouble();
        final topHeight = (screenHeight - spotlightHeight) / 2;

        if (isLandscape) {
          return Container(color: settings.backgroundColor, child: child);
        }

        return Stack(
          children: [
            // Oberer Außenbereich mit Vignette
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      settings.backgroundColor,
                      Color.lerp(settings.backgroundColor, Colors.black, 0.0)!,
                    ],
                  ),
                ),
              ),
            ),
            // Spotlight Mitte
            Positioned(
              top: topHeight,
              left: 0,
              right: 0,
              height: spotlightHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: settings.spotlightColor,
                ),
              ),
            ),
            // Unterer Außenbereich mit Vignette
            Positioned(
              top: topHeight + spotlightHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      settings.backgroundColor,
                      Color.lerp(settings.backgroundColor, Colors.black, 0.0)!,
                    ],
                  ),
                ),
              ),
            ),
            // Content zentriert
            Positioned.fill(child: child),
          ],
        );
      },
    );
  }

  Widget _buildWord() {
    final word = token!.raw;
    final orpIndex = token!.orpIndex.clamp(0, word.length - 1);
    final dotSize = (settings.fontSize * 0.10).clamp(3.0, 6.0);
    final dotSpacing = settings.orpDotSpacing;

    final orpActive = settings.orpEnabled;
    final useCentered = settings.orpCentered;
    final effectiveOrpColor = orpActive ? settings.orpColor : settings.textColor;
    final showDot = orpActive && settings.orpDotEnabled;

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;

        return Stack(
          children: [
            if (useCentered)
              // Zentriert-Modus: ganzes Wort mittig, ORP-Buchstabe bleibt farbig
              Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: word.substring(0, orpIndex),
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize,
                          color: settings.textColor,
                        ),
                      ),
                      TextSpan(
                        text: word.substring(orpIndex, orpIndex + 1),
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize,
                          color: effectiveOrpColor,
                          fontWeight: settings.orpBold
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      TextSpan(
                        text: word.substring(orpIndex + 1),
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize,
                          color: settings.textColor,
                        ),
                      ),
                    ],
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              )
            else
              // ORP-Modus: ORP-Buchstabe an fixer X-Position (Screenmitte)
              Center(
                child: _OrpWordLayoutTextOnly(
                  before: word.substring(0, orpIndex),
                  focus: word.substring(orpIndex, orpIndex + 1),
                  after: word.substring(orpIndex + 1),
                  textColor: settings.textColor,
                  orpColor: effectiveOrpColor,
                  fontSize: settings.fontSize,
                  fontFamily: settings.fontFamily,
                  orpBold: settings.orpBold,
                ),
              ),
            // Dot absolut fixiert unter Screenmitte
            if (showDot)
              Positioned(
                left: centerX - dotSize / 2,
                top: centerY + dotSpacing,
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: effectiveOrpColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrpWordLayoutTextOnly extends StatelessWidget {
  final String before;
  final String focus;
  final String after;
  final Color textColor;
  final Color orpColor;
  final double fontSize;
  final String fontFamily;
  final bool orpBold;
  const _OrpWordLayoutTextOnly({
    required this.before,
    required this.focus,
    required this.after,
    required this.textColor,
    required this.orpColor,
    required this.fontSize,
    required this.fontFamily,
    required this.orpBold,
  });

  TextStyle _style(Color color, [double? size]) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size ?? fontSize,
      color: color,
    );
  }

  double _measureText(String text, double size) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style(Colors.white, size)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 32.0;
    final centerX = screenWidth / 2;

    double actualFontSize = fontSize;
    double beforeWidth = 0, focusWidth = 0, afterWidth = 0;

    while (true) {
      beforeWidth = _measureText(before, actualFontSize);
      focusWidth = _measureText(focus, actualFontSize);
      afterWidth = _measureText(after, actualFontSize);

      final focusLeft = centerX - focusWidth / 2;
      final beforeLeft = focusLeft - beforeWidth;
      final afterRight = focusLeft + focusWidth + afterWidth;

      final overflowsLeft = beforeLeft < padding / 2;
      final overflowsRight = afterRight > screenWidth - padding / 2;

      if ((!overflowsLeft && !overflowsRight) || actualFontSize <= 10) break;
      actualFontSize -= 1;
    }

    final focusLeft = centerX - focusWidth / 2;
    final beforeLeft = focusLeft - beforeWidth;
    final afterLeft = focusLeft + focusWidth;

    final wordHeight = actualFontSize * 1.2;

    return SizedBox(
      width: screenWidth,
      height: wordHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: beforeLeft,
            top: 0,
            child: Text(
              before,
              style: _style(textColor, actualFontSize),
              textScaler: TextScaler.noScaling,
            ),
          ),
          Positioned(
            left: focusLeft,
            top: 0,
            child: Text(
              focus,
              style: _style(orpColor, actualFontSize).copyWith(
                fontWeight: orpBold ? FontWeight.bold : FontWeight.normal,
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
          Positioned(
            left: afterLeft,
            top: 0,
            child: Text(
              after,
              style: _style(textColor, actualFontSize),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ],
      ),
    );
  }
}
