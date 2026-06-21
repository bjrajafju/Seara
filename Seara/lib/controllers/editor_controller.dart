import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';

import '../models/story/drawing_path.dart';
import '../models/story/story_audio.dart';
import '../models/story/story_draft.dart';
import '../models/story/story_type.dart';
import '../models/story/text_overlay.dart';
import '../utils/media/blob_url_helper.dart'
    if (dart.library.html) '../utils/media/blob_url_helper_web.dart'
    as blob_helper;

/// Central state manager for the story editor.
///
/// Owns the mutable [StoryDraft] working copy and all editor UI state.
/// Also manages the preview audio lifecycle for external tracks.
class EditorController extends ChangeNotifier {
  // Constants

  static const double kMinScale = 0.3;
  static const double kMaxScale = 5.0;
  static const double kMinFontSize = 12.0;
  static const double kMaxFontSize = 96.0;
  static const double kMinBrushSize = 2.0;
  static const double kMaxBrushSize = 40.0;
  static const double kMinPosition = -0.2;
  static const double kMaxPosition = 1.2;

  // State

  final StoryDraft _draft;
  String? _selectedLayerId;
  bool _isEditModalOpen = false;
  bool _isExporting = false;
  bool _isPublishing = false;

  // Drawing state
  bool _isDrawingMode = false;
  bool _isEraserActive = false;
  Color _drawingColor = Colors.white;
  double _brushThickness = 8.0;

  // Audio Preview State (Reused instance)
  final AudioPlayer _audioPlayer = AudioPlayer();

  EditorController(this._draft) {
    _initAudioPreview();
  }

  @override
  void dispose() {
    // Cleanup Web Blob URL before disposing player
    if (kIsWeb && _draft.audio?.webUrl != null) {
      blob_helper.revokeBlobUrl(_draft.audio!.webUrl);
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Getters

  StoryDraft get draft => _draft;
  String? get selectedLayerId => _selectedLayerId;
  bool get isEditModalOpen => _isEditModalOpen;
  bool get isExporting => _isExporting;
  bool get isPublishing => _isPublishing;
  bool get isBusy => _isExporting || _isPublishing;

  // Drawing getters
  bool get isDrawingMode => _isDrawingMode;
  bool get isEraserActive => _isEraserActive;
  Color get drawingColor => _drawingColor;
  double get brushThickness => _brushThickness;

  // Video / audio getters
  bool get isVideoStory => _draft.type == StoryType.video;
  bool get isMuted => _draft.isMuted;
  StoryAudio? get audioTrack => _draft.audio;
  bool get canExport => true;

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

  // Audio Preview Logic

  void _initAudioPreview() {
    if (_draft.audio != null) {
      _applyAudioTrack(_draft.audio!);
    }
  }

  Future<void> _applyAudioTrack(StoryAudio audio) async {
    try {
      // Reuse the existing player instance, stop first to avoid state conflicts.
      await _audioPlayer.stop();

      // Platform-safe source selection
      final source = kIsWeb
          ? AudioSource.uri(Uri.parse(audio.webUrl!))
          : AudioSource.uri(Uri.file(audio.filePath!));

      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.setLoopMode(LoopMode.off);
      // DO NOT auto-play here. Playback is triggered by video loop sync.
    } catch (e) {
      debugPrint('[EditorController] Audio preview failed: $e');
    }
  }

  /// Restarts the external audio track from timestamp 0.
  /// Called by [BaseMediaWidget] when the video loops to maintain sync.
  Future<void> restartExternalAudio() async {
    if (_draft.audio != null) {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    }
  }

  // Layer mutations

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
      zIndex: 0,
    );
    _draft.addTextOverlay(overlay);
    openEditModal(id);
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

  // Transform mutations

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

  // Text / font mutations

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

  // Drawing mutations

  void toggleDrawingMode() {
    _isDrawingMode = !_isDrawingMode;
    _selectedLayerId = null;
    _isEditModalOpen = false;
    notifyListeners();
  }

  void setEraserActive(bool value) {
    _isEraserActive = value;
    notifyListeners();
  }

  void setDrawingColor(Color color) {
    _drawingColor = color;
    if (_isEraserActive) _isEraserActive = false;
    notifyListeners();
  }

  void setBrushThickness(double value) {
    _brushThickness = value.clamp(kMinBrushSize, kMaxBrushSize);
    notifyListeners();
  }

  void commitStroke(DrawingPath stroke) {
    _draft.ensureDrawingOverlay(id: 'drawing_overlay').addPath(stroke);
    notifyListeners();
  }

  void clearDrawing() {
    _draft.clearDrawing();
    notifyListeners();
  }

  // Video / audio mutations

  void toggleMute() {
    _draft.isMuted = !_draft.isMuted;
    notifyListeners();
  }

  void setAudioTrack(StoryAudio audio) {
    // Revoke old blob URL if replacing
    if (kIsWeb && _draft.audio?.webUrl != null) {
      blob_helper.revokeBlobUrl(_draft.audio!.webUrl);
    }

    _draft.audio = audio;
    _applyAudioTrack(audio);
    notifyListeners();
  }

  void removeAudioTrack() {
    // Revoke blob URL before clearing state
    if (kIsWeb && _draft.audio?.webUrl != null) {
      blob_helper.revokeBlobUrl(_draft.audio!.webUrl);
    }

    _draft.audio = null;
    _audioPlayer.stop();
    notifyListeners();
  }

  // Modal control

  void openEditModal(String id) {
    _selectedLayerId = id;
    _isEditModalOpen = true;
    notifyListeners();
  }

  void closeEditModal() {
    final layer = selectedLayer;
    _isEditModalOpen = false;
    _selectedLayerId = null;
    if (layer != null && layer.content.trim().isEmpty) {
      _draft.textOverlays.remove(layer);
    }
    notifyListeners();
  }

  // Export

  void beginExporting() {
    _isExporting = true;
    notifyListeners();
  }

  void endExporting() {
    _isExporting = false;
    notifyListeners();
  }

  void beginPublishing() {
    _isPublishing = true;
    notifyListeners();
  }

  void endPublishing() {
    _isPublishing = false;
    notifyListeners();
  }

  Future<Uint8List?> captureImage(
    RenderRepaintBoundary? boundary,
    double pixelRatio,
  ) async {
    if (!canExport) return null;
    if (boundary == null) return null;
    _isExporting = true;
    notifyListeners();

    try {
      await Future.delayed(Duration.zero);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  // Private helpers

  TextOverlay? _layerById(String id) {
    try {
      return _draft.textOverlays.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}
