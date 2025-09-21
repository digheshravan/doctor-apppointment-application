import 'package:flutter/material.dart';
import 'package:medi_slot/screens/doctor/assistant_requests.dart';
import 'package:medi_slot/screens/doctor/edit_clinic_page.dart';
import 'package:medi_slot/screens/login_screen.dart';
import '../../auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorHome extends StatefulWidget {
  const DoctorHome({super.key});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  final authService = AuthService();
  String? userName;
  String? doctorId;
  bool isLoading = true;
  List<Map<String, dynamic>> clinics = []; // ✅ store clinics

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final name = await authService.getCurrentUserName();
    final id = await authService.getCurrentDoctorId();
    setState(() {
      userName = name ?? "Doctor";
      doctorId = id;
    });

    if (id != null) {
      await fetchClinics(id);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchClinics(String doctorId) async {
    try {
      final response = await Supabase.instance.client
          .from('clinic_locations')
          .select()
          .eq('doctor_id', doctorId);

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Error fetching clinics: $e");
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

  void goToAssistantRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DoctorDashboard()),
    );
  }

  void goToEditClinic() {
    if (doctorId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditClinicPage(doctorId: doctorId!),
      ),
    ).then((_) {
      // ✅ refresh clinics after editing
      if (doctorId != null) fetchClinics(doctorId!);
    });
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
            Text(
              "Welcome, Dr. ${userName ?? 'Doctor'} 🩺",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ Temporary container to show clinics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent),
              ),
              child: clinics.isEmpty
                  ? const Text(
                "No clinics linked yet.",
                style: TextStyle(color: Colors.grey),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Clinics:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  ...clinics.map((clinic) => ListTile(
                    leading: const Icon(Icons.local_hospital,
                        color: Colors.redAccent),
                    title: Text(clinic['clinic_name'] ??
                        "Unnamed Clinic"),
                    subtitle: Text(
                        clinic['address'] ?? "No address"),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount =
                  constraints.maxWidth > 600 ? 2 : 1;
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
                        onTap: () {},
                      ),
                      DashboardCard(
                        icon: Icons.assignment,
                        color: Colors.indigo,
                        title: "View Prescriptions",
                        onTap: () {},
                      ),
                      DashboardCard(
                        icon: Icons.group,
                        color: Colors.orange,
                        title: "View Assistant Requests",
                        onTap: goToAssistantRequests,
                      ),
                      DashboardCard(
                        icon: Icons.local_hospital,
                        color: Colors.redAccent,
                        title: "Edit Clinic Details",
                        onTap: goToEditClinic,
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
