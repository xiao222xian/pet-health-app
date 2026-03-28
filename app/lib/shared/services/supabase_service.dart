import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static Future<void> signOut() => client.auth.signOut();
}
