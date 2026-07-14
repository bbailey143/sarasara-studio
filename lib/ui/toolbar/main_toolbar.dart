import 'package:flutter/material.dart';

import '../../models/brush.dart';
import '../../models/paper.dart';
import '../../models/pigment.dart';
import 'color_picker_dialog.dart';

/// The floating toolbar for the painting canvas.
///
/// Displays brush controls (color, active brush preset, size, eraser),
/// paper preset selector, and canvas actions (undo, redo, clear) in a
/// compact, dark, frosted-glass bar.
///
/// This is a StatelessWidget — all state is managed by the parent
/// [PaintingScreen] and passed in via callbacks.
class MainToolbar extends StatelessWidget {
  // ─── Current State ────────────────────────────────────────────────

  final Brush activeBrush;
  final Pigment activePigment;
  final Color brushColor;
  final bool isEraser;
  final bool canUndo;
  final bool canRedo;
  final Paper activePaper;
  final bool isBrushDirty;

  // ─── Callbacks ────────────────────────────────────────────────────

  final ValueChanged<Brush> onBrushChanged;
  final ValueChanged<Pigment> onPigmentChanged;
  final ValueChanged<Color> onBrushColorChanged;
  final VoidCallback onEraserToggled;
  final ValueChanged<Paper> onPaperChanged;
  final VoidCallback onRinseBrush;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;

  const MainToolbar({
    super.key,
    required this.activeBrush,
    required this.activePigment,
    required this.brushColor,
    required this.isEraser,
    required this.canUndo,
    required this.canRedo,
    required this.activePaper,
    required this.isBrushDirty,
    required this.onBrushChanged,
    required this.onPigmentChanged,
    required this.onBrushColorChanged,
    required this.onEraserToggled,
    required this.onPaperChanged,
    required this.onRinseBrush,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildColorButton(context),
            const SizedBox(width: 10),
            _buildPigmentSelector(context),
            const SizedBox(width: 10),
            _buildPresetSelector(context),
            const SizedBox(width: 10),
            _buildSizeSlider(),
            const SizedBox(width: 6),
            SizedBox(
              width: 28,
              child: Text(
                activeBrush.size.round().toString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            _divider(),
            _buildPaperSelector(context),
            _divider(),
            _buildToolButton(
              icon: Icons.auto_fix_high_rounded,
              isActive: isEraser,
              onPressed: onEraserToggled,
              tooltip: isEraser ? 'Switch to Brush' : 'Eraser',
            ),
            _divider(),
            _buildToolButton(
              icon: Icons.opacity_rounded,
              isActive: false,
              onPressed: isBrushDirty ? onRinseBrush : null,
              tooltip: isBrushDirty
                  ? 'Rinse Brush (Dirty)'
                  : 'Rinse Brush (Clean)',
            ),
            _divider(),
            _buildToolButton(
              icon: Icons.undo_rounded,
              onPressed: canUndo ? onUndo : null,
              tooltip: 'Undo',
            ),
            _buildToolButton(
              icon: Icons.redo_rounded,
              onPressed: canRedo ? onRedo : null,
              tooltip: 'Redo',
            ),
            _divider(),
            _buildToolButton(
              icon: Icons.delete_outline_rounded,
              onPressed: (canUndo || canRedo) ? onClear : null,
              tooltip: 'Clear Canvas',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Color Button ─────────────────────────────────────────────────

  Widget _buildColorButton(BuildContext context) {
    return Tooltip(
      message: 'Choose Color',
      child: GestureDetector(
        onTap: () async {
          final color = await ColorPickerDialog.show(context, brushColor);
          if (color != null) {
            onBrushColorChanged(color);
          }
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: brushColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: brushColor.withValues(alpha: 0.3),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Pigment Selector ─────────────────────────────────────────────

  Widget _buildPigmentSelector(BuildContext context) {
    return PopupMenuButton<Pigment>(
      tooltip: 'Select Pigment',
      initialValue: activePigment,
      offset: const Offset(0, -260),
      color: const Color(0xFF2D2D3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onPigmentChanged,
      itemBuilder: (context) {
        return Pigment.starterPalette.map((pigment) {
          final isSelected = pigment.name == activePigment.name;
          return PopupMenuItem<Pigment>(
            value: pigment,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: pigment.displayColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  pigment.name,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: activePigment.displayColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                activePigment.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_up_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Brush Preset Selector ────────────────────────────────────────

  Widget _buildPresetSelector(BuildContext context) {
    return PopupMenuButton<Brush>(
      tooltip: 'Select Brush Preset',
      initialValue: activeBrush,
      offset: const Offset(0, -310),
      color: const Color(0xFF2D2D3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onBrushChanged,
      itemBuilder: (context) {
        return Brush.presets.map((preset) {
          final isSelected = preset.name == activeBrush.name;
          return PopupMenuItem<Brush>(
            value: preset,
            child: Row(
              children: [
                Icon(
                  preset.isFlat
                      ? Icons.format_paint_rounded
                      : Icons.brush_rounded,
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Text(
                  preset.name,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activeBrush.isFlat
                  ? Icons.format_paint_rounded
                  : Icons.brush_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              activeBrush.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_up_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Paper Selector ────────────────────────────────────────────────

  Widget _buildPaperSelector(BuildContext context) {
    return PopupMenuButton<Paper>(
      tooltip: 'Select Paper',
      initialValue: activePaper,
      offset: const Offset(0, -200),
      color: const Color(0xFF2D2D3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onPaperChanged,
      itemBuilder: (context) {
        return Paper.presets.map((preset) {
          final isSelected = preset.name == activePaper.name;
          return PopupMenuItem<Paper>(
            value: preset,
            child: Row(
              children: [
                Icon(
                  Icons.terrain_rounded,
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Text(
                  preset.name,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'tooth ${(preset.tooth * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terrain_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              activePaper.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_up_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Size Slider ──────────────────────────────────────────────────

  Widget _buildSizeSlider() {
    return SizedBox(
      width: 120,
      child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: const Color(0xFF6C63FF),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
          thumbColor: Colors.white,
          overlayColor: const Color(0x226C63FF),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 7,
            elevation: 2,
          ),
          trackHeight: 3,
        ),
        child: Slider(
          value: activeBrush.size,
          min: 1.0,
          max: 60.0,
          onChanged: (newSize) {
            onBrushChanged(activeBrush.copyWith(size: newSize));
          },
        ),
      ),
    );
  }

  // ─── Tool Buttons ─────────────────────────────────────────────────

  Widget _buildToolButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool isActive = false,
    String? tooltip,
  }) {
    final isEnabled = onPressed != null;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isActive
                ? const Color(0xFF6C63FF)
                : isEnabled
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.2),
            size: 20,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  // ─── Divider ──────────────────────────────────────────────────────

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
