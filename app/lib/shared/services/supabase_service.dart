import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;
  static final ValueNotifier<int> dataVersion = ValueNotifier(0);
  static final ValueNotifier<int> profileVersion = ValueNotifier(0);

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static void notifyDataChanged() {
    dataVersion.value++;
  }

  static void notifyProfileChanged() {
    profileVersion.value++;
  }

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static Future<void> signOut() => client.auth.signOut();
}
