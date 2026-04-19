import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:seara/services/global_audio_manager.dart';

/// Inline audio player for chat messages.
///
/// Design contract:
/// - Owns NO [AudioPlayer]. All playback is delegated to [GlobalAudioManager].
/// - UI state is driven entirely by manager streams — never by local booleans.
/// - Safe to scroll in/out of view: audio continues regardless of widget lifecycle.
/// - Only one audio can play at a time (enforced by the manager).
class AudioMessageWidget extends StatefulWidget {
  const AudioMessageWidget({
    super.key,
    required this.messageId,
    required this.url,
  });

  /// Unique ID of the message — used to tag ownership in [GlobalAudioManager].
  final String messageId;

  /// Remote URL of the audio file.
  final String url;

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final GlobalAudioManager _manager = GlobalAudioManager.instance;

  // Local UI-only state (not playback state).
  bool _isSeeking = false;
  Duration _seekPosition = Duration.zero; // shown only while dragging

  // Speed cycling.
  static const List<double> _speeds = [1.0, 1.5, 2.0];
  int _speedIndex = 0;
  double _currentSpeed = 1.0;
  bool _isChangingSpeed = false;

  String? _errorText;

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _isThisActive =>
      _manager.currentMessageId == widget.messageId;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Playback actions ───────────────────────────────────────────────────────

  Future<void> _toggle() async {
    try {
      if (_manager.isPlaying(widget.messageId)) {
        await _manager.pause();
      } else {
        // Start / resume.
        if (_isThisActive) {
          // Already loaded and paused — just resume.
          await _manager.resume();
        } else {
          // New audio — manager will stop whatever was playing.
          await _manager.playUrl(widget.messageId, widget.url);
        }
      }
      if (mounted) setState(() => _errorText = null);
    } catch (e) {
      if (mounted) setState(() => _errorText = 'Erro ao reproduzir.');
    }
  }

  Future<void> _seek(double ratio) async {
    if (!_isThisActive) return;
    final dur = _manager.durationFor(widget.messageId);
    if (dur == null || dur == Duration.zero) return;
    final target = Duration(
      milliseconds: (ratio * dur.inMilliseconds).round(),
    );
    await _manager.seek(target);
    if (mounted) setState(() => _seekPosition = target);
  }

  void _cycleSpeed() {
    if (_isChangingSpeed) return;
    final next = (_speedIndex + 1) % _speeds.length;
    setState(() {
      _speedIndex = next;
      _currentSpeed = _speeds[next];
    });
    if (!_isThisActive) {
      _manager.setSpeed(_currentSpeed);
      return;
    }
    setState(() => _isChangingSpeed = true);
    _manager.setSpeed(_currentSpeed).whenComplete(() {
      if (mounted) setState(() => _isChangingSpeed = false);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // We use two nested StreamBuilders:
    // 1. activeMessageIdStream — tells us whether THIS message is active.
    // 2. playerStateStream + positionStream — for play/pause icon and slider.

    return StreamBuilder<String?>(
      stream: _manager.activeMessageIdStream,
      initialData: _manager.lastActiveMessageId,
      builder: (context, activeSnap) {
        final isActive = activeSnap.data == widget.messageId;

        return StreamBuilder<PlayerState>(
          stream: _manager.playerStateStream,
          initialData: _manager.lastPlayerState,
          builder: (context, stateSnap) {
            final playerState = stateSnap.data!;
            final isPlaying =
                isActive &&
                playerState.playing &&
                playerState.processingState != ProcessingState.completed;
            final isLoading =
                isActive &&
                (playerState.processingState == ProcessingState.loading ||
                    playerState.processingState == ProcessingState.buffering);

            return StreamBuilder<Duration>(
              stream: _manager.positionStream,
              initialData:
                  isActive ? _manager.lastPosition : Duration.zero,
              builder: (context, posSnap) {
                final livePosition =
                    isActive ? posSnap.data ?? Duration.zero : Duration.zero;

                return StreamBuilder<Duration>(
                  stream: _manager.durationStream,
                  initialData:
                      isActive ? _manager.lastDuration : Duration.zero,
                  builder: (context, durSnap) {
                    final duration =
                        isActive ? durSnap.data ?? Duration.zero : Duration.zero;

                    final position = _isSeeking ? _seekPosition : livePosition;
                    final progress = duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;

                    return _buildUI(
                      theme: theme,
                      isLoading: isLoading,
                      isPlaying: isPlaying,
                      progress: progress,
                      position: position,
                      duration: duration,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUI({
    required ThemeData theme,
    required bool isLoading,
    required bool isPlaying,
    required double progress,
    required Duration position,
    required Duration duration,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // ── Play / Pause button ──────────────────────────────────────────
          IconButton(
            iconSize: 32,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: theme.colorScheme.primary,
                  ),
            onPressed: _toggle,
          ),
          const SizedBox(width: 2),

          // ── Slider + time labels ─────────────────────────────────────────
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
                    inactiveTrackColor:
                        theme.colorScheme.outline.withAlpha(60),
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withAlpha(30),
                  ),
                  child: Slider(
                    value: progress,
                    allowedInteraction: SliderInteraction.tapAndSlide,
                    onChangeStart: (_) {
                      setState(() => _isSeeking = true);
                    },
                    onChanged: (v) {
                      if (!mounted) return;
                      final dur = duration;
                      if (dur == Duration.zero) return;
                      setState(() {
                        _seekPosition = Duration(
                          milliseconds:
                              (v * dur.inMilliseconds).round(),
                        );
                      });
                    },
                    onChangeEnd: (v) {
                      setState(() => _isSeeking = false);
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
                        _fmt(position),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _fmt(duration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _errorText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 2),

          // ── Speed button ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _isChangingSpeed ? null : _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _isChangingSpeed
                    ? theme.colorScheme.outline.withAlpha(20)
                    : theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isChangingSpeed
                      ? theme.colorScheme.outline.withAlpha(60)
                      : theme.colorScheme.primary.withAlpha(60),
                ),
              ),
              child: Text(
                '${_currentSpeed == _currentSpeed.truncateToDouble() ? _currentSpeed.toInt() : _currentSpeed}×',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _isChangingSpeed
                      ? theme.colorScheme.onSurface.withAlpha(120)
                      : theme.colorScheme.primary,
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
