import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // implementação simples: campos para nome, bio e guardar
    final nameController = TextEditingController(text: 'Daniel');
    final bioController = TextEditingController(text: 'Desenvolvedor · Criador');

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar placeholder
            const CircleAvatar(radius: 48, backgroundColor: Colors.grey),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 8),
            TextField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // guardar alterações -> enviar para backend
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
