import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  UserRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient => _client ?? Supabase.instance.client;

  /// Gets the current authenticated user's ID.
  String? get currentAuthId {
    try {
      return _effectiveClient.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Gets the theme preference for a specific user from the database.
  Future<String?> getUserTheme(String authId) async {
    try {
      final response = await _effectiveClient
          .from('users')
          .select('theme')
          .eq('auth_id', authId)
          .maybeSingle();
      
      return response?['theme'] as String?;
    } catch (e) {
      // If error (e.g. column doesn't exist yet), return null to use local fallback
      return null;
    }
  }

  /// Updates the theme preference for a specific user in the database.
  Future<void> setUserTheme(String authId, String theme) async {
    try {
      await _effectiveClient
          .from('users')
          .update({'theme': theme})
          .eq('auth_id', authId);
    } catch (e) {
      // Silent fail if column doesn't exist or other DB issues
    }
  }
}
