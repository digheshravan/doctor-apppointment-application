import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  SupabaseClient get client => _supabase;


  // 🕒 Duration for which session remains active (customize as needed)
  final Duration sessionDuration = const Duration(hours: 6);

  // ---------------------------------------------------------------------------
  // 🔹 Sign in with email & password + store session
  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await saveLoginSession(response.user!.id, email);
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Sign up with email & password + store session
  Future<AuthResponse> signUpWithEmailAndPassword(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await saveLoginSession(response.user!.id, email);
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Sign out (Supabase + local)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _clearLocalSession();
  }

  // ---------------------------------------------------------------------------
  // 🔹 Check if user is still logged in and session is valid
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final expiryTime = prefs.getInt('sessionExpiry');

    if (!isLoggedIn || expiryTime == null) return false;

    // ⏳ Check if session expired
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > expiryTime) {
      await signOut();
      return false;
    }

    // 🔒 Ensure Supabase session is still valid
    final user = _supabase.auth.currentUser;
    if (user == null) {
      await signOut();
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Save login session locally (after successful login/signup)
  Future<void> saveLoginSession(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final expiryTime = now.add(sessionDuration).millisecondsSinceEpoch;

    // Use email to detect role from profiles table only
    String role = await detectUserRole(email);

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    await prefs.setInt('sessionExpiry', expiryTime);
  }

  // ---------------------------------------------------------------------------
  // 🔹 Detect user role based on Supabase tables
  Future<String> detectUserRole(String email) async {
    try {
      // 1️⃣ Get profile by email
      final profile = await _supabase
          .from('profiles')
          .select('id, role')
          .eq('email', email)
          .maybeSingle();

      if (profile == null) return 'patient';

      final profileRole = profile['role'] as String?;
      if (profileRole != null && profileRole.isNotEmpty) return profileRole;

      // Default to patient if role is empty
      return 'patient';
    } catch (e) {
      print('⚠️ Role detection error: $e');
      return 'patient';
    }
  }

  // ---------------------------------------------------------------------------
// 🔹 Get current user role on app start (persistent login)
  Future<String> getCurrentUserRole() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ Check if role is already saved and session is valid
    final savedRole = prefs.getString('role');
    final userId = prefs.getString('userId');
    final expiry = prefs.getInt('sessionExpiry') ?? 0;

    if (savedRole != null && userId != null) {
      if (DateTime.now().millisecondsSinceEpoch < expiry) {
        return savedRole; // Return saved role if session is still valid
      }
    }

    // 2️⃣ If not saved or expired, check Supabase current user
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Patient'; // Not logged in

    // 3️⃣ Detect role from profiles table
    final email = user.email!;
    final role = await detectUserRole(email);

    // 4️⃣ Save role and session again
    await saveLoginSession(user.id, email);

    return role;
  }


  // ---------------------------------------------------------------------------
  // 🔹 Retrieve stored role
  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  // ---------------------------------------------------------------------------
  // 🔹 Clear all session data
  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ---------------------------------------------------------------------------
  // 🔹 Get current user email
  String? getCurrentUserEmail() {
    final user = _supabase.auth.currentUser;
    return user?.email;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Get current user name (from profiles table)
  Future<String?> getCurrentUserName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();

    return response?['name'] as String?;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Doctor/Assistant related methods
  Future<String?> getCurrentDoctorId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('doctors')
        .select('doctor_id')
        .eq('user_id', user.id)
        .maybeSingle();

    return response?['doctor_id'] as String?;
  }

  // 🔹 Fetch all appointments assigned to the logged-in doctor (with patient details)
  Future<List<Map<String, dynamic>>> getAppointmentsForCurrentDoctor() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Step 1: Identify doctor id (or assistant’s assigned doctor)
    String? doctorId = await getCurrentDoctorId();
    doctorId ??= await getAssignedDoctorIdForAssistant();
    print('👨‍⚕️ Doctor ID: $doctorId');
    print('🔑 Current Supabase User ID: ${_supabase.auth.currentUser?.id}');
    if (doctorId == null) return [];

    // Step 2: Fetch appointments joined with patient details
    final response = await _supabase
        .from('appointments')
        .select('''
        appointment_id,
        appointment_date,
        appointment_time,
        reason,
        status,
        report_url,
        visit_status,
        patients(
          patient_id,
          name,
          age,
          gender
        )
      ''')
        .eq('doctor_id', doctorId)
        .order('appointment_date', ascending: true);

    if (response == null || response is! List) return [];

    return List<Map<String, dynamic>>.from(response);
  }

  Future<String?> getCurrentAssistantId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('assistants')
        .select('assistant_id')
        .eq('user_id', user.id)
        .maybeSingle();

    return response?['assistant_id'] as String?;
  }

  Future<String?> getAssignedDoctorIdForAssistant() async {
    final assistantId = await getCurrentAssistantId();
    if (assistantId == null) return null;

    final response = await _supabase
        .from('assistants')
        .select('assigned_doctor_id')
        .eq('assistant_id', assistantId)
        .maybeSingle();

    return response?['assigned_doctor_id'] as String?;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Appointments data
  Future<int> getTotalPatientsCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    String? doctorId = await getCurrentDoctorId();
    doctorId ??= await getAssignedDoctorIdForAssistant();

    if (doctorId == null) return 0;

    final response = await _supabase
        .from('appointments')
        .select('appointment_id')
        .eq('doctor_id', doctorId)
        .not('status', 'in', ['cancelled', 'rejected']);

    if (response == null || response is! List) return 0;

    return response.length;
  }

  Future<List<Map<String, dynamic>>> getTodayAppointments() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    String? doctorId = await getCurrentDoctorId();
    doctorId ??= await getAssignedDoctorIdForAssistant();
    if (doctorId == null) return [];

    final today = DateTime.now().toIso8601String().split('T').first;

    final response = await _supabase
        .from('appointments')
        .select('''
        status, 
        visit_status, 
        appointment_time, 
        patients!inner(name, age, gender, patient_id)
      ''')
        .eq('doctor_id', doctorId)
        .eq('appointment_date', today)
        .eq('visit_status', 'active');

    if (response == null || response is! List) return [];

    return response.map<Map<String, dynamic>>((row) {
      final name = row['patients']?['name'] ?? 'Unknown';
      final time = row['appointment_time'] ?? 'N/A';
      final status = row['status'] ?? 'Pending';
      final visitStatus = row['visit_status'] ?? 'inactive';
      return {
        'name': name,
        'time': time,
        'status': status,
        'visit_status': visitStatus
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
// 🔹 Fetch all approved doctors with profile info
  Future<List<Map<String, dynamic>>> getApprovedDoctors() async {
    try {
      final response = await _supabase
          .from('doctors')
          .select('doctor_id, user_id, specialization, experience_years, status, photo_url, qualification, consultation_fee, profiles(id, name, email)')
          .eq('status', 'approved');

      if (response == null || response is! List) return [];

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("⚠️ Error fetching doctors: $e");
      return [];
    }
  }

  Future<String?> getCurrentAssistantName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('❌ No Supabase user found (not logged in)');
      return null;
    }

    print('👤 Current Supabase user ID: ${user.id}');

    try {
      // Step 1: Fetch assistant record
      final assistantResponse = await _supabase
          .from('assistants')
          .select('assistant_id, user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      print('🧩 Assistant record fetched: $assistantResponse');

      if (assistantResponse == null) {
        print('⚠️ No assistant record found for this user ID');
        return null;
      }

      // Step 2: Fetch the assistant’s name from profiles
      final profileResponse = await _supabase
          .from('profiles')
          .select('name')
          .eq('id', assistantResponse['user_id'])
          .maybeSingle();

      print('📇 Profile record fetched: $profileResponse');

      if (profileResponse == null) {
        print('⚠️ No profile found for user_id: ${assistantResponse['user_id']}');
        return null;
      }

      print('✅ Assistant name: ${profileResponse['name']}');
      return profileResponse['name'] as String?;
    } catch (e, st) {
      print('🚨 Error fetching assistant name: $e');
      print('📜 Stacktrace: $st');
      return null;
    }
  }

  // 🔹 Get Pending Approvals Count
  Future<int> getPendingApprovalsCountForAssistant() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      // 1️⃣ Fetch assigned doctor for assistant
      final assistant = await _supabase
          .from('assistants')
          .select('assigned_doctor_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final doctorId = assistant?['assigned_doctor_id'];
      if (doctorId == null) return 0;

      // 2️⃣ Get pending appointments list
      final response = await _supabase
          .from('appointments')
          .select('appointment_id')
          .eq('doctor_id', doctorId)
          .eq('status', 'pending');

      // 3️⃣ Count manually
      return response.length;
    } catch (e) {
      print('⚠️ Error fetching pending approvals count: $e');
      return 0;
    }
  }

// 🔹 Get Total Patients Count
  Future<int> getTotalPatientsCountForAssistant() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      // 1️⃣ Get assigned doctor
      final assistant = await _supabase
          .from('assistants')
          .select('assigned_doctor_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final doctorId = assistant?['assigned_doctor_id'];
      if (doctorId == null) return 0;

      // 2️⃣ Fetch all patients for this doctor
      final response = await _supabase
          .from('appointments')
          .select('patient_id')
          .eq('doctor_id', doctorId);

      // 3️⃣ Get unique patients
      final uniquePatients =
          response.map((row) => row['patient_id']).toSet().length;

      return uniquePatients;
    } catch (e) {
      print('⚠️ Error fetching total patients count: $e');
      return 0;
    }
  }

// 🔹 Get Today's Appointments Count
  Future<int> getTodaysAppointmentsCountForAssistant() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      // 1️⃣ Get assigned doctor
      final assistant = await _supabase
          .from('assistants')
          .select('assigned_doctor_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final doctorId = assistant?['assigned_doctor_id'];
      if (doctorId == null) return 0;

      // 2️⃣ Filter by today's date
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('appointments')
          .select('appointment_id')
          .eq('doctor_id', doctorId)
          .eq('appointment_date', today);

      // 3️⃣ Return total count
      return response.length;
    } catch (e) {
      print('⚠️ Error fetching today’s appointments count: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  String? get currentUserId => _supabase.auth.currentUser?.id;
}