class LinkPreview {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String url;

  LinkPreview({
    this.title,
    this.description,
    this.imageUrl,
    required this.url,
  });

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      url: json['url'] as String,
    );
  }

  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      (description == null || description!.isEmpty) &&
      (imageUrl == null || imageUrl!.isEmpty);
}
