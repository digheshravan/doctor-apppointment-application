// assistant_dashboard.dart
import 'package:flutter/material.dart';
import 'package:medi_slot/screens/assistant/manage_appointments.dart';
import 'package:medi_slot/screens/login_screen.dart';
import '../../auth/auth_service.dart';
import 'assigned_clinics_page.dart'; // Import Assigned Clinics page

class AssistantDashboard extends StatefulWidget {
  const AssistantDashboard({super.key});

  @override
  State<AssistantDashboard> createState() => _AssistantDashboardState();
}

class _AssistantDashboardState extends State<AssistantDashboard> {
  final AuthService authService = AuthService();
  String? userName;
  String? assistantId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initDashboard();
  }

  /// Initialize user and assistant info
  Future<void> initDashboard() async {
    setState(() => isLoading = true);

    try {
      final name = await authService.getCurrentUserName();
      final id = await authService.getCurrentAssistantId();

      setState(() {
        userName = name ?? "Assistant";
        assistantId = id;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error initializing dashboard: $e");
      setState(() => isLoading = false);
    }
  }

  /// Logout function
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
      // Gradient AppBar
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
            tooltip: "Logout",
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome, ${userName ?? 'Assistant'} 👩‍⚕️",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 30),

            // Manage Appointments
            DashboardCard(
              icon: Icons.calendar_month,
              color: Colors.orange,
              title: "Manage Appointments",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageAppointmentsPage(),
                  ),
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
    );
  }
}

/// DashboardCard Widget
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
                backgroundColor: color.withValues(alpha: 0.1),
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
