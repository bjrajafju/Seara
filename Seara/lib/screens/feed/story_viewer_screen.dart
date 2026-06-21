import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/story_engine_controller.dart';
import '../../controllers/story_feed_controller.dart';
import '../../models/feed/feed_story.dart';
import '../../models/feed/story_user.dart';
import '../../widgets/feed/viewer/story_gesture_layer.dart';
import '../../widgets/feed/viewer/story_header.dart';
import '../../widgets/feed/viewer/story_media_view.dart';
import '../../widgets/feed/viewer/story_progress_bars.dart';
import '../../widgets/feed/viewer/story_viewers_sheet.dart';
import '../../widgets/story/story_viewport.dart';

/// Full-screen story viewer with horizontal PageView between users.
///
/// Architecture:
/// - [StoryEngineController] is the single source of truth.
/// - [PageView] is the owner of horizontal swipe between users.
/// - [StoryGestureLayer] handles taps and long-press -> signals engine.
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
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
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

//  Single story page

class _StoryPage extends StatelessWidget {
  final VoidCallback onClose;

  const _StoryPage({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final story = engine.currentStory;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnStory = story.userId == currentUserId;

    return StoryViewport(
      child: StoryGestureLayer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media (background)
            const StoryMediaView(),

            // Top overlay: progress bars + header
            Positioned(
              top: 16,
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

            // Bottom overlay: management button for own stories
            if (isOwnStory)
              Positioned(
                bottom: 16,
                left: 12,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 26,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                    onPressed: () =>
                        _showManagementSheet(context, engine, story),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showManagementSheet(
    BuildContext context,
    StoryEngineController engine,
    FeedStory story,
  ) async {
    engine.pause();

    final wasDeleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StoryViewersSheet(
        storyId: story.id,
        mediaUrl: story.mediaUrl,
        engine: engine,
      ),
    );

    if (wasDeleted == true) {
      await engine.handleStoryDeleted(story.id);
    } else {
      engine.resume();
    }
  }
}
