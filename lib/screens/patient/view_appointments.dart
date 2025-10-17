import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shimmer/shimmer.dart';

class ViewAppointmentsPage extends StatefulWidget {
  const ViewAppointmentsPage({Key? key}) : super(key: key);

  @override
  State<ViewAppointmentsPage> createState() => _ViewAppointmentsPageState();
}

class _ViewAppointmentsPageState extends State<ViewAppointmentsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> upcomingAppointments = [];
  List<dynamic> pastAppointments = [];
  List<dynamic> cancelledAppointments = [];
  bool isLoading = true;

  // --- THEME COLORS ---
  final Color primaryThemeColor = const Color(0xFF2193b0);
  final Color secondaryThemeColor = const Color(0xFF6dd5ed);

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "No user logged in";

      // 1. Get all patient_ids for this user
      final patientData = await supabase
          .from('patients')
          .select('patient_id')
          .eq('user_id', user.id);

      if (patientData.isEmpty) {
        throw "No patients found";
      }

      final patientIds = patientData.map((p) => p['patient_id']).toList();

      // 2. Fetch all appointments for this user's patients
      final patientIdsStr = patientIds.join(',');
      final data = await supabase
          .from('appointments')
          .select('''
      appointment_id,
      appointment_date,
      appointment_time,
      reason,
      status,
      report_url,
      slot_id,
      patients(name, age, gender, relation),
      doctors(specialization, profiles(name))
    ''')
          .filter('patient_id', 'in', '($patientIdsStr)')
          .order('appointment_date', ascending: false)
          .order('appointment_time', ascending: false);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final upcoming = <dynamic>[];
      final past = <dynamic>[];
      final cancelled = <dynamic>[];

      for (final appt in data) {
        final apptDate = DateTime.parse(appt['appointment_date']);
        final status = (appt['status'] ?? '').toLowerCase();

        if (status == 'cancelled') {
          cancelled.add(appt);
        } else if (apptDate.isBefore(today) || status == 'completed') {
          past.add(appt);
        } else {
          upcoming.add(appt);
        }
      }

      if (mounted) {
        setState(() {
          upcomingAppointments = upcoming;
          pastAppointments = past;
          cancelledAppointments = cancelled;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching appointments: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent, // remove default color
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryThemeColor, secondaryThemeColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              "My Appointments",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 16),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Past"),
              Tab(text: "Cancelled"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAppointmentList(upcomingAppointments, isUpcoming: true),
            _buildAppointmentList(pastAppointments, isUpcoming: false),
            _buildAppointmentList(cancelledAppointments, isUpcoming: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentList(List<dynamic> appointments, {required bool isUpcoming}) {
    if (isLoading) {
      return _buildShimmerList();
    }

    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isUpcoming
                  ? "No Upcoming Appointments"
                  : "No ${isUpcoming == false ? 'Past/Cancelled' : ''} Appointments",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isUpcoming
                  ? "You have no scheduled appointments at this time."
                  : "You have no previous appointment history.",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: fetchAppointments, // reuse the same fetch method
      color: primaryThemeColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appt = appointments[index];
          return _AppointmentCard(
            appointment: appt,
            onAppointmentCancelled: fetchAppointments, // refresh after cancel
            themeColor: primaryThemeColor,
          );
        },
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // --- Header Section ---
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 14, width: 120, color: Colors.white, margin: const EdgeInsets.only(bottom: 6)),
                            Container(height: 12, width: 100, color: Colors.white),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Info Rows ---
                  Column(
                    children: List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 16),
                            Container(width: 70, height: 12, color: Colors.white),
                            const SizedBox(width: 16),
                            Expanded(child: Container(height: 12, color: Colors.white)),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // --- Report / Button Row ---
                  Row(
                    children: [
                      Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 16),
                      Container(width: 70, height: 12, color: Colors.white),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- UI WIDGETS ---

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Color themeColor;

  // 👇 add this callback
  final VoidCallback? onAppointmentCancelled;

  const _AppointmentCard({
    required this.appointment,
    required this.themeColor,
    this.onAppointmentCancelled, // 👈 now available
  });

  String formatDate(String date) =>
      DateFormat('E, dd MMM yyyy').format(DateTime.parse(date));

  String formatTime(String time) =>
      DateFormat('hh:mm a').format(DateFormat("HH:mm:ss").parse(time));

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange.shade700;
      case "approved":
        return Colors.green.shade700;
      case "rejected":
      case "cancelled":
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _openFile(BuildContext context, String fileUrl) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Downloading report...")),
    );
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = fileUrl.split('/').last.split('?').first;
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          throw Exception('Could not open file: ${result.message}');
        }
      } else {
        throw Exception("Failed to download file: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error opening file: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening report: $e")),
        );
      }
    }
  }

  Future<void> _cancelAppointment(
      BuildContext context, Map<String, dynamic> appointment) async {
    final supabase = Supabase.instance.client;
    try {
      final apptId = appointment['appointment_id'];
      final slotId = appointment['slot_id'];

      // 1. Update appointment status
      await supabase
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('appointment_id', apptId);

      // 2. Update the slot if it exists
      if (slotId != null) {
        final slot = await supabase
            .from('appointment_slots')
            .select('slot_limit, booked_count')
            .eq('slot_id', slotId)
            .maybeSingle();

        if (slot != null) {
          int bookedCount = slot['booked_count'] ?? 0;
          int slotLimit = slot['slot_limit'] ?? 1;

          bookedCount = (bookedCount - 1).clamp(0, slotLimit); // ensure >= 0

          String slotStatus = bookedCount < slotLimit ? 'open' : 'full';

          await supabase
              .from('appointment_slots')
              .update({
            'booked_count': bookedCount,
            'status': slotStatus,
          })
              .eq('slot_id', slotId);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment cancelled successfully")),
        );
      }

      // 3. Refresh parent list
      if (onAppointmentCancelled != null) {
        onAppointmentCancelled!();
      }
    } catch (e) {
      debugPrint("Error cancelling appointment: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling appointment: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = appointment['patients'] ?? {};
    final doctor = appointment['doctors'] ?? {};
    final doctorProfile = doctor['profiles'] ?? {};
    final status = appointment['status'] ?? 'unknown';
    final reportUrl = appointment['report_url'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header Section ---
          Container(
            padding: const EdgeInsets.all(16),
            color: themeColor.withOpacity(0.05),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: themeColor.withOpacity(0.15),
                  child: Icon(Icons.medical_services_outlined,
                      color: themeColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorProfile['name'] != null
                            ? "Dr. ${doctorProfile['name']}"
                            : 'Unknown Doctor',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor['specialization'] ?? 'No specialization',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: statusColor(status).withOpacity(0.1),
                  labelStyle: TextStyle(
                      color: statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
          ),

          // --- Details Section ---
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_outline, "Patient",
                    patient['name'] ?? 'N/A'),
                _buildInfoRow(Icons.calendar_today_outlined, "Date",
                    formatDate(appointment['appointment_date'])),
                _buildInfoRow(Icons.access_time_outlined, "Time",
                    formatTime(appointment['appointment_time'])),
                _buildInfoRow(Icons.notes_outlined, "Reason",
                    appointment['reason'] ?? 'No reason provided'),
                const Divider(height: 24),
                _buildReportRow(context, reportUrl),

                // --- Cancel Button ---
                if (status.toLowerCase() != 'cancelled')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _cancelAppointment(context, appointment),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text("Cancel Appointment"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            child: Text("$label:",
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(BuildContext context, String? reportUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.attach_file, color: Colors.grey.shade500, size: 20),
        const SizedBox(width: 16),
        SizedBox(
          width: 70,
          child: Text("Report:",
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: reportUrl != null
              ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openFile(context, reportUrl),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                backgroundColor: themeColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                "View Attachment",
                style: TextStyle(
                    color: themeColor, fontWeight: FontWeight.bold),
              ),
            ),
          )
              : const Text(
            "No attachment",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}