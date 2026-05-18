import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/story_engine_controller.dart';
import '../../controllers/story_feed_controller.dart';
import '../../models/feed/story_user.dart';
import '../../widgets/feed/viewer/story_gesture_layer.dart';
import '../../widgets/feed/viewer/story_header.dart';
import '../../widgets/feed/viewer/story_media_view.dart';
import '../../widgets/feed/viewer/story_progress_bars.dart';

/// Full-screen story viewer with horizontal PageView between users.
///
/// Architecture:
/// - [StoryEngineController] is the single source of truth.
/// - [PageView] is the owner of horizontal swipe between users.
/// - [StoryGestureLayer] handles taps and long-press → signals engine.
/// - [StoryProgressBars], [StoryHeader], [StoryMediaView] read from engine.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryUser> users;
  final int initialUserIndex;

  const StoryViewerScreen({
    super.key,
    required this.users,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  late final StoryEngineController _engine;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: widget.initialUserIndex);

    _engine = StoryEngineController(
      users: widget.users,
      feedController: context.read<StoryFeedController>(),
      initialUserIndex: widget.initialUserIndex,
    );

    // Listen for shouldClose and navigate away.
    _engine.addListener(_onEngineChanged);

    // Initialise async (loads mute pref + activates first story).
    _engine.init(this);
  }

  void _onEngineChanged() {
    if (!mounted) return;

    // If engine requests close, pop the route.
    if (_engine.shouldClose) {
      Navigator.of(context).pop();
      return;
    }

    // Keep PageView in sync when engine advances to a new user (e.g. tap-next).
    final enginePage = _engine.userIndex;
    final controllerPage = _pageController.hasClients
        ? _pageController.page?.round() ?? enginePage
        : enginePage;

    if (enginePage != controllerPage) {
      _pageController.animateToPage(
        enginePage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _engine,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildDismissible(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.users.length,
            onPageChanged: (index) {
              // PageView is the owner of swipe navigation — signal engine.
              _engine.onUserPageChanged(index, vsync: this);
            },
            itemBuilder: (_, __) {
              // Each page is identical — content comes from engine state.
              return _StoryPage(onClose: () => Navigator.of(context).pop());
            },
          ),
        ),
      ),
    );
  }

  /// Wraps the viewer in a vertical drag-to-dismiss gesture.
  Widget _buildDismissible({required Widget child}) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}

// ── Single story page ─────────────────────────────────────────────────────

class _StoryPage extends StatelessWidget {
  final VoidCallback onClose;

  const _StoryPage({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return StoryGestureLayer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Media (background) ──────────────────────────────────────────
          const StoryMediaView(),

          // ── Top overlay: progress bars + header ─────────────────────────
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StoryProgressBars(),
                const SizedBox(height: 10),
                StoryHeader(onClose: onClose),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
