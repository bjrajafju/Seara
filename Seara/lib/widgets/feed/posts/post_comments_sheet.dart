import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/post_feed_controller.dart';
import '../../../models/feed/feed_post.dart';
import '../../../models/feed/post_comment.dart';
import '../../../services/feed/comment_repository.dart';
import '../../../utils/time_helper.dart';
import '../../../utils/navigation_helper.dart';

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({
    super.key,
    required this.post,
    required this.scrollController,
  });

  final FeedPost post;
  final ScrollController scrollController;

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final _commentController = TextEditingController();
  final _commentRepo = CommentRepository();
  List<PostComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isSubmitting = false;
  String? _currentUserAvatarUrl;
  String? _currentUserUsername;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadCurrentUserProfile();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentRepo.fetchComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar comentários: $e')),
        );
      }
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('username, avatar')
          .eq('auth_id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _currentUserUsername = data['username'] as String?;
          _currentUserAvatarUrl = data['avatar'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final newComment = await _commentRepo.insertComment(widget.post.id, text);
      
      // Update local state
      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _commentController.clear();
          _isSubmitting = false;
        });

        // Increment count in feed controller
        context.read<PostFeedController>().incrementCommentCount(widget.post.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar comentário: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Text(
            'Comentários',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5),

          // Comments List
          Expanded(
            child: _isLoadingComments
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'Ainda não há comentários.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => NavigationHelper.openProfile(context, comment.userDbId),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(comment.avatarUrl),
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment.middle,
                                              child: GestureDetector(
                                                onTap: () => NavigationHelper.openProfile(context, comment.userDbId),
                                                child: MouseRegion(
                                                  cursor: SystemMouseCursors.click,
                                                  child: Text(
                                                    '${comment.username} ',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextSpan(text: comment.content),
                                          ],
                                        ),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatRelativeTime(comment.createdAt),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Bottom comment input
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      _currentUserAvatarUrl ??
                          'https://ui-avatars.com/api/?name=${_currentUserUsername ?? 'user'}',
                    ),
                    backgroundColor: Colors.white12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Adicionar um comentário...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _commentController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return TextButton(
                        onPressed: hasText && !_isSubmitting
                            ? _submitComment
                            : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              )
                            : Text(
                                'Publicar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: hasText
                                      ? Colors.blue
                                      : Colors.blue.withOpacity(0.4),
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
