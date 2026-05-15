import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../mappers/story_media_mapper.dart';
import '../../models/story/story_models.dart';
import '../../services/story/media_input_service.dart';
import '../../services/story/media_input_service_factory.dart';
import '../../widgets/story/story_viewport.dart';
import 'story_editor_screen.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  late final MediaInputService _mediaService;
  bool _isInitialized = false;
  bool _hasPermission = true;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  DateTime? _recordingStartTime;

  Timer? _recordingTimer;
  int _recordingDuration = 0;
  static const int _maxRecordingSeconds = 60;

  @override
  void initState() {
    super.initState();
    _mediaService = createMediaInputService();
    _initService();
  }

  Future<void> _initService() async {
    final success = await _mediaService.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = success;
        _hasPermission = success;
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize camera or permission denied.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _stopRecordingTimer();
    _mediaService.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  void _startRecordingTimer() {
    _recordingDuration = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration++);
      if (_recordingDuration >= _maxRecordingSeconds) {
        _stopRecording();
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Capture actions
  // ---------------------------------------------------------------------------

  Future<void> _pickFromGallery() async {
    if (_isProcessing || _isRecording) return;
    setState(() => _isProcessing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // Platform-safe path/bytes extraction
      final path = kIsWeb ? null : file.path;
      final bytes = file.bytes;

      if (kIsWeb) {
        if (bytes == null) return;
        final mimeType =
            file.name.toLowerCase().endsWith('.mp4') ||
                file.name.toLowerCase().endsWith('.mov') ||
                file.name.toLowerCase().endsWith('.webm')
            ? 'video/mp4'
            : 'image/jpeg';
        final isVideo = mimeType.startsWith('video/');

        _navigateToEditor(
          StoryDraft(
            type: isVideo ? StoryType.video : StoryType.photo,
            media: [
              StoryMediaMapper.fromAsset(
                BytesMediaAsset(bytes: bytes, mimeType: mimeType),
              ),
            ],
          ),
        );
      } else {
        if (path == null) return;
        final mimeType = StoryMediaMapper.inferMimeType(path);
        final isVideo = mimeType.startsWith('video/');
        _navigateToEditor(
          StoryDraft(
            type: isVideo ? StoryType.video : StoryType.photo,
            media: [StoryMediaMapper.fromAsset(FileMediaAsset(path))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleClose() async {
    if (_isRecording) {
      _stopRecordingTimer();
      setState(() => _isRecording = false);
      await _mediaService.stopVideoRecording();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _takePhoto() async {
    if (_isRecording || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final asset = await _mediaService.capturePhoto();
      if (!mounted) return;

      if (asset != null) {
        _navigateToEditor(
          StoryDraft(
            type: StoryType.photo,
            media: [StoryMediaMapper.fromAsset(asset)],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool _pendingStop = false;

  Future<void> _startRecording() async {
    if (_isProcessing || _isRecording) return;
    setState(() {
      _isProcessing = true;
      _pendingStop = false;
    });

    try {
      final success = await _mediaService.startVideoRecording();
      if (!mounted) return;

      if (success) {
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
        });
        if (_mediaService.hasCameraPreview) {
          _startRecordingTimer();
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    if (_pendingStop && _isRecording) {
      await _stopRecording();
    } else if (_isRecording && !_mediaService.hasCameraPreview) {
      await _stopRecording();
    }
  }

  Future<void> _stopRecording() async {
    if (_isProcessing) {
      _pendingStop = true;
      return;
    }
    if (!_isRecording) return;
    setState(() => _isProcessing = true);

    _stopRecordingTimer();
    final duration = _recordingDuration;

    // Safety check: Don't stop if it was just started (less than 500ms)
    // to avoid race conditions with quick releases or system glitches.
    if (_recordingStartTime != null &&
        DateTime.now().difference(_recordingStartTime!).inMilliseconds < 500) {
      _pendingStop = true;
      return;
    }

    setState(() {
      _isRecording = false;
      _recordingStartTime = null;
    });

    try {
      final asset = await _mediaService.stopVideoRecording();
      if (!mounted) return;

      if (asset != null) {
        _navigateToEditor(
          StoryDraft(
            type: StoryType.video,
            media: [
              StoryMediaMapper.fromAsset(
                asset,
                durationSeconds: duration.toDouble(),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to record video')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final isOn = await _mediaService.toggleFlash();
    if (mounted) setState(() => _isFlashOn = isOn);
  }

  Future<void> _switchCamera() async {
    final success = await _mediaService.switchCamera();
    if (success && mounted) setState(() {});
  }

  /// Pushes [StoryEditorScreen] replacing the camera screen so the user
  /// cannot navigate back to the camera after capturing.
  void _navigateToEditor(StoryDraft draft) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StoryEditorScreen(draft: draft)),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return _buildError('Camera permission denied');
    }

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview constrained to the same 9:16 frame used by the
            // editor. Composition overlay controls sit outside the viewport.
            StoryViewport(child: _buildPreview()),

            // Top bar: close / recording timer / flash + flip
            _buildTopBar(),

            // Bottom bar: gallery stub / capture button
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _handleClose,
        ),
      ),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final previewData = _mediaService.getPreview(context);
    if (previewData != null) {
      return previewData.builder(context);
    }
    // Fallback: loading or camera not yet initialised.
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.camera_alt, color: Colors.white38, size: 80),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: _handleClose,
          ),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '00:${_recordingDuration.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            children: [
              // Flash only makes sense on camera platforms.
              if (_mediaService.hasCameraPreview)
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleFlash,
                ),
              const SizedBox(width: 8),
              if (_mediaService.hasCameraPreview)
                IconButton(
                  icon: const Icon(
                    Icons.flip_camera_ios,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _switchCamera,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery
          IconButton(
            icon: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 32,
            ),
            onPressed: _pickFromGallery,
          ),

          // Capture button
          Listener(
            key: const ValueKey('capture_button'),
            onPointerDown: (_) {
              _pendingStop = false;
            },
            onPointerUp: (_) {
              if (_isRecording) {
                _stopRecording();
              } else {
                // If they just tapped, _stopRecording wasn't called.
                // We'll let GestureDetector handle the tap for photo.
              }
            },
            child: GestureDetector(
              onTap: _takePhoto,
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) {
                // Handled by Listener for better desktop support,
                // but kept here for mobile/gesture consistency.
                if (_isRecording) _stopRecording();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.white,
                    width: 4,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isRecording ? 30 : 64,
                    height: _isRecording ? 30 : 64,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.white,
                      borderRadius: BorderRadius.circular(
                        _isRecording ? 8 : 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Spacer to balance the row
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
