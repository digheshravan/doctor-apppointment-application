import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmailAndPassword(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  // Get current user name from profiles table
  Future<String?> getCurrentUserName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return response['name'] as String?;
  }

  // ✅ Get current doctor's ID from doctors table
  Future<String?> getCurrentDoctorId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('doctors')
        .select('doctor_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return response['doctor_id'] as String?;
  }
  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<String?> getCurrentAssistantId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('assistants')
        .select('assistant_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return response['assistant_id'] as String?;
  }

}
