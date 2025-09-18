import 'package:flutter/material.dart';
import 'package:medi_slot/screens/doctor/assistant_requests.dart';
import 'package:medi_slot/screens/login_screen.dart';
import '../../auth/auth_service.dart';

class DoctorHome extends StatefulWidget {
  const DoctorHome({super.key});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  final authService = AuthService();
  String? userName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    final name = await authService.getCurrentUserName();
    setState(() {
      userName = name ?? "Doctor";
      isLoading = false;
    });
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

  void goToAssistantRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DoctorDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Gradient AppBar with Logout
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
          "Doctor Dashboard",
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Welcome Text
            Text(
              "Welcome, Dr. ${userName ?? 'Doctor'} 🩺",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 30),

            // ✅ Responsive Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount =
                  constraints.maxWidth > 600 ? 2 : 1; // responsive
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 2.5,
                    children: [
                      DashboardCard(
                        icon: Icons.edit_note,
                        color: Colors.teal,
                        title: "Write Prescription",
                        onTap: () {
                          // TODO: Navigate to Write Prescription screen
                        },
                      ),
                      DashboardCard(
                        icon: Icons.assignment,
                        color: Colors.indigo,
                        title: "View Prescriptions",
                        onTap: () {
                          // TODO: Navigate to View Prescriptions screen
                        },
                      ),
                      DashboardCard(
                        icon: Icons.group,
                        color: Colors.orange,
                        title: "View Assistant Requests",
                        onTap: goToAssistantRequests,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 20),

              // ✅ Expanded prevents overflow
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}