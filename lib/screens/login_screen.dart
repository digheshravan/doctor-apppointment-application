import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/admin/admin_dashboard.dart';
import 'package:medi_slot/screens/assistant/assistant_home.dart';
import 'package:medi_slot/screens/doctor/doctor_home.dart';
import 'package:medi_slot/screens/patient/patient.dart';
import 'package:medi_slot/screens/signup_screen.dart';
// Note: You may not need SharedPreferences here if AuthService handles session
// import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1️⃣ Sign in using Supabase auth
      final response =
      await _authService.signInWithEmailAndPassword(email, password);

      if (response.user == null) throw Exception("Invalid email or password");

      final userId = response.user!.id;

      // 2️⃣ Detect role directly from profiles table
      final role = await _authService.detectUserRole(email);

      // 3️⃣ Save session
      await _authService.saveLoginSession(userId, role);

      // 4️⃣ Navigate to dashboard based on role
      Widget nextScreen;
      switch (role.toLowerCase()) {
        case 'admin':
          nextScreen = const AdminDashboard();
          break;
        case 'doctor':
        // FIXME: You need to fetch the doctorId associated with this userId
        // This navigation might fail if doctorId is required and not 'admin'
        // For now, passing a placeholder. You must fix this logic.
          nextScreen = const DoctorDashboard(
              doctorId: ''); // Placeholder, needs correct logic
          break;
        case 'assistant':
          nextScreen = const AssistantDashboardScreen();
          break;
        case 'patient':
        default:
          nextScreen = const PatientDashboard();
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Define the color scheme from SignupScreen
    final Color primaryColor = const Color(0xFF00A9F1);
    final Color accentColor = const Color(0xFF0077B6);
    final Color backgroundColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Sign In',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // This automatically adds a back button if navigated to,
        // or can be used to explicitly add one if needed.
        iconTheme: const IconThemeData(color: Colors.black87),
        automaticallyImplyLeading: false, // Remove back button if not needed
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Text
                Text(
                  "Welcome Back!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to your account to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 48), // More space for login

                // Email Field
                _buildTextField(
                  label: 'Email Address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                  !v!.contains("@") ? "Enter a valid email address" : null,
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                // Password Field
                _buildTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isObscure: _obscurePassword,
                  validator: (v) => v!.length < 6
                      ? "Password must be at least 6 characters"
                      : null,
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[600]),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 32),

                // Sign In Button
                ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ))
                      : const Text('Sign In',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),

                // Sign Up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?",
                        style: TextStyle(color: Colors.grey[700])),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignupScreen())),
                      child: Text('Sign Up',
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable helper widget for text form fields
  // (Copied from SignupScreen for consistent UI)
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    IconData? icon,
  }) {
    final Color primaryColor = const Color(0xFF00A9F1);
    final Color textFieldFillColor = Colors.grey[100]!;
    final Color errorColor = Colors.redAccent[700]!;

    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.grey[800], fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        prefixIcon:
        icon != null ? Icon(icon, color: primaryColor, size: 20) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: textFieldFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[350]!, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        errorStyle: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16), // Consistent padding
      ),
    );
  }
}