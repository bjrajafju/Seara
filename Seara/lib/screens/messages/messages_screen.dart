import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seara/providers/theme_provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();

  // SEARCH BAR
  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: "Pesquisar...",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget _buildResultsHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            "Resultados:",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "24",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  // MESSAGE ITEM
  Widget _buildMessageItem(ThemeData theme) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1633332755192-727a05c4013d',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User/Group Name",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Texto da última mensagem enviada aqui...",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "12/07/2026",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // LIST OF MESSAGES
  Widget _buildMessagesList(ThemeData theme) {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 12,
        separatorBuilder: (_, __) =>
            Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
        itemBuilder: (_, index) => _buildMessageItem(theme),
      ),
    );
  }

  // NEW MESSAGE BUTTON
  Widget _buildNewMessageButton(ThemeData theme) {
    return FloatingActionButton(
      onPressed: () {
        print('FloatingActionButton pressed ...');
      },
      backgroundColor: theme.colorScheme.primary,
      elevation: 8,
      child: Icon(
        Icons.add_rounded,
        color: theme.colorScheme.onPrimary,
        size: 24,
      ),
    );
  }

  // BODY
  Widget _buildBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(theme),
        _buildResultsHeader(theme),
        const SizedBox(height: 8),
        _buildMessagesList(theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: Text(
            'Mensagens',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0.5,
        ),
        floatingActionButton: _buildNewMessageButton(theme),
        body: SafeArea(child: _buildBody(theme)),
      ),
    );
  }
}
