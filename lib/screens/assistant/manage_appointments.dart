import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageAppointmentsPage extends StatefulWidget {
  const ManageAppointmentsPage({super.key});

  @override
  State<ManageAppointmentsPage> createState() => _ManageAppointmentsPageState();
}

class _ManageAppointmentsPageState extends State<ManageAppointmentsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    try {
      final response = await supabase
          .from('appointments')
          .select('''
            appointment_id,
            appointment_date,
            appointment_time,
            status,
            reason,
            patients(name),
            doctors(
              specialization,
              profiles(name)
            )
          ''')
          .order('appointment_date');

      setState(() {
        appointments = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> updateStatus(String id, String status) async {
    await supabase
        .from('appointments')
        .update({'status': status}).eq('appointment_id', id);
    fetchAppointments();
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
          "Manage Appointments",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
          ? const Center(child: Text("No appointments found"))
          : ListView.builder(
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appt = appointments[index];
          return Card(
            margin: const EdgeInsets.all(10),
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Patient: ${appt['patients']['name'] ?? 'Unknown'}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                      "Doctor: ${appt['doctors']['profiles']['name'] ?? 'Unknown'}"),
                  Text(
                      "Specialization: ${appt['doctors']['specialization']}"),
                  Text("Date: ${appt['appointment_date']}"),
                  Text("Slot: ${appt['appointment_time']}"),
                  Text("Reason: ${appt['reason'] ?? 'N/A'}"),
                  Text(
                    "Status: ${appt['status']}",
                    style: TextStyle(
                      color: appt['status'] == 'pending'
                          ? Colors.orange
                          : appt['status'] == 'accepted'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => updateStatus(
                            appt['appointment_id'], 'accepted'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text("Accept"),
                      ),
                      ElevatedButton(
                        onPressed: () => updateStatus(
                            appt['appointment_id'], 'rejected'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text("Reject"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
