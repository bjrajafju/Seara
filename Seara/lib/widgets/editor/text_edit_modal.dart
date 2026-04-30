import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/editor_controller.dart';

/// Full-screen overlay for editing a text layer's content and font size.
///
/// Opened by [EditorController.openEditModal] and closed by
/// [EditorController.closeEditModal] (which removes the layer if empty).
///
/// Used for BOTH creation and editing — the same UI in both cases.
class TextEditModal extends StatefulWidget {
  final String layerId;

  const TextEditModal({super.key, required this.layerId});

  @override
  State<TextEditModal> createState() => _TextEditModalState();
}

class _TextEditModalState extends State<TextEditModal> {
  late final TextEditingController _textCtrl;
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    final layer = context.read<EditorController>().selectedLayer;
    _textCtrl = TextEditingController(text: layer?.content ?? '');
    _fontSize = layer?.fontSize ?? 32.0;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed background — not dismissible by tap (Done button only).
        const ModalBarrier(color: Colors.black54, dismissible: false),

        // Editor panel centered on screen.
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Text input.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type something…',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  onChanged: (value) {
                    context.read<EditorController>().updateText(
                      widget.layerId,
                      value,
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Font size slider.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.text_fields,
                      color: Colors.white54,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: EditorController.kMinFontSize,
                        max: EditorController.kMaxFontSize,
                        divisions: 42,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          setState(() => _fontSize = value);
                          context.read<EditorController>().updateFontSize(
                            widget.layerId,
                            value,
                          );
                        },
                      ),
                    ),
                    const Icon(
                      Icons.text_fields,
                      color: Colors.white,
                      size: 26,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Done button.
              TextButton(
                onPressed: () =>
                    context.read<EditorController>().closeEditModal(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
