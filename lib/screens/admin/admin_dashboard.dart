import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:flutter/material.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService authService = AuthService();
  final supabase = Supabase.instance.client;
  List<dynamic> pendingDoctors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSessionValidity();
    fetchPendingDoctors();
  }

  Future<void> _checkSessionValidity() async {
    final isValid = await authService.isUserLoggedIn();
    if (!isValid) {
      // Session expired → redirect to login
      if (mounted) {
        await authService.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> fetchPendingDoctors() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('doctors')
          .select('doctor_id, user_id, phone, gender, specialization')
          .eq('status', 'pending');

      // Fetch the doctor's name and email from profiles
      List<dynamic> doctorsWithProfiles = [];
      for (var doctor in data) {
        final profile = await supabase
            .from('profiles')
            .select('name, email')
            .eq('id', doctor['user_id'])
            .single();
        doctorsWithProfiles.add({
          ...doctor,
          'name': profile['name'],
          'email': profile['email'],
        });
      }

      setState(() {
        pendingDoctors = doctorsWithProfiles;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching pending doctors: $e")),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> approveDoctor(String doctorId) async {
    try {
      await supabase
          .from('doctors')
          .update({'status': 'approved'})
          .eq('doctor_id', doctorId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doctor approved!")),
      );
      fetchPendingDoctors();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error approving doctor: $e")),
      );
    }
  }

  Future<void> rejectDoctor(String doctorId) async {
    try {
      await supabase
          .from('doctors')
          .update({'status': 'rejected'})
          .eq('doctor_id', doctorId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doctor rejected!")),
      );
      fetchPendingDoctors();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error rejecting doctor: $e")),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing out: $e")),
        );
      }
    }
  }

  Widget buildDoctorCard(Map doctor, int index) {
    final colors = [
      [Colors.deepPurple, Colors.purpleAccent],
      [Colors.teal, Colors.greenAccent],
      [Colors.indigo, Colors.blueAccent],
      [Colors.orange, Colors.deepOrangeAccent],
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors[index % colors.length],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  doctor['name'][0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor['name'],
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      doctor['email'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "Specialization: ${doctor['specialization']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                    onPressed: () => approveDoctor(doctor['doctor_id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => rejectDoctor(doctor['doctor_id']),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
            onPressed: signOut,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Pending Doctors: ${pendingDoctors.length}",
              style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingDoctors.isEmpty
          ? const Center(
          child: Text(
            "No pending doctors 🩺",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ))
          : ListView.builder(
        itemCount: pendingDoctors.length,
        itemBuilder: (context, index) =>
            buildDoctorCard(pendingDoctors[index], index),
      ),
    );
  }
}
