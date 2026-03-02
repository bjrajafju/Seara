import 'dart:math';
import 'package:flutter/material.dart';
import 'package:seara/models/profile_model.dart';
import 'package:seara/services/profile_service.dart';
import 'package:seara/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final Profile profile;

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isHoveringAvatar = false;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ---------- Widgets Privados ----------

  Widget _buildAvatar() {
    return Center(
      child: Column(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringAvatar = true),
            onExit: (_) => setState(() => _isHoveringAvatar = false),
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: () {},
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(widget.profile.avatarUrl),
                  ),
                  AnimatedOpacity(
                    opacity: _isHoveringAvatar ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Change profile photo',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
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

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Save',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ---------- Função de salvar ----------
  Future<void> _saveProfile() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      await ProfileService.updateProfile(
        userId: userId,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: widget.profile.avatarUrl,
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

  // ---------- Build Principal ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAvatar(),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Name',
              hint: 'Your name',
              controller: _nameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Username',
              hint: 'Unique username',
              controller: _usernameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Bio',
              hint: 'Write your bio',
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
