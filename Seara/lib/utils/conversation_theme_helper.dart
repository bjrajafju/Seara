import 'package:flutter/material.dart';

/// Theme colors for conversation backgrounds and bubbles
/// Maps to integer IDs stored in DB (conversation_settings.theme)
class ConversationThemeHelper {
  static const List<ConversationThemeData> themes = [
    ConversationThemeData(
      id: 0,
      name: 'Padrão',
      // Maintaining the dark modern background for default
      backgroundColors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
      myBubbleColor: Color(0xFF1C63B8), // Muted dark blue
      otherBubbleColor: Color(0xFF38383A), // Dark grey
      myTextColor: Colors.white,
      otherTextColor: Colors.white,
    ),
    ConversationThemeData(
      id: 1,
      name: 'Oceano',
      backgroundColors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
      myBubbleColor: Color(0xFF1B5E7E),
      otherBubbleColor: Color(0xFF0D3248),
      myTextColor: Colors.white,
      otherTextColor: Colors.white,
    ),
    ConversationThemeData(
      id: 2,
      name: 'Pôr do Sol',
      backgroundColors: [Color(0xFF2D1B69), Color(0xFF862F58)],
      myBubbleColor: Color(0xFF7B2D5F),
      otherBubbleColor: Color(0xFF3D2470),
      myTextColor: Colors.white,
      otherTextColor: Colors.white,
    ),
    ConversationThemeData(
      id: 3,
      name: 'Floresta',
      backgroundColors: [Color(0xFF0B3D2C), Color(0xFF1A5C3A)],
      myBubbleColor: Color(0xFF1E6B3F),
      otherBubbleColor: Color(0xFF0E4530),
      myTextColor: Colors.white,
      otherTextColor: Colors.white,
    ),
    ConversationThemeData(
      id: 4,
      name: 'Meia-noite',
      backgroundColors: [Color(0xFF0A0A1A), Color(0xFF1A1A3A)],
      myBubbleColor: Color(0xFF2A2A5A),
      otherBubbleColor: Color(0xFF141430),
      myTextColor: Colors.white,
      otherTextColor: Colors.white,
    ),
  ];

  static ConversationThemeData getTheme(int id) {
    if (id < 0 || id >= themes.length) return themes[0];
    return themes[id];
  }
}

class ConversationThemeData {
  final int id;
  final String name;
  final List<Color> backgroundColors;
  final Color? myBubbleColor;
  final Color? otherBubbleColor;
  final Color? myTextColor;
  final Color? otherTextColor;

  const ConversationThemeData({
    required this.id,
    required this.name,
    required this.backgroundColors,
    this.myBubbleColor,
    this.otherBubbleColor,
    this.myTextColor,
    this.otherTextColor,
  });

  /// Returns true if this is the default theme (no custom colors)
  bool get isDefault => id == 0;

  /// Background decoration for the conversation
  BoxDecoration get backgroundDecoration => BoxDecoration(
        gradient: LinearGradient(
          colors: backgroundColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
}
