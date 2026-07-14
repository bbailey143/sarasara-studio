import 'package:flutter/material.dart';

/// A custom HSV color picker dialog with artist-friendly preset colors.
///
/// Features:
/// - Saturation/Value rectangle with crosshair indicator
/// - Hue slider with rainbow gradient
/// - Artist-curated watercolor palette presets
/// - Current color preview
///
/// Self-contained — no dependency on any other lib/ file besides
/// flutter/material. Keep it that way; it's fully reusable as-is.
class ColorPickerDialog extends StatefulWidget {
  /// The color to start with when the dialog opens.
  final Color initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  /// Show the color picker as a dialog. Returns the chosen color,
  /// or null if cancelled.
  static Future<Color?> show(BuildContext context, Color initialColor) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsv;
  late Color _initialColor;

  // Artist preset colors — curated watercolor palette.
  static const List<_PresetColor> _presets = [
    _PresetColor('Phthalo Blue', Color(0xFF0D3B66)),
    _PresetColor('Ultramarine', Color(0xFF2C5F8A)),
    _PresetColor('Cerulean', Color(0xFF5B9BD5)),
    _PresetColor('Magenta', Color(0xFF8B1A4A)),
    _PresetColor('Cadmium Red', Color(0xFFCC2936)),
    _PresetColor('Alizarin', Color(0xFFA52A2A)),
    _PresetColor('Hansa Yellow', Color(0xFFEBC944)),
    _PresetColor('Yellow Ochre', Color(0xFFD4A017)),
    _PresetColor('Cad Orange', Color(0xFFE8751A)),
    _PresetColor('Sap Green', Color(0xFF2D6A4F)),
    _PresetColor('Viridian', Color(0xFF40826D)),
    _PresetColor('Hooker\'s Green', Color(0xFF1B4332)),
    _PresetColor('Burnt Sienna', Color(0xFF8B4513)),
    _PresetColor('Raw Umber', Color(0xFF5C4033)),
    _PresetColor('Burnt Umber', Color(0xFF6E3B1A)),
    _PresetColor('White', Color(0xFFF5F5F5)),
    _PresetColor('Payne\'s Gray', Color(0xFF3D4F5F)),
    _PresetColor('Ivory Black', Color(0xFF1A1A1A)),
  ];

  @override
  void initState() {
    super.initState();
    _initialColor = widget.initialColor;
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose Color',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildSVPicker(),
              const SizedBox(height: 12),
              _buildHueSlider(),
              const SizedBox(height: 16),
              _buildPresets(),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SV Picker ───────────────────────────────────────────────────

  Widget _buildSVPicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return GestureDetector(
          onPanStart: (d) => _updateSV(d.localPosition, size),
          onPanUpdate: (d) => _updateSV(d.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: size,
              height: size * 0.75,
              child: CustomPaint(
                painter: _SVPainter(
                  hue: _hsv.hue,
                  saturation: _hsv.saturation,
                  value: _hsv.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateSV(Offset pos, double size) {
    setState(() {
      final s = (pos.dx / size).clamp(0.0, 1.0);
      final v = 1.0 - (pos.dy / (size * 0.75)).clamp(0.0, 1.0);
      _hsv = HSVColor.fromAHSV(1.0, _hsv.hue, s, v);
    });
  }

  // ─── Hue Slider ──────────────────────────────────────────────────

  Widget _buildHueSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanStart: (d) => _updateHue(d.localPosition.dx, width),
          onPanUpdate: (d) => _updateHue(d.localPosition.dx, width),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: width,
              height: 28,
              child: CustomPaint(painter: _HuePainter(hue: _hsv.hue)),
            ),
          ),
        );
      },
    );
  }

  void _updateHue(double x, double width) {
    setState(() {
      final h = (x / width * 360).clamp(0.0, 359.99);
      _hsv = HSVColor.fromAHSV(1.0, h, _hsv.saturation, _hsv.value);
    });
  }

  // ─── Presets ─────────────────────────────────────────────────────

  Widget _buildPresets() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _presets.map((preset) {
        final isSelected = _colorDistance(preset.color, _hsv.toColor()) < 0.05;
        return Tooltip(
          message: preset.name,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _hsv = HSVColor.fromColor(preset.color);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: preset.color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: preset.color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────

  Widget _buildFooter() {
    final currentColor = _hsv.toColor();
    return Row(
      children: [
        Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Row(
              children: [
                Expanded(child: Container(color: _initialColor)),
                Expanded(child: Container(color: currentColor)),
              ],
            ),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.white54),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, currentColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  /// Simple perceptual color distance for preset selection highlight.
  double _colorDistance(Color a, Color b) {
    final dr = (a.r - b.r).abs();
    final dg = (a.g - b.g).abs();
    final db = (a.b - b.b).abs();
    return (dr + dg + db) / 3.0;
  }
}

// ─── Custom Painters ──────────────────────────────────────────────────

/// Paints the Saturation/Value rectangle for a given hue.
///
/// Left → Right = Saturation (0 → 1)
/// Top → Bottom = Value (1 → 0)
class _SVPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _SVPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final hueColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    final satGradient = LinearGradient(colors: [Colors.white, hueColor]);
    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));

    const valGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0xFF000000)],
    );
    canvas.drawRect(rect, Paint()..shader = valGradient.createShader(rect));

    final cx = saturation * size.width;
    final cy = (1.0 - value) * size.height;
    final center = Offset(cx, cy);

    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SVPainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}

/// Paints the hue rainbow bar with a position indicator.
class _HuePainter extends CustomPainter {
  final double hue;

  _HuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final colors = List.generate(
      7,
      (i) => HSVColor.fromAHSV(1.0, i * 60.0, 1.0, 1.0).toColor(),
    );

    final gradient = LinearGradient(colors: colors);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final x = (hue / 360.0) * size.width;
    final indicatorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, size.height / 2),
        width: 8,
        height: size.height + 4,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      indicatorRect,
      Paint()
        ..color = Colors.black45
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      indicatorRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}

/// Internal data class for preset color swatches.
class _PresetColor {
  final String name;
  final Color color;
  const _PresetColor(this.name, this.color);
}
