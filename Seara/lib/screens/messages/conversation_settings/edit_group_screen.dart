import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/services/upload_service.dart';

class EditGroupScreen extends StatefulWidget {
  const EditGroupScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.currentName,
    this.currentImage,
  });

  final int conversationId;
  final int userId;
  final String currentName;
  final String? currentImage;

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  late TextEditingController _nameController;
  String? _imageUrl;
  bool _isSaving = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _imageUrl = widget.currentImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (file == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await file.readAsBytes();
      final result = await UploadService.uploadFile(
        bucket: 'attachments',
        fileName: 'group_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fileBytes: bytes,
        mimeType: 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _imageUrl = result.url;
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar imagem: ${e.toString()}')),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome não pode estar vazio.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update name if changed
      if (name != widget.currentName) {
        await ConversationSettingsService.updateName(
          widget.conversationId,
          widget.userId,
          name,
        );
      }

      // Update image if changed
      if (_imageUrl != widget.currentImage && _imageUrl != null) {
        await ConversationSettingsService.updateImage(
          widget.conversationId,
          widget.userId,
          _imageUrl!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'Editar grupo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundImage: _imageUrl != null
                          ? NetworkImage(_imageUrl!)
                          : null,
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      child: _imageUrl == null
                          ? Icon(
                              Icons.group_rounded,
                              size: 40,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.scrim.withAlpha(140),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    if (!_isUploading)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Toca para alterar a imagem',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Name field
            Text(
              'Nome do grupo',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: theme.textTheme.bodyLarge,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'Nome do grupo',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(80),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
