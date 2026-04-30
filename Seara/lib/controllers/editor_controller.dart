import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../models/story/story_draft.dart';
import '../models/story/text_overlay.dart';

/// Central state manager for the story editor.
///
/// Owns the mutable [StoryDraft] working copy and all editor UI state.
/// All clamping of transforms, positions, and font sizes is applied here —
/// never in widgets.
class EditorController extends ChangeNotifier {
  // ── Constants ──────────────────────────────────────────────────────────────

  static const double kMinScale = 0.3;
  static const double kMaxScale = 5.0;
  static const double kMinFontSize = 12.0;
  static const double kMaxFontSize = 96.0;

  /// Normalized position bounds — slight overflow allowed so text can be
  /// partially off-screen without becoming unrecoverable.
  static const double kMinPosition = -0.2;
  static const double kMaxPosition = 1.2;

  // ── State ──────────────────────────────────────────────────────────────────

  final StoryDraft _draft;
  String? _selectedLayerId;
  bool _isEditModalOpen = false;
  bool _isExporting = false;

  EditorController(this._draft);

  // ── Getters ────────────────────────────────────────────────────────────────

  StoryDraft get draft => _draft;

  String? get selectedLayerId => _selectedLayerId;

  bool get isEditModalOpen => _isEditModalOpen;

  bool get isExporting => _isExporting;

  /// All text layers sorted by [TextOverlay.zIndex] ascending.
  /// The last item in the list renders on top.
  List<TextOverlay> get layersInZOrder {
    final sorted = List<TextOverlay>.from(_draft.textOverlays);
    sorted.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sorted;
  }

  TextOverlay? get selectedLayer {
    if (_selectedLayerId == null) return null;
    try {
      return _draft.textOverlays.firstWhere((l) => l.id == _selectedLayerId);
    } catch (_) {
      return null;
    }
  }

  // ── Layer mutations ────────────────────────────────────────────────────────

  /// Creates a new text layer centered on the canvas, then opens the edit modal.
  void addTextLayer() {
    final id = 'text_${DateTime.now().microsecondsSinceEpoch}';
    final overlay = TextOverlay(
      id: id,
      x: 0.5,
      y: 0.5,
      scale: 1.0,
      rotation: 0.0,
      fontSize: 32.0,
      content: '',
      zIndex: 0, // addTextOverlay assigns real zIndex
    );
    _draft.addTextOverlay(overlay);
    openEditModal(id);
    // notifyListeners called by openEditModal
  }

  void removeLayer(String id) {
    _draft.textOverlays.removeWhere((l) => l.id == id);
    if (_selectedLayerId == id) {
      _selectedLayerId = null;
      _isEditModalOpen = false;
    }
    notifyListeners();
  }

  void selectLayer(String id) {
    _selectedLayerId = id;
    notifyListeners();
  }

  void deselectAll() {
    _selectedLayerId = null;
    notifyListeners();
  }

  void bringToFront(String id) {
    final layer = _layerById(id);
    if (layer == null) return;
    _draft.bringTextToFront(layer);
    notifyListeners();
  }

  // ── Transform mutations ────────────────────────────────────────────────────

  void updatePosition(String id, double newX, double newY) {
    final layer = _layerById(id);
    if (layer == null) return;
    layer.x = newX.clamp(kMinPosition, kMaxPosition);
    layer.y = newY.clamp(kMinPosition, kMaxPosition);
    notifyListeners();
  }

  void updateScaleAndRotation(String id, double newScale, double newRotation) {
    final layer = _layerById(id);
    if (layer == null) return;
    layer.scale = newScale.clamp(kMinScale, kMaxScale);
    layer.rotation = newRotation;
    notifyListeners();
  }

  // ── Text / font mutations ──────────────────────────────────────────────────

  void updateText(String id, String newContent) {
    final layer = _layerById(id);
    if (layer == null) return;
    layer.content = newContent;
    notifyListeners();
  }

  void updateFontSize(String id, double newSize) {
    final layer = _layerById(id);
    if (layer == null) return;
    layer.fontSize = newSize.clamp(kMinFontSize, kMaxFontSize);
    notifyListeners();
  }

  // ── Modal control ──────────────────────────────────────────────────────────

  void openEditModal(String id) {
    _selectedLayerId = id;
    _isEditModalOpen = true;
    notifyListeners();
  }

  /// Closes the modal. Removes the layer if it was left empty.
  void closeEditModal() {
    final layer = selectedLayer;
    _isEditModalOpen = false;
    _selectedLayerId = null;
    if (layer != null && layer.content.trim().isEmpty) {
      _draft.textOverlays.remove(layer);
    }
    notifyListeners();
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Captures [boundary] and writes the result as a PNG to the temp directory.
  ///
  /// The [RenderRepaintBoundary] is resolved synchronously by the caller (UI)
  /// before this async method is called, eliminating BuildContext-across-async
  /// lint warnings.
  ///
  /// [pixelRatio] must be supplied by the UI (e.g. from [MediaQuery]).
  /// Returns the saved file path on success, null on failure.
  Future<String?> exportToImage(
    RenderRepaintBoundary? boundary,
    double pixelRatio,
  ) async {
    if (boundary == null) return null;
    _isExporting = true;
    notifyListeners();

    try {
      // Allow Flutter to finish painting the current frame before capturing.
      await Future.delayed(Duration.zero);

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      return file.path;
    } catch (_) {
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  TextOverlay? _layerById(String id) {
    try {
      return _draft.textOverlays.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}
