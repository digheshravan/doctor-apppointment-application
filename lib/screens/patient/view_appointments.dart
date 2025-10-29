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

  // --- THEME COLORS from ProfilesScreen ---
  static const Color primaryColor = Color(0xFF00AEEF);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  static const Color dangerColor = Color(0xFFF44336); // For cancel button
  // --- End Theme Colors ---

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
        // No patients, so no appointments
        if (mounted) {
          setState(() {
            upcomingAppointments = [];
            pastAppointments = [];
            cancelledAppointments = [];
            isLoading = false;
          });
        }
        return;
      }

      final patientIds = patientData.map((p) => p['patient_id']).toList();

      // --- FIX: Re-added patientIdsStr for the .filter() method ---
      final patientIdsStr = patientIds.join(',');

      // 2. Fetch all appointments for this user's patients
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
      // --- FIX: Replaced .in_() with the .filter() method ---
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

        if (status == 'cancelled' || status == 'rejected') {
          cancelled.add(appt);
        } else if (apptDate.isBefore(today) || status == 'completed') {
          past.add(appt);
        } else {
          // Includes 'pending' and 'accepted' for today or future
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
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          toolbarHeight: 80,
          title: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined, // Appropriate icon
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Appointments',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      'Upcoming, Past & Cancelled',
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: primaryColor,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 16),
            labelColor: textColor,
            unselectedLabelColor: lightTextColor,
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Past"),
              Tab(text: "Cancelled"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAppointmentList(upcomingAppointments, tabName: "Upcoming"),
            _buildAppointmentList(pastAppointments, tabName: "Past"),
            _buildAppointmentList(cancelledAppointments, tabName: "Cancelled"),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentList(List<dynamic> appointments,
      {required String tabName}) {
    if (isLoading) {
      return _buildShimmerList();
    }

    if (appointments.isEmpty) {
      return _buildEmptyState(tabName);
    }
    return RefreshIndicator(
      onRefresh: fetchAppointments,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appt = appointments[index];
          return _AppointmentCard(
            appointment: appt,
            onAppointmentCancelled: fetchAppointments,
            primaryColor: primaryColor,
            textColor: textColor,
            lightTextColor: lightTextColor,
            dangerColor: dangerColor,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String tabName) {
    String title = "No $tabName Appointments";
    String subtitle = "You have no $tabName appointments at this time.";
    if (tabName == "Past") {
      subtitle = "You have no previous appointment history.";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return const _ShimmerAppointmentCard();
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Appointment Card
// -----------------------------------------------------------------------------
class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Color primaryColor;
  final Color textColor;
  final Color lightTextColor;
  final Color dangerColor;
  final VoidCallback? onAppointmentCancelled;

  const _AppointmentCard({
    required this.appointment,
    required this.primaryColor,
    required this.textColor,
    required this.lightTextColor,
    required this.dangerColor,
    this.onAppointmentCancelled,
  });

  String formatDate(String date) =>
      DateFormat('E, dd MMM yyyy').format(DateTime.parse(date));

  String formatTime(String time) =>
      DateFormat('hh:mm a').format(DateFormat("HH:mm:ss").parse(time));

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange.shade700;
      case "accepted": // Changed from 'approved' to 'accepted'
        return Colors.green.shade700;
      case "rejected":
      case "cancelled":
        return dangerColor;
      default:
        return lightTextColor;
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
    final status = (appointment['status'] ?? 'unknown').toLowerCase();
    final reportUrl = appointment['report_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header Section ---
          Container(
            padding: const EdgeInsets.all(16),
            color: primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Icon(Icons.medical_services_outlined,
                      color: primaryColor, size: 28),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor['specialization'] ?? 'No specialization',
                        style: TextStyle(color: lightTextColor, fontSize: 14),
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
                if (status == 'pending' || status == 'accepted')
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
                          backgroundColor: dangerColor,
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
          Icon(icon, color: lightTextColor, size: 20),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            child: Text("$label:",
                style: TextStyle(
                    color: lightTextColor, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
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
        Icon(Icons.attach_file, color: lightTextColor, size: 20),
        const SizedBox(width: 16),
        SizedBox(
          width: 70,
          child: Text("Report:",
              style: TextStyle(
                  color: lightTextColor, fontWeight: FontWeight.w500)),
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
                backgroundColor: primaryColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                "View Attachment",
                style: TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          )
              : Text(
            "No attachment",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: lightTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Shimmer Card
// -----------------------------------------------------------------------------
class _ShimmerAppointmentCard extends StatelessWidget {
  const _ShimmerAppointmentCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white.withOpacity(0.5),
              child: Row(
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
                        Container(
                            height: 18,
                            width: 150,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 6)),
                        Container(height: 14, width: 100, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(4, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 16),
                        Container(width: 70, height: 14, color: Colors.white),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Container(height: 14, color: Colors.white)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}