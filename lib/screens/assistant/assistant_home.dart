import 'package:flutter/material.dart';
import 'package:medi_slot/screens/assistant/manage_appointments.dart';
import 'package:medi_slot/screens/assistant/upload_slots_page.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/auth_service.dart';
import 'assigned_clinics_page.dart';

class AssistantDashboard extends StatefulWidget {
  const AssistantDashboard({super.key});

  @override
  State<AssistantDashboard> createState() => _AssistantDashboardState();
}

class _AssistantDashboardState extends State<AssistantDashboard> {
  final AuthService authService = AuthService();
  final supabase = Supabase.instance.client;
  String? userName;
  String? assistantId;
  String? doctorId; // Doctor ID (nullable)
  String? assignedDoctorId; // Doctor assigned to assistant
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSessionValidity();
    initDashboard();
    loadDoctorData();
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

  Future<void> loadDoctorData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Try fetching as doctor
    final doctorResponse = await Supabase.instance.client
        .from('doctors')
        .select('doctor_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (doctorResponse != null) {
      setState(() {
        doctorId = doctorResponse['doctor_id'];
      });
    } else {
      // If not a doctor, check if assistant
      final assignedId = await fetchAssignedDoctorId(user.id);
      if (assignedId != null) {
        setState(() {
          assignedDoctorId = assignedId;
        });
      }
    }
  }

  Future<String?> fetchAssignedDoctorId(String userId) async {
    final response = await Supabase.instance.client
        .from('assistants')
        .select('assigned_doctor_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      print('No assistant record found for userId: $userId');
      return null;
    }

    return response['assigned_doctor_id'] as String?;
  }


  Future<void> initDashboard() async {
    setState(() => isLoading = true);

    try {
      final name = await authService.getCurrentUserName();
      final aId = await authService.getCurrentAssistantId();
      final dId = await authService.getCurrentDoctorId();
      final assignedId = await authService.getAssignedDoctorIdForAssistant();

      setState(() {
        userName = name ?? "Assistant";
        assistantId = aId;
        doctorId = dId;
        assignedDoctorId = assignedId;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error initializing dashboard: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> logout(BuildContext context) async {
    await authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Assistant Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 6,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  "Welcome, ${userName ?? 'Assistant'} 👩‍⚕️",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Upload Slots
              DashboardCard(
                icon: Icons.schedule,
                color: Colors.teal,
                title: "Upload Slots",
                onTap: () {
                  final effectiveDoctorId = doctorId ?? assignedDoctorId;

                  if (effectiveDoctorId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UploadSlotsPage(
                          doctorId: effectiveDoctorId,
                          assistantId: assistantId,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No Doctor assigned. Cannot upload slots."),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // Manage Appointments
              DashboardCard(
                icon: Icons.calendar_month,
                color: Colors.orange,
                title: "Manage Appointments",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageAppointmentsPage()),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Assist Doctors
              DashboardCard(
                icon: Icons.local_hospital,
                color: Colors.green,
                title: "Assist Doctors",
                onTap: () {
                  // TODO: Navigate to Assist Doctors screen
                },
              ),

              const SizedBox(height: 20),

              // Manage Patients
              DashboardCard(
                icon: Icons.people,
                color: Colors.blue,
                title: "Manage Patients",
                onTap: () {
                  // TODO: Navigate to Manage Patients screen
                },
              ),

              const SizedBox(height: 20),

              // Assigned Clinics
              if (assistantId != null)
                DashboardCard(
                  icon: Icons.local_hospital_outlined,
                  color: Colors.purple,
                  title: "Assigned Clinics",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignedClinicsPage(
                          assistantId: assistantId!,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withAlpha(25), // ✅ replaced deprecated withOpacity
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
