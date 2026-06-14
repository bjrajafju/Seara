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
  bool _isHandsFreeEnabled = false;
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
        type: kIsWeb ? FileType.image : FileType.media,
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
        final nameLower = file.name.toLowerCase();
        final isVideoFile =
            nameLower.endsWith('.mp4') ||
            nameLower.endsWith('.mov') ||
            nameLower.endsWith('.webm') ||
            nameLower.endsWith('.mkv') ||
            nameLower.endsWith('.avi');

        if (isVideoFile) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vídeos não são suportados na Web.')),
          );
          return;
        }

        final mimeType = StoryMediaMapper.inferMimeType(file.name);
        _navigateToEditor(
          StoryDraft(
            type: StoryType.photo,
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
    if (kIsWeb) return;
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
    if (kIsWeb) return;
    if (_isProcessing) {
      _pendingStop = true;
      return;
    }
    if (!_isRecording) return;

    setState(() => _isProcessing = true);

    _stopRecordingTimer();

    final duration = _recordingDuration;

    final isTooFast =
        _recordingStartTime != null &&
        DateTime.now().difference(_recordingStartTime!).inMilliseconds < 500;

    if (isTooFast) {
      _pendingStop = true;

      setState(() {
        _isProcessing = false;
      });

      // tenta novamente depois de um frame
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_isRecording) await _stopRecording();
      });

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

            // Left Sidebar: Hands Free Toggle
            _buildSideBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBar() {
    if (kIsWeb) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolButton(
              icon: _isHandsFreeEnabled
                  ? Icons.front_hand
                  : Icons.pan_tool_outlined,
              label: 'Hands Free',
              isActive: _isHandsFreeEnabled,
              onPressed: () {
                if (_isRecording) return;
                setState(() => _isHandsFreeEnabled = !_isHandsFreeEnabled);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? Colors.yellow : Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.yellow : Colors.white24,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
      ],
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
                _formatDuration(_recordingDuration),
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
              if (kIsWeb) return;
              if (!_isHandsFreeEnabled) {
                _pendingStop = false;
              }
            },
            onPointerUp: (_) {
              if (kIsWeb) return;
              if (!_isHandsFreeEnabled && _isRecording) {
                _stopRecording();
              }
            },
            child: GestureDetector(
              onTap: () {
                if (kIsWeb) {
                  _takePhoto();
                  return;
                }
                if (_isHandsFreeEnabled) {
                  if (_isRecording) {
                    _stopRecording();
                  } else {
                    _startRecording();
                  }
                } else {
                  _takePhoto();
                }
              },
              onLongPressStart: (kIsWeb || _isHandsFreeEnabled)
                  ? null
                  : (_) => _startRecording(),
              onLongPressEnd: (kIsWeb || _isHandsFreeEnabled)
                  ? null
                  : (_) {
                      if (_isRecording) _stopRecording();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording
                        ? Colors.red
                        : ((!kIsWeb && _isHandsFreeEnabled)
                              ? Colors.yellow
                              : Colors.white),
                    width: 4,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isRecording ? 30 : 64,
                    height: _isRecording ? 30 : 64,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red
                          : ((!kIsWeb && _isHandsFreeEnabled)
                                ? Colors.yellow
                                : Colors.white),
                      borderRadius: BorderRadius.circular(
                        _isRecording ? 8 : 32,
                      ),
                    ),
                    child: (!kIsWeb && _isHandsFreeEnabled && !_isRecording)
                        ? const Icon(
                            Icons.videocam,
                            color: Colors.black,
                            size: 32,
                          )
                        : null,
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

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
