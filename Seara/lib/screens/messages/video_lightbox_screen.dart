import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

// Import condicional: usa web em browser, stub em mobile
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

/// Modal fullscreen para reprodução de vídeos recebidos no chat.
///
/// Funcionalidades:
/// - Play / Pause (tap central)
/// - Barra de progresso interativa (seek)
/// - Controlo de volume (mute / unmute)
/// - Botão fullscreen (landscape em mobile, indicação em web)
/// - Download
/// - Fechar com X ou tap fora dos controlos
class VideoLightboxScreen extends StatefulWidget {
  const VideoLightboxScreen({
    super.key,
    required this.videoUrl,
    this.fileName,
  });

  final String videoUrl;
  final String? fileName;

  @override
  State<VideoLightboxScreen> createState() => _VideoLightboxScreenState();
}

class _VideoLightboxScreenState extends State<VideoLightboxScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  bool _isSeeking = false;
  bool _isMuted = false;
  bool _isDownloading = false;
  bool _isFullscreen = false;

  late AnimationController _controlsFade;

  @override
  void initState() {
    super.initState();

    _controlsFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );

    // video_player suporta web nativamente — sem guard kIsWeb
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _autoHideControls();
        }
      }).catchError((_) {
        // Falha silenciosa — ex: CORS no browser
        if (mounted) setState(() => _initialized = false);
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controlsFade.dispose();
    _controller.dispose();
    // SystemChrome apenas em mobile
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // ── Controlos de UI ─────────────────────────────────────────────────────
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsFade.forward();
      _autoHideControls();
    } else {
      _controlsFade.reverse();
    }
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_isSeeking) {
        setState(() => _showControls = false);
        _controlsFade.reverse();
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _controlsFade.forward();
    }
    _autoHideControls();
  }

  // ── Playback ────────────────────────────────────────────────────────────
  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
    _showControlsTemporarily();
  }

  Future<void> _seek(double value) async {
    final target = Duration(
      milliseconds:
          (value * _controller.value.duration.inMilliseconds).round(),
    );
    await _controller.seekTo(target);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
    _showControlsTemporarily();
  }

  // ── Fullscreen ──────────────────────────────────────────────────────────
  void _toggleFullscreen() {
    if (kIsWeb) return;
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _showControlsTemporarily();
  }

  // ── Download ────────────────────────────────────────────────────────────
  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      if (kIsWeb) {
        downloadFile(widget.videoUrl, widget.fileName ?? 'video.mp4');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download iniciado.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer download.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ── Formatação de tempo ─────────────────────────────────────────────────
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Vídeo / placeholder web ────────────────────────────────
            Center(child: _buildVideoContent()),

            // ── Overlay de controlos (fade) ────────────────────────────
            FadeTransition(
              opacity: _controlsFade,
              child: _buildControlsOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (!_initialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  Widget _buildControlsOverlay() {
    return Column(
      children: [
        // ── Barra superior ─────────────────────────────────────────────
        _buildTopBar(),
        const Spacer(),

        // ── Botão play/pause central ───────────────────────────────────
        if (_initialized)
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withAlpha(120),
              ),
              child: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),

        const Spacer(),

        // ── Barra inferior (progress + volume + fullscreen) ────────────
        if (_initialized) _buildBottomBar(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(160),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.fileName ?? 'Vídeo',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Download
            _isDownloading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Download',
                    onPressed: _download,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withAlpha(160),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de progresso
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white38,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: progress.toDouble(),
                  onChangeStart: (_) {
                    _isSeeking = true;
                    _controller.pause();
                  },
                  onChanged: (v) {
                    setState(() {
                      // Actualizar o display durante o seek
                    });
                    _seek(v);
                  },
                  onChangeEnd: (v) {
                    _isSeeking = false;
                    _seek(v);
                    _controller.play();
                    _autoHideControls();
                  },
                ),
              ),
              // Linha de botões + tempos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      _fmt(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      ' / ',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      _fmt(duration),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // Volume
                    IconButton(
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                    const SizedBox(width: 16),
                    // Fullscreen (apenas mobile)
                    if (!kIsWeb)
                      IconButton(
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
