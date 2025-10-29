import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:medi_slot/screens/admin/admin_dashboard.dart';
import 'package:medi_slot/screens/doctor/doctor_home.dart';
import 'package:medi_slot/screens/assistant/assistant_home.dart';
import 'package:medi_slot/screens/patient/patient.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));

    final authService = AuthService();
    final user = authService.client.auth.currentUser;

    if (user != null) {
      // ✅ User is logged in in Supabase, fetch role from profiles table
      final role = await authService.detectUserRole(user.email!); // always fetch from Supabase

      // Navigate to respective dashboard
      Widget nextScreen;
      switch (role.toLowerCase()) {
        case 'admin':
          nextScreen = const AdminDashboard();
          break;
        case 'doctor':
          nextScreen = const DoctorDashboard(doctorId: '',);
          break;
        case 'assistant':
          nextScreen = const AssistantDashboardScreen();
          break;
        case 'patient':
        default:
          nextScreen = const PatientDashboard();
      }

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
        );
      }
    } else {
      // ❌ Not logged in
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Image(
            image: AssetImage('assets/icon/MediSlot.png'),
            height: 150,
            width: 150,
          ),
        ),
      ),
    );
  }
}