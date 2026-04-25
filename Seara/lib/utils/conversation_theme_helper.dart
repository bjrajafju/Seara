import 'package:flutter/material.dart';

class ConversationThemeHelper {
  static const List<ConversationThemeData> themes = [
    ConversationThemeData(
      id: 0,
      name: 'Padrão',
      backgroundColors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
      myBubbleColor: Color(0xFF1C63B8),
      otherBubbleColor: Color(0xFF38383A),
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
    ConversationThemeData(
      id: 5,
      name: 'AMOLED',
      backgroundColors: [Color(0xFF000000), Color(0xFF0A0A0A)],
      myBubbleColor: Color(0xFF1A0055),
      otherBubbleColor: Color(0xFF1A1A1A),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFEEEEEE),
    ),
    ConversationThemeData(
      id: 6,
      name: 'Nord',
      backgroundColors: [Color(0xFF2E3440), Color(0xFF3B4252)],
      myBubbleColor: Color(0xFF4C566A),
      otherBubbleColor: Color(0xFF434C5E),
      myTextColor: Color(0xFFECEFF4),
      otherTextColor: Color(0xFFD8DEE9),
    ),
    ConversationThemeData(
      id: 7,
      name: 'Dracula',
      backgroundColors: [Color(0xFF282A36), Color(0xFF1E1F29)],
      myBubbleColor: Color(0xFF44475A),
      otherBubbleColor: Color(0xFF383A4A),
      myTextColor: Color(0xFFF8F8F2),
      otherTextColor: Color(0xFFCDD6F4),
    ),
    ConversationThemeData(
      id: 8,
      name: 'Mocha',
      backgroundColors: [Color(0xFF1E1E2E), Color(0xFF181825)],
      myBubbleColor: Color(0xFF45475A),
      otherBubbleColor: Color(0xFF313244),
      myTextColor: Color(0xFFCDD6F4),
      otherTextColor: Color(0xFFBAC2DE),
    ),
    ConversationThemeData(
      id: 9,
      name: 'Rosa',
      backgroundColors: [Color(0xFFFFF0F5), Color(0xFFFFD6E7)],
      myBubbleColor: Color(0xFFAD1457),
      otherBubbleColor: Color(0xFFFCCEDE),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFF3A0024),
    ),
    ConversationThemeData(
      id: 10,
      name: 'Sakura',
      backgroundColors: [Color(0xFFFFF5F9), Color(0xFFFFD6F0)],
      myBubbleColor: Color(0xFFE91E8C),
      otherBubbleColor: Color(0xFFFFCCE8),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFF3A0020),
    ),
    ConversationThemeData(
      id: 11,
      name: 'Ambar',
      backgroundColors: [Color(0xFFFFFBF0), Color(0xFFFFF3CC)],
      myBubbleColor: Color(0xFFF59F00),
      otherBubbleColor: Color(0xFFFFE8A1),
      myTextColor: Color(0xFF3D2000),
      otherTextColor: Color(0xFF2C1A00),
    ),
    ConversationThemeData(
      id: 12,
      name: 'Artico',
      backgroundColors: [Color(0xFFF0F8FF), Color(0xFFDCF0FF)],
      myBubbleColor: Color(0xFF0277BD),
      otherBubbleColor: Color(0xFFB3E5FC),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFF002B49),
    ),
    ConversationThemeData(
      id: 13,
      name: 'Lavanda',
      backgroundColors: [Color(0xFF1A1230), Color(0xFF2D1F4A)],
      myBubbleColor: Color(0xFF7C3AED),
      otherBubbleColor: Color(0xFF2D1F4A),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFE9D5FF),
    ),
    ConversationThemeData(
      id: 14,
      name: 'Coral',
      backgroundColors: [Color(0xFF1A0A05), Color(0xFF2D1510)],
      myBubbleColor: Color(0xFFE84545),
      otherBubbleColor: Color(0xFF3D1A15),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFFFD5D5),
    ),
    ConversationThemeData(
      id: 15,
      name: 'Ardosia',
      backgroundColors: [Color(0xFF0F172A), Color(0xFF1E293B)],
      myBubbleColor: Color(0xFF334155),
      otherBubbleColor: Color(0xFF1E293B),
      myTextColor: Color(0xFFE2E8F0),
      otherTextColor: Color(0xFFCBD5E1),
    ),
    ConversationThemeData(
      id: 16,
      name: 'Esmeralda',
      backgroundColors: [Color(0xFF022C22), Color(0xFF064E3B)],
      myBubbleColor: Color(0xFF059669),
      otherBubbleColor: Color(0xFF065F46),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFD1FAE5),
    ),
    ConversationThemeData(
      id: 17,
      name: 'Cobre',
      backgroundColors: [Color(0xFF1C0A00), Color(0xFF2E1400)],
      myBubbleColor: Color(0xFFB45309),
      otherBubbleColor: Color(0xFF3D1C00),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFFDE68A),
    ),
    ConversationThemeData(
      id: 18,
      name: 'Aguarela',
      backgroundColors: [Color(0xFF0C1445), Color(0xFF1A237E)],
      myBubbleColor: Color(0xFF283593),
      otherBubbleColor: Color(0xFF1A237E),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFE8EAF6),
    ),
    ConversationThemeData(
      id: 19,
      name: 'Vulcao',
      backgroundColors: [Color(0xFF1A0000), Color(0xFF3D0000)],
      myBubbleColor: Color(0xFFB71C1C),
      otherBubbleColor: Color(0xFF3D0000),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFFFCDD2),
    ),
    ConversationThemeData(
      id: 20,
      name: 'Nebula',
      backgroundColors: [Color(0xFF0D0D1A), Color(0xFF1A0D2E)],
      myBubbleColor: Color(0xFF4A148C),
      otherBubbleColor: Color(0xFF1A0D2E),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFE1BEE7),
    ),
    ConversationThemeData(
      id: 21,
      name: 'Branco Puro',
      backgroundColors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
      myBubbleColor: Color(0xFF1976D2),
      otherBubbleColor: Color(0xFFEEEEEE),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFF212121),
    ),
    ConversationThemeData(
      id: 22,
      name: 'Outono',
      backgroundColors: [Color(0xFF1A0E00), Color(0xFF2D1900)],
      myBubbleColor: Color(0xFFD4500A),
      otherBubbleColor: Color(0xFF3D2200),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFFFE0B2),
    ),
    ConversationThemeData(
      id: 23,
      name: 'Gelo',
      backgroundColors: [Color(0xFFE8F4FD), Color(0xFFD0E8F8)],
      myBubbleColor: Color(0xFF0288D1),
      otherBubbleColor: Color(0xFFB3D9F5),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFF01579B),
    ),
    ConversationThemeData(
      id: 24,
      name: 'Roxo Escuro',
      backgroundColors: [Color(0xFF12001F), Color(0xFF200033)],
      myBubbleColor: Color(0xFF6A1B9A),
      otherBubbleColor: Color(0xFF280040),
      myTextColor: Colors.white,
      otherTextColor: Color(0xFFE1BEE7),
    ),
  ];

  /// Returns the theme data for the selected conversation style
  static ConversationThemeData getTheme(int id) {
    try {
      return themes.firstWhere((t) => t.id == id);
    } catch (_) {
      return themes[0];
    }
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

  bool get isDefault => id == 0;

  BoxDecoration get backgroundDecoration => BoxDecoration(
    gradient: LinearGradient(
      colors: backgroundColors,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}
