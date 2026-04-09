import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Player de áudio inline nas mensagens de chat.
///
/// Funcionalidades:
/// - Play / Pause
/// - Barra de progresso interativa (seek)
/// - Botão de velocidade: 1× → 1.25× → 1.5× → 1.75× → 2× → 1×
class AudioMessageWidget extends StatefulWidget {
  const AudioMessageWidget({super.key, required this.url});

  final String url;

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isSeeking = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _initialized = false;

  static const List<double> _speeds = [1.0, 1.25, 1.5, 1.75, 2.0];
  int _speedIndex = 0;

  double get _currentSpeed => _speeds[_speedIndex];

  // Inicialização lazy (só quando o utilizador prime play)
  Future<void> _ensurePlayer() async {
    if (_initialized) return;
    _initialized = true;

    final player = AudioPlayer();

    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    player.onPositionChanged.listen((p) {
      if (!_isSeeking && mounted) setState(() => _position = p);
    });

    player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    if (mounted) setState(() => _player = player);
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  // Controlo de playback
  Future<void> _toggle() async {
    await _ensurePlayer();
    final player = _player;
    if (player == null) return;

    if (_isPlaying) {
      await player.pause();
    } else {
      if (_position == _duration && _duration != Duration.zero) {
        // Recomeçar do início
        await player.seek(Duration.zero);
      }
      await player.play(UrlSource(widget.url));
      await player.setPlaybackRate(_currentSpeed);
    }

    if (mounted) setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _seek(double value) async {
    final target = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    await _player?.seek(target);
    if (mounted) setState(() => _position = target);
  }

  void _cycleSpeed() async {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
    });
    if (_isPlaying) {
      await _player?.setPlaybackRate(_currentSpeed);
    }
  }

  // Formatação de tempo
  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Botão play/pause
          IconButton(
            iconSize: 32,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: theme.colorScheme.primary,
            ),
            onPressed: _toggle,
          ),
          const SizedBox(width: 2),

          // Coluna central: slider + tempos
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.outline.withAlpha(60),
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withAlpha(30),
                  ),
                  child: Slider(
                    value: progress,
                    onChangeStart: (_) => _isSeeking = true,
                    onChanged: (v) {
                      if (mounted) {
                        setState(() {
                          _position = Duration(
                            milliseconds: (v * _duration.inMilliseconds)
                                .round(),
                          );
                        });
                      }
                    },
                    onChangeEnd: (v) {
                      _isSeeking = false;
                      _seek(v);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(_position),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _fmt(_duration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 2),

          // Botão de velocidade
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(60),
                ),
              ),
              child: Text(
                '${_currentSpeed == _currentSpeed.truncate() ? _currentSpeed.toInt() : _currentSpeed}×',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
