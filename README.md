# Speader – Focus Reader

Persönlicher RSVP-Reader für Android, entwickelt in Flutter.
Fokus auf Lesefluss, Anpassbarkeit und Gamification – ohne Cloud-Abhängigkeiten.

## Features

**Lesen**
- RSVP-Modus — Wort-für-Wort-Anzeige mit konfigurierbarem WPM, Pausen und ORP-Highlighting
- Paragraph-Modus — Absatzweise Navigation mit Satz-Fokus und Auto-Play
- Spotlight — konfigurierbare Fokuszone im RSVP-Modus
- WPM-Kalibrierung und Längenskalierung

**Inhalte**
- EPUB- und TXT-Import via Share Intent
- Kapitelnavigation mit Fortschrittsanzeige
- Token-Caching für schnelles Laden
- KI-gestützte Kapitelzusammenfassungen und Worterklärungen (Claude API)

**Gamification**
- 11 sammelbare Companions mit XP-Progression und Level-Ups
- Streak-System mit Tageszielen
- Lesestatistiken: WPM-Verlauf, Wochenziele, Sessiontracking, Heatmap

**Anpassung**
- 15 Schriftarten
- 5 Farbprofile mit HSL-Slider
- ORP-Farbpalette (12 Slots)
- Satzenden-Ausnahmen konfigurierbar

## Tech Stack

| | |
|---|---|
| Framework | Flutter / Dart |
| State Management | Riverpod |
| Navigation | go_router |
| Datenbank | SQLite (sqflite) |
| KI | Claude API (Anthropic) |

## Setup

Voraussetzung: Flutter SDK ≥ 3.32

```bash
flutter pub get
flutter run
```

## Konfiguration

KI-Features (Kapitelzusammenfassungen, Worterklärungen) benötigen einen
[Anthropic API-Key](https://console.anthropic.com), der in den Einstellungen hinterlegt wird.

## Architektur

```
lib/
├── core/
│   ├── database/       DAOs, DatabaseHelper
│   ├── models/         Book, WordToken, ReadSession, …
│   ├── services/       SettingsService, StreakService, ClaudeService
│   └── widgets/        HslSliders, …
├── epub/               EPUB-Parser, Importer
├── rsvp/               RsvpEngine, DisplayTimer, OrpCalculator
└── features/
    ├── library/        Bibliothek, Archiv, Statistiken
    ├── reader/         RSVP- & Paragraph-Reader, Overlay, Settings
    ├── settings/       Config Screen, Settings Provider
    ├── companions/     Companion Screen, Collection, Level-Up
    └── orp_editor/     Satzenden-Ausnahmen
```

## Hinweis

Persönliches Projekt, nicht für öffentliche Distribution gedacht.
