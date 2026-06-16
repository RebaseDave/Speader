import 'package:flutter/material.dart';

class HslSliders extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;

  const HslSliders({
    super.key,
    required this.initialColor,
    required this.onChanged,
  });

  @override
  State<HslSliders> createState() => _HslSlidersState();
}

class _HslSlidersState extends State<HslSliders> {
  late double _h, _s, _l;

  @override
  void initState() {
    super.initState();
    _fromColor(widget.initialColor);
  }

  void _fromColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    _h = hsl.hue;
    _s = hsl.saturation;
    _l = hsl.lightness;
  }

  Color get _current => HSLColor.fromAHSL(1.0, _h, _s, _l).toColor();
  void _emit() => widget.onChanged(_current);

  String get _hexDisplay {
    double hueToRgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final h = _h / 360;
    double r, g, b;
    if (_s == 0) {
      r = g = b = _l;
    } else {
      final q = _l < 0.5 ? _l * (1 + _s) : _l + _s - _l * _s;
      final p = 2 * _l - q;
      r = hueToRgb(p, q, h + 1 / 3);
      g = hueToRgb(p, q, h);
      b = hueToRgb(p, q, h - 1 / 3);
    }

    final ri = (r * 255).round().clamp(0, 255);
    final gi = (g * 255).round().clamp(0, 255);
    final bi = (b * 255).round().clamp(0, 255);
    return '#'
        '${ri.toRadixString(16).padLeft(2, '0')}'
        '${gi.toRadixString(16).padLeft(2, '0')}'
        '${bi.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HslSliderRow(
          label: 'H',
          value: _h,
          min: 0,
          max: 360,
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
          onChanged: (v) {
            setState(() => _h = v);
            _emit();
          },
        ),
        const SizedBox(height: 6),
        _HslSliderRow(
          label: 'S',
          value: _s,
          min: 0,
          max: 1,
          gradient: LinearGradient(
            colors: [
              HSLColor.fromAHSL(1.0, _h, 0.0, _l).toColor(),
              HSLColor.fromAHSL(1.0, _h, 1.0, _l).toColor(),
            ],
          ),
          onChanged: (v) {
            setState(() => _s = v);
            _emit();
          },
        ),
        const SizedBox(height: 6),
        _HslSliderRow(
          label: 'L',
          value: _l,
          min: 0,
          max: 1,
          gradient: LinearGradient(
            colors: [
              Colors.black,
              HSLColor.fromAHSL(1.0, _h, _s, 0.5).toColor(),
              Colors.white,
            ],
          ),
          onChanged: (v) {
            setState(() => _l = v);
            _emit();
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
                _hexDisplay,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _HslSliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final LinearGradient gradient;
  final ValueChanged<double> onChanged;

  const _HslSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  String get _display =>
      max == 360 ? '${value.round()}°' : '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 18,
                  trackShape: _TransparentTrack(),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    elevation: 3,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            _display,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _TransparentTrack extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {}
}
