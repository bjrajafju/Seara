import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:seara/models/profile_model.dart';
import 'package:seara/services/profile/profile_service.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/upload_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final Profile profile;

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isHoveringAvatar = false;
  bool _isUploadingAvatar = false;

  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.bio);
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Builds avatar
  Widget _buildAvatar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringAvatar = true),
            onExit: (_) => setState(() => _isHoveringAvatar = false),
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: _isUploadingAvatar ? null : _pickAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      _avatarUrl ?? widget.profile.avatarUrl,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _isHoveringAvatar ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: cs.scrim.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit, color: cs.onSurface, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mudar foto de perfil',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
      ),
      keyboardType: TextInputType.text,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.done,
      maxLines: maxLines,
    );
  }

  /// Builds save button
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Guardar',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Saves profile
  Future<void> _saveProfile() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      await ProfileService.updateProfile(
        userId: userId,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatarUrl ?? widget.profile.avatarUrl,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains("Username já existe")
                ? "Username já existe"
                : 'Erro ao guardar perfil',
          ),
        ),
      );
    }
  }

  /// Picks avatar
  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );

    if (file == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await file.readAsBytes();

      final result = await UploadService.uploadFile(
        bucket: 'avatar',
        fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fileBytes: bytes,
        mimeType: 'image/jpeg',
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = result.url;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao atualizar avatar')));
    }
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAvatar(),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Nome',
              hint: 'O seu nome público',
              controller: _nameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Username',
              hint: 'O seu username único',
              controller: _usernameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Bio',
              hint: 'Escreva a sua biografia',
              controller: _bioController,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }
}
