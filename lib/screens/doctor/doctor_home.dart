import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:medi_slot/screens/doctor/appointments_screen.dart';
import 'package:medi_slot/screens/doctor/patients_screen.dart';
import 'package:medi_slot/screens/doctor/prescriptions_screen.dart';
import 'package:medi_slot/screens/doctor/profile_screen.dart';
import 'package:medi_slot/screens/doctor/write_prescription_screen.dart';
import 'package:medi_slot/screens/login_screen.dart';
import '../../auth/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// Doctor Dashboard
// -----------------------------------------------------------------------------
class DoctorDashboard extends StatefulWidget {
  final String doctorId;
  const DoctorDashboard({Key? key, required this.doctorId}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final AuthService authService = AuthService();
  final SupabaseClient supabase = Supabase.instance.client;

  String? userName;
  String? doctorId;
  bool isLoading = true;

  int _page = 0;
  int todayAppointments = 0;
  int totalPatients = 0;
  int pendingSlots = 0;
  int pendingApprovalsCount = 0;
  List<Map<String, dynamic>> upcomingAppointments = [];
  Map<String, dynamic>? _selectedPatient;

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _checkSessionValidity();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await fetchUserData();
    await _loadDashboardData();
    _buildPages();
  }

  void _buildPages() {
    _pages = [
      DoctorHomePage(
        userName: userName ?? "Doctor",
        todayAppointments: todayAppointments,
        totalPatients: totalPatients,
        pendingSlots: pendingSlots,
        upcomingAppointments: upcomingAppointments,
        pendingApprovalsCount: pendingApprovalsCount,
      ),
      const AppointmentsScreen(),
      PatientsScreen(onWritePrescription: _openPrescriptionScreen),
      const PrescriptionsScreen(),
      if (_selectedPatient != null && doctorId != null)
        WritePrescriptionScreen(
          doctorId: doctorId!,
          patient: _selectedPatient!,
        )
      else
        const SizedBox(),
      const ProfileScreen(),
    ];
    setState(() => isLoading = false);
  }

