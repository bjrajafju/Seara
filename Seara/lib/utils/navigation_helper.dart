import 'package:flutter/material.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';

class NavigationHelper {
  /// Opens the profile of the specified user.
  /// If [userDbId] matches the current user's ID, it opens the current user's profile.
  static Future<void> openProfile(BuildContext context, int? userDbId) async {
    if (userDbId == null) return;

    final myId = await AuthService.getUserId();
    final targetId = (userDbId == myId) ? null : userDbId;

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: targetId),
        ),
      );
    }
  }
}
