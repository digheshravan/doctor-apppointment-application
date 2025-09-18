import 'package:flutter/material.dart';
import 'package:medi_slot/screens/assistant/assistant_home.dart';
import 'package:medi_slot/screens/doctor/doctor_home.dart';
import 'package:medi_slot/screens/patient/patient.dart';
import 'package:medi_slot/screens/signup_screen.dart';
import 'package:medi_slot/screens/admin/admin_dashboard.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // Updated login function with Admin check
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1️⃣ Check admin table first
      final adminData = await supabase
          .from('admin')
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      if (adminData != null) {
        // Admin login successful
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
        return;
      }

      // 2️⃣ Normal Supabase login
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception("Login failed");

      // 3️⃣ Fetch role from profiles
      final profileData = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final role = profileData['role'] as String?;
      if (role == null) throw Exception("Role not found");

      // 4️⃣ Check Doctor approval (already implemented)
      if (role == "Doctor") {
        final doctorData = await supabase
            .from('doctors')
            .select('status')
            .eq('user_id', user.id)
            .single();

        final status = doctorData['status'] as String?;
        if (status != 'approved') {
          String msg = status == 'pending'
              ? "Your account is pending approval by admin."
              : "Your account has been rejected.";
          throw Exception(msg);
        }
      }

      // 5️⃣ Check Assistant approval
      if (role == "Assistant") {
        final assistantData = await supabase
            .from('assistants')
            .select('status')
            .eq('user_id', user.id)
            .single();

        final status = assistantData['status'] as String?;
        if (status != 'approved') {
          String msg = status == 'pending'
              ? "Your account is pending approval by your assigned doctor."
              : "Your account has been rejected by the doctor.";
          throw Exception(msg);
        }
      }

      // 6️⃣ Navigate based on role
      if (mounted) {
        if (role == "Doctor") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DoctorHome()),
          );
        } else if (role == "Patient") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PatientDashboard()),
          );
        } else if (role == "Assistant") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AssistantDashboard()),
          );
        } else {
          throw Exception("Unknown role: $role");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Login",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black,),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                  value != null && value.contains("@") ? null : "Enter a valid email",
                ),
                const SizedBox(height: 16),

                // Password with visibility toggle
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) => value != null && value.length >= 6
                      ? null
                      : "Password must be at least 6 chars",
                ),
                const SizedBox(height: 10),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: implement password reset
                    },
                    child: const Text("Forgot Password?"),
                  ),
                ),
                const SizedBox(height: 20),

                // Login Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.transparent, // transparent to show gradient
                      shadowColor: Colors.transparent,     // remove shadow so gradient is clean
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Login",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // No account? Signup
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don’t have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
