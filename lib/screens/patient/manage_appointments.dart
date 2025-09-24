import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shimmer/shimmer.dart';

class ManageAppointmentsPage extends StatefulWidget {
  const ManageAppointmentsPage({Key? key}) : super(key: key);

  @override
  State<ManageAppointmentsPage> createState() => _ManageAppointmentsPageState();
}

class _ManageAppointmentsPageState extends State<ManageAppointmentsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> upcomingAppointments = [];
  List<dynamic> pastAppointments = [];
  bool isLoading = true;

  // --- THEME COLORS ---
  final Color primaryThemeColor = const Color(0xFF2193b0);
  final Color secondaryThemeColor = const Color(0xFF6dd5ed);

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  /// Fetches appointments and categorizes them into upcoming and past.
  Future<void> fetchAppointments() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    // Simulate a network delay for a better shimmer effect demonstration
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "No user logged in";

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
            patients ( name, relation ),
            doctors ( specialization, profiles ( name ) )
          ''')
          .eq('patients.user_id', user.id)
          .order('appointment_date', ascending: false)
          .order('appointment_time', ascending: false);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final upcoming = <dynamic>[];
      final past = <dynamic>[];

      for (final appt in data) {
        final apptDate = DateTime.parse(appt['appointment_date']);
        if (apptDate.isBefore(today) ||
            (apptDate.isAtSameMomentAs(today) && appt['status'] == 'completed')) {
          past.add(appt);
        } else {
          upcoming.add(appt);
        }
      }

      if (mounted) {
        setState(() {
          upcomingAppointments = upcoming;
          pastAppointments = past;
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

  /// Deletes an appointment and updates the corresponding slot.
  Future<void> deleteAppointment(String appointmentId, int? slotId) async {
    try {
      // 1. Delete the appointment
      await supabase
          .from('appointments')
          .delete()
          .eq('appointment_id', appointmentId);

      // 2. If a slot_id exists, decrement its booked_count
      if (slotId != null) {
        final slotData = await supabase
            .from('appointment_slots')
            .select('booked_count')
            .eq('slot_id', slotId)
            .maybeSingle();

        if (slotData != null) {
          int bookedCount = (slotData['booked_count'] ?? 0) - 1;
          await supabase.from('appointment_slots').update({
            'booked_count': bookedCount.clamp(0, 100), // Ensure count doesn't go below 0
          }).eq('slot_id', slotId);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment deleted successfully!")),
      );

      // Refresh the list to show the change
      await fetchAppointments();
    } catch (e) {
      debugPrint("Error deleting appointment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting appointment: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryThemeColor, secondaryThemeColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            "Manage Appointments",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          elevation: 4,
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAppointmentList(upcomingAppointments, isUpcoming: true),
            _buildAppointmentList(pastAppointments, isUpcoming: false),
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
      return _EmptyState(
        title: "No ${isUpcoming ? 'Upcoming' : 'Past'} Appointments",
        message: isUpcoming
            ? "You have no scheduled appointments to manage."
            : "You have no previous appointment history.",
      );
    }

    return RefreshIndicator(
      onRefresh: fetchAppointments,
      color: primaryThemeColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return _AppointmentCard(
            appointment: appointment,
            themeColor: primaryThemeColor,
            onDelete: () => deleteAppointment(
              appointment['appointment_id'],
              appointment['slot_id'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => const _ShimmerAppointmentCard(),
    );
  }
}

// --- UI WIDGETS ---

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Color themeColor;
  final VoidCallback onDelete;

  const _AppointmentCard({
    required this.appointment,
    required this.themeColor,
    required this.onDelete,
  });

  String formatDate(String date) => DateFormat('E, dd MMM yyyy').format(DateTime.parse(date));
  String formatTime(String time) => DateFormat('hh:mm a').format(DateFormat("HH:mm:ss").parse(time));

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending": return Colors.orange.shade700;
      case "approved": return Colors.green.shade700;
      case "rejected":
      case "cancelled": return Colors.red.shade700;
      default: return Colors.grey.shade700;
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

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this appointment? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
            ),
          ],
        );
      },
    );
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
                  child: Icon(Icons.medical_services_outlined, color: themeColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorProfile['name'] != null ? "Dr. ${doctorProfile['name']}" : 'Unknown Doctor',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor['specialization'] ?? 'No specialization',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: statusColor(status).withOpacity(0.1),
                  labelStyle: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
          // --- Details Section ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_outline, "Patient", patient['name'] ?? 'N/A'),
                _buildInfoRow(Icons.calendar_today_outlined, "Date", formatDate(appointment['appointment_date'])),
                _buildInfoRow(Icons.access_time_outlined, "Time", formatTime(appointment['appointment_time'])),
                _buildInfoRow(Icons.notes_outlined, "Reason", appointment['reason'] ?? 'No reason provided'),
                _buildInfoRow(Icons.attach_file, "Report", reportUrl, isReport: true, context: context),
              ],
            ),
          ),
          // --- Footer with Action Buttons ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showDeleteDialog(context),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  label: const Text("Delete", style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {bool isReport = false, BuildContext? context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            child: Text("$label:", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: isReport
                ? (value != null
                ? Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openFile(context!, value),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  backgroundColor: themeColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  "View Attachment",
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
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
            ))
                : Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerAppointmentCard extends StatelessWidget {
  const _ShimmerAppointmentCard();

  Widget _buildShimmerBox({required double height, required double width, double radius = 8}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.1),
        margin: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  _buildShimmerBox(height: 52, width: 52, radius: 26),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(height: 20, width: 150),
                        const SizedBox(height: 8),
                        _buildShimmerBox(height: 14, width: 100),
                      ],
                    ),
                  ),
                  _buildShimmerBox(height: 30, width: 80),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildShimmerBox(height: 16, width: double.infinity),
                  const SizedBox(height: 12),
                  _buildShimmerBox(height: 16, width: double.infinity),
                  const SizedBox(height: 12),
                  _buildShimmerBox(height: 16, width: double.infinity),
                  const SizedBox(height: 12),
                  _buildShimmerBox(height: 16, width: double.infinity),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}