import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewAppointmentsPage extends StatefulWidget {
  const ViewAppointmentsPage({Key? key}) : super(key: key);

  @override
  State<ViewAppointmentsPage> createState() => _ViewAppointmentsPageState();
}

class _ViewAppointmentsPageState extends State<ViewAppointmentsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  /// ✅ Fetch all appointments for the logged-in user
  Future<void> fetchAppointments() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("No user logged in");
        return;
      }

      final data = await supabase
          .from('appointments')
          .select('''
          appointment_id,
          appointment_date,
          appointment_time,
          reason,
          status,
          patients (
            name, age, gender, relation, user_id
          ),
          doctors (
            specialization,
            profiles ( name )
          )
        ''')
          .eq('patients.user_id', user.id)
          .order('appointment_date', ascending: false);

      debugPrint("Appointments fetched: $data");

      setState(() {
        appointments = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
      setState(() => isLoading = false);
    }
  }

  String formatDate(String date) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }

  String formatTime(String time) {
    try {
      return DateFormat('hh:mm a').format(DateFormat("HH:mm:ss").parse(time));
    } catch (_) {
      return time;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          "View Appointments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
          ? const Center(child: Text("No appointments found"))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appt = appointments[index];
          final patient = appt['patients'] ?? {};
          final doctor = appt['doctors'] ?? {};
          final doctorProfile = doctor['profiles'] ?? {};

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: Colors.blue.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ExpansionTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.medical_services,
                    color: Colors.blue.shade700),
              ),
              title: Text(
                doctorProfile['name'] != null ? "Dr. ${doctorProfile['name']}" : 'Unknown Doctor',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    formatDate(appt['appointment_date']),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 10),
                  Chip(
                    label: Text(appt['status']),
                    backgroundColor:
                    statusColor(appt['status']).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: statusColor(appt['status']),
                      fontWeight: FontWeight.bold,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                ],
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person,
                              size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            "Patient: ${patient['name']} (${patient['relation'] ?? ''})",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.medical_information,
                              size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            "Doctor: ${doctorProfile['name'] != null ? "Dr. ${doctorProfile['name']}" : 'Unknown'}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.work_outline,
                              size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            "Specialization: ${doctor['specialization'] ?? '-'}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.date_range,
                              size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            "Date: ${formatDate(appt['appointment_date'])}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            "Time: ${formatTime(appt['appointment_time'])}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Reason: ${appt['reason'] ?? 'No reason provided'}",
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
