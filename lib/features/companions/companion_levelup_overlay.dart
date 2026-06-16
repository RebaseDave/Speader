import 'package:flutter/material.dart';
import 'companion.dart';
import 'companion_definition.dart';

class CompanionLevelUpOverlay extends StatefulWidget {
  final int slot;
  final int newLevel;
  final VoidCallback onDone;

  const CompanionLevelUpOverlay({
    super.key,
    required this.slot,
    required this.newLevel,
    required this.onDone,
  });

  @override
  State<CompanionLevelUpOverlay> createState() =>
      _CompanionLevelUpOverlayState();
}

class _CompanionLevelUpOverlayState extends State<CompanionLevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
    );
    _slideUp = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );

    _controller.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = CompanionDefinition.forSlot(widget.slot);
    final isPrestige =
        widget.slot == 11 && widget.newLevel >= Companion.maxLevel;
    final color = isPrestige
        ? const Color(0xFFFFD700)
        : const Color(0xFF00B4D8);
    final levelText = isPrestige
        ? '★${widget.newLevel - 100}'
        : 'Level ${widget.newLevel}';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _fadeIn.value * (1.0 - _fadeOut.value);
        return Positioned(
          top: 80,
          left: 40,
          right: 40,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Companion Bild
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/${def.assetKey}.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              // Level Up + neues Level
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Level Up',
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    levelText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
