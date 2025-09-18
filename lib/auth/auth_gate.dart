/*

AUTH GATE - This will continuously listen for auth state changes.

---------------------------------------------------------------------------------

unauthorized -> Login Page
authorized -> Signup Page

 */

import 'package:flutter/material.dart';
import 'package:medi_slot/screens/doctor/doctor_home.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/signup_screen.dart';

class AuthGate extends StatelessWidget{
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
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
            return const DoctorHome();
          }else{
            return const LoginScreen();
          }
        },
    );
  }
}