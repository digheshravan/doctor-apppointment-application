import 'package:flutter/material.dart';
import 'package:medi_slot/splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // supa base setup
  await Supabase.initialize(
      url: "https://iakgozqqfqxofautvert.supabase.co",
      anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlha2dvenFxZnF4b2ZhdXR2ZXJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDEzNjEsImV4cCI6MjA3MzE3NzM2MX0.PsKzicE_Fb7Rp-3ckQtuEHTUHUkremBBMQrNsBDrElM",
  );
  runApp(const DoctorAppointmentApp());
}

class DoctorAppointmentApp extends StatelessWidget {
  const DoctorAppointmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doctor Appointment App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const Splash(),
    );
  }
}
