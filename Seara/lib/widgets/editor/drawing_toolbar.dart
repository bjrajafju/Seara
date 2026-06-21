import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';

/// Contextual drawing toolbar shown when drawing mode is active.
///
/// Rendered OUTSIDE the [StoryViewport] (like the main toolbar), but appears
/// as a bottom sheet anchored below the viewport — keeps the composition
/// frame clean.
///
/// Features:
/// - Tool selector: pencil / eraser
/// - Brush thickness slider
/// - Color palette
/// - Clear-all button
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({super.key});

  // Curated palette — vibrant colours that show well on dark media.
  static const List<Color> _palette = [
    Colors.white,
    Color(0xFFFF3B30), // red
    Color(0xFFFF9500), // orange
    Color(0xFFFFCC00), // yellow
    Color(0xFF34C759), // green
    Color(0xFF00C7BE), // teal
    Color(0xFF007AFF), // blue
    Color(0xFFAF52DE), // purple
    Color(0xFFFF2D55), // pink
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EditorController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xCC1C1C1E), // dark translucent
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Tool selector + Clear
          Row(
            children: [
              _ToolChip(
                icon: Icons.edit_rounded,
                label: 'Pincel',
                selected: !ctrl.isEraserActive,
                onTap: () =>
                    context.read<EditorController>().setEraserActive(false),
              ),
              const SizedBox(width: 8),
              _ToolChip(
                icon: Icons.auto_fix_normal_rounded,
                label: 'Borracha',
                selected: ctrl.isEraserActive,
                onTap: () =>
                    context.read<EditorController>().setEraserActive(true),
              ),
              const Spacer(),
              // Clear all drawing
              GestureDetector(
                onTap: () => context.read<EditorController>().clearDrawing(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Limpar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Brush thickness
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.white54, size: 8),
              Expanded(
                child: Slider(
                  value: ctrl.brushThickness,
                  min: EditorController.kMinBrushSize,
                  max: EditorController.kMaxBrushSize,
                  divisions: 19,
                  activeColor: ctrl.isEraserActive
                      ? Colors.white54
                      : ctrl.drawingColor,
                  inactiveColor: Colors.white24,
                  onChanged: (v) =>
                      context.read<EditorController>().setBrushThickness(v),
                ),
              ),
              const Icon(Icons.circle, color: Colors.white, size: 22),
            ],
          ),

          const SizedBox(height: 8),

          // Color palette
          if (!ctrl.isEraserActive)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final color = _palette[i];
                  final selected = ctrl.drawingColor == color;
                  return GestureDetector(
                    onTap: () =>
                        context.read<EditorController>().setDrawingColor(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white30,
                          width: selected ? 3 : 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// A compact chip for tool selection (Pencil / Eraser).
class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.black : Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
