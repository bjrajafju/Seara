import 'package:flutter/widgets.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 600;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1100;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1100;
  }

  static double messageMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return width * 0.66; // mobile
    }

    if (width < 1100) {
      return width * 0.45; // tablet
    }

    return width * 0.33; // desktop
  }
}
