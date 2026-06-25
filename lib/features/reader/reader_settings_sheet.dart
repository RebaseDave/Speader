import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/settings_service.dart';
import '../settings/settings_provider.dart';

class ReaderSettingsSheet extends ConsumerWidget {
  final bool paragraphMode;
  const ReaderSettingsSheet({super.key, this.paragraphMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final service = SettingsService.instance;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      // Max 40% der Bildschirmhöhe damit die Schrift sichtbar bleibt
      constraints: BoxConstraints(maxHeight: screenHeight * 0.40),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Scrollbarer Inhalt
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Farbprofil
                  const SizedBox(height: 8),
                  const Text(
                    'Farbprofil',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['a', 'b', 'c', 'd', 'e'].map((profile) {
                      final isActive = settings.activeColorProfile == profile;
                      final name = service.colorProfileName(profile);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () async {
                              await service.setActiveColorProfile(profile);
                              ref.read(settingsProvider.notifier).reload();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 11,
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
                        ),
                      );
                    }).toList(),
                  ),

                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),

                  // Schriftgröße
                  const Text(
                    'Schriftgröße',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (paragraphMode) {
                            final newSize =
                                (settings.paragraphFontSize - 1).clamp(12.0, 40.0);
                            await service.setParagraphFontSize(newSize);
                          } else {
                            final newSize =
                                (settings.fontSize - 1).clamp(16.0, 60.0);
                            await service.setFontSize(newSize);
                          }
                          ref.read(settingsProvider.notifier).reload();
                        },
                        icon: const Icon(Icons.remove, color: Colors.white),
                      ),
                      Text(
                        paragraphMode
                            ? '${settings.paragraphFontSize.round()}'
                            : '${settings.fontSize.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (paragraphMode) {
                            final newSize =
                                (settings.paragraphFontSize + 1).clamp(12.0, 40.0);
                            await service.setParagraphFontSize(newSize);
                          } else {
                            final newSize =
                                (settings.fontSize + 1).clamp(16.0, 60.0);
                            await service.setFontSize(newSize);
                          }
                          ref.read(settingsProvider.notifier).reload();
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),

                  // Schriftart
                  const Text(
                    'Schriftart',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _FontSelector(
                    currentFont: settings.fontFamily,
                    onSelected: (font) async {
                      await service.setFontFamily(font);
                      ref.read(settingsProvider.notifier).reload();
                    },
                  ),

                  if (paragraphMode) ...[
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    const Text(
                      'Zeilenabstand',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final newH = (settings.paragraphLineHeight - 0.1)
                                .clamp(1.2, 2.5);
                            await service.setParagraphLineHeight(newH);
                            ref.read(settingsProvider.notifier).reload();
                          },
                          icon: const Icon(Icons.remove, color: Colors.white),
                        ),
                        Text(
                          settings.paragraphLineHeight.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final newH = (settings.paragraphLineHeight + 0.1)
                                .clamp(1.2, 2.5);
                            await service.setParagraphLineHeight(newH);
                            ref.read(settingsProvider.notifier).reload();
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ],

                  if (!paragraphMode) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    // ORP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ORP',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Switch(
                          value: settings.orpEnabled,
                          onChanged: (val) async {
                            await service.setOrpEnabled(val);
                            ref.read(settingsProvider.notifier).reload();
                          },
                          activeTrackColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ],
                    ),
                    if (settings.orpEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ORP fett',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Switch(
                            value: settings.orpBold,
                            onChanged: (val) async {
                              await service.setOrpBold(val);
                              ref.read(settingsProvider.notifier).reload();
                            },
                            activeTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ORP Punkt',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Switch(
                            value: settings.orpDotEnabled,
                            onChanged: (val) async {
                              await service.setOrpDotEnabled(val);
                              ref.read(settingsProvider.notifier).reload();
                            },
                            activeTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        ],
                      ),
                      if (settings.orpDotEnabled) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Abstand',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${settings.orpDotSpacing.round()}px',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.orpDotSpacing,
                          min: 0.0,
                          max: 50.0,
                          divisions: 50,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) async {
                            await service.setOrpDotSpacing(val);
                            ref.read(settingsProvider.notifier).reload();
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      ...List.generate(2, (row) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (col) {
                              final slot = row * 6 + col;
                              final color = service.orpPaletteColor(slot);
                              final isActive =
                                  color.toARGB32() ==
                                  settings.orpColor.toARGB32();
                              return GestureDetector(
                                onTap: () async {
                                  await service.setActiveOrpColorSlot(slot);
                                  ref.read(settingsProvider.notifier).reload();
                                },
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white24,
                                      width: isActive ? 3 : 1.5,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 8),
                    // Zentriert
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Zentriert',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Switch(
                          value: settings.orpCentered,
                          onChanged: (val) async {
                            await ref
                                .read(settingsProvider.notifier)
                                .setOrpCentered(val);
                          },
                          activeTrackColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    // Spotlight
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Spotlight',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Switch(
                          value: settings.spotlightEnabled,
                          onChanged: (val) async {
                            await service.setSpotlightEnabled(val);
                            ref.read(settingsProvider.notifier).reload();
                          },
                          activeTrackColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ],
                    ),
                    if (settings.spotlightEnabled) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Spotlight-Höhe',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  final newH = (settings.spotlightHeight - 10)
                                      .clamp(40, 400);
                                  await service.setSpotlightHeight(newH);
                                  ref.read(settingsProvider.notifier).reload();
                                },
                                icon: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${settings.spotlightHeight}px',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final newH = (settings.spotlightHeight + 10)
                                      .clamp(40, 400);
                                  await service.setSpotlightHeight(newH);
                                  ref.read(settingsProvider.notifier).reload();
                                },
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],

                  if (!paragraphMode) ...[
                    const SizedBox(height: 8),
                    // Zentriert (unabhängig von ORP)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Zentriert',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Switch(
                          value: settings.orpCentered,
                          onChanged: (val) async {
                            await ref
                                .read(settingsProvider.notifier)
                                .setOrpCentered(val);
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    // Spotlight
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Spotlight',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Switch(
                          value: settings.spotlightEnabled,
                          onChanged: (val) async {
                            await service.setSpotlightEnabled(val);
                            ref.read(settingsProvider.notifier).reload();
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    if (settings.spotlightEnabled) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Spotlight-Höhe',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  final newH = (settings.spotlightHeight - 10)
                                      .clamp(40, 400);
                                  await service.setSpotlightHeight(newH);
                                  ref.read(settingsProvider.notifier).reload();
                                },
                                icon: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${settings.spotlightHeight}px',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final newH = (settings.spotlightHeight + 10)
                                      .clamp(40, 400);
                                  await service.setSpotlightHeight(newH);
                                  ref.read(settingsProvider.notifier).reload();
                                },
                                icon: const Icon(
                                    Icons.add, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSelector extends StatelessWidget {
  final String currentFont;
  final ValueChanged<String> onSelected;

  const _FontSelector({required this.currentFont, required this.onSelected});

  static List<String> get _fonts => SettingsService.instance.selectedFonts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _fonts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final font = _fonts[index];
          final isActive = currentFont == font;
          return GestureDetector(
            onTap: () => onSelected(font),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                font,
                style: TextStyle(
                  fontFamily: font,
                  color: isActive ? Colors.white : Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