  void _openPrescriptionScreen(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatient = patient;
      _page = 4; // Switch to WritePrescriptionScreen
      _buildPages(); // rebuild pages with updated patient data
    });
  }

  Future<void> _checkSessionValidity() async {
    final isValid = await authService.isUserLoggedIn();
    if (!isValid && mounted) {
      await authService.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<void> fetchUserData() async {
    final name = await authService.getCurrentUserName();
    final id = await authService.getCurrentDoctorId();

    setState(() {
      userName = name ?? "Doctor";
      doctorId = id ?? widget.doctorId;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      final currentDoctorId = doctorId ?? widget.doctorId;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final todayRes = await supabase
          .from('appointment_slots')
          .select('booked_count')
          .eq('doctor_id', currentDoctorId)
          .eq('slot_date', today);

      int todayCount = 0;
      for (var slot in todayRes) {
        todayCount += (slot['booked_count'] ?? 0) as int;
      }

      final appointmentsRes = await supabase
          .from('appointments')
          .select('appointment_id, status')
          .eq('doctor_id', currentDoctorId)
          .not('status', 'in', ['cancelled', 'rejected']);

      final totalPatientsCount =
      (appointmentsRes is List) ? appointmentsRes.length : 0;

      final pendingSlotsRes = await supabase
          .from('appointment_slots')
          .select('slot_id')
          .eq('doctor_id', currentDoctorId)
          .eq('slot_date', today)
          .eq('status', 'open');

      final pendingSlotsCount =
      (pendingSlotsRes is List) ? pendingSlotsRes.length : 0;

      final pendingRes = await supabase
          .from('appointments')
          .select('appointment_id')
          .eq('doctor_id', currentDoctorId)
          .eq('status', 'pending');

      pendingApprovalsCount = (pendingRes is List) ? pendingRes.length : 0;

      setState(() {
        todayAppointments = todayCount;
        totalPatients = totalPatientsCount;
        pendingSlots = pendingSlotsCount;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading dashboard data: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: _page, children: _pages),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        buttonBackgroundColor: Colors.blue.shade700,
        color: Colors.white,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        height: 65.0,
        index: _page,
        items: const [
          Icon(Icons.home, size: 28),
          Icon(Icons.calendar_today_outlined, size: 28),
          Icon(Icons.group_outlined, size: 28),
          Icon(Icons.medication_liquid_outlined, size: 28),
          Icon(Icons.edit_note_rounded, size: 28),
          Icon(Icons.person_outline, size: 28),
        ],
        onTap: (index) => setState(() => _page = index),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Doctor Home Page
// -----------------------------------------------------------------------------
class DoctorHomePage extends StatelessWidget {
  final String userName;
  final int todayAppointments;
  final int totalPatients;
  final int pendingSlots;
  final List<Map<String, dynamic>> upcomingAppointments;
  final int pendingApprovalsCount;

  const DoctorHomePage({
    super.key,
    required this.userName,
    required this.todayAppointments,
    required this.totalPatients,
    required this.pendingSlots,
    required this.upcomingAppointments,
    required this.pendingApprovalsCount,
  });

  @override
  Widget build(BuildContext context) {
    final String currentDate =
    DateFormat('EEEE, MMMM d').format(DateTime.now());

    const int completedConsultations = 7;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(userName, currentDate),
          const SizedBox(height: 20),
          _buildStatCards(todayAppointments, totalPatients, pendingSlots, completedConsultations),
          const SizedBox(height: 25),
          _buildReadyToStartCard(),
          const SizedBox(height: 25),
          _buildUpcomingAppointmentsSection(context, upcomingAppointments),
          const SizedBox(height: 15),
          _buildPendingApprovals(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome Back, Dr. $name",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          date,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(int appointments, int patients, int pending, int completed) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          value: appointments,
          label: "Today's Appointments",
          icon: Icons.calendar_today_outlined,
          color: Colors.blue.shade700,
        ),
        _StatCard(
          value: patients,
          label: 'Total Patients',
          icon: Icons.group_outlined,
          color: Colors.green.shade700,
        ),
        _StatCard(
          value: pending,
          label: 'Pending Slots',
          icon: Icons.access_time,
          color: Colors.orange.shade700,
        ),
        _StatCard(
          value: completed,
          label: 'Completed (Pending to update SH)',
          icon: Icons.check_circle_outline,
          color: Colors.purple.shade700,
        ),
      ],
    );
  }

  Widget _buildReadyToStartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [Colors.lightBlue.shade300, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ready to start?",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 4),
              Text("Begin your next consultation",
                  style: TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("Start",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentsSection(
      BuildContext context, List<Map<String, dynamic>> appointments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Upcoming Appointments",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            TextButton(
              onPressed: () {},
              child: Text("View All",
                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...appointments.map((appointment) => _AppointmentTile(
          name: appointment['name'],
          time: appointment['time'],
          status: appointment['status'],
        )),
      ],
    );
  }

  Widget _buildPendingApprovals() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          Text(
            "$pendingApprovalsCount Pending Approvals",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widgets
// -----------------------------------------------------------------------------
class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(value.toString(),
              style:
              const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const Spacer(),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final String name;
  final String time;
  final String status;

  const _AppointmentTile({required this.name, required this.time, required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBgColor;

    if (status == 'Confirmed') {
      statusColor = Colors.green.shade800;
      statusBgColor = Colors.green.shade50;
    } else if (status == 'Pending') {
      statusColor = Colors.orange.shade800;
      statusBgColor = Colors.orange.shade50;
    } else {
      statusColor = Colors.red.shade800;
      statusBgColor = Colors.red.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
            BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.group_outlined, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(time,
                          overflow: TextOverflow.ellipsis,
                          style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}