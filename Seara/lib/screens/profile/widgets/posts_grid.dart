import 'package:flutter/material.dart';

class PostsGrid extends StatelessWidget {
  const PostsGrid({Key? key}) : super(key: key);

  // Mock image URLs (substitui por dados do backend)
  static final List<String> _images = List.generate(
    24,
    (i) => 'https://images.unsplash.com/photo-15${100 + i}?w=800&q=60',
  );

  @override
  Widget build(BuildContext context) {
    // Se quiseres load infinito, usa FutureBuilder + backend
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(1),
      itemCount: _images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final img = _images[index];
        return GestureDetector(
          onTap: () {
            // abrir post (mais tarde)
          },
          child: Container(
            color: Colors.grey[300],
            child: Image.network(img, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
