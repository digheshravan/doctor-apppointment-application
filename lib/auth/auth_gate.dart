/*
AUTH GATE - This will continuously listen for auth state changes.
---------------------------------------------------------------------------------
unauthorized -> Login Page
authorized -> Signup Page
 */

import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/admin/admin_dashboard.dart';
import 'package:medi_slot/screens/assistant/assistant_home.dart';
import 'package:medi_slot/screens/doctor/doctor_home.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:medi_slot/screens/patient/patient.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget{
  const AuthGate({super.key});

  Future<Widget> _dashboardForCurrentUser() async {
    final authService = AuthService();
    final role = await authService.getCurrentUserRole();

    switch (role.toLowerCase()) {
      case 'admin':
        return const AdminDashboard();
      case 'doctor':
        final doctorId = await authService.getCurrentDoctorId();
        return DoctorDashboard(doctorId: doctorId ?? '');
      case 'assistant':
        return const AssistantDashboardScreen();
      case 'patient':
      default:
        return const PatientDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        // Listen to auth state changes
        stream: Supabase.instance.client.auth.onAuthStateChange,

        // Build appropriate page based on auth state
        builder: (context, snapshot) {
          //loading...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }


          // check if there is valid session currently
          final session = snapshot.hasData ? snapshot.data!.session : null;

          if(session != null){
            return FutureBuilder<Widget>(
              future: _dashboardForCurrentUser(),
              builder: (context, routeSnapshot) {
                if (routeSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                return routeSnapshot.data ?? const PatientDashboard();
              },
            );
          }else{
            return const LoginScreen();
          }
        },
    );
  }
}
