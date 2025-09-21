import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/patient/patient.dart';
import 'package:medi_slot/screens/patient/doctor_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookAppointmentPage extends StatefulWidget {
  const BookAppointmentPage({Key? key}) : super(key: key);

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  Map<String, dynamic>? _selectedDoctor; // Store selected doctor data
  final supabase = Supabase.instance.client;

  String? selectedPatientId;
  Map<String, dynamic>? selectedDoctor; // For booking
  Map<String, dynamic>? selectedDoctorInfo; // For displaying card info
  DateTime? selectedDate;
  String? selectedTimeSlot;

  List<dynamic> patients = [];
  List<dynamic> appointments = [];

  final TextEditingController reasonController = TextEditingController();
  bool isLoading = true;

  final List<String> timeSlots = [
    "09:00:00",
    "10:00:00",
    "11:00:00",
    "12:00:00",
    "14:00:00",
    "15:00:00",
    "16:00:00",
  ];

  @override
  void initState() {
    super.initState();
    fetchPatients();
  }

  Future<void> fetchPatients() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('patients')
          .select('patient_id, name, age, gender')
          .eq('user_id', user.id);

      setState(() {
        patients = data;
        if (patients.isNotEmpty) {
          selectedPatientId = patients.first['patient_id'];
          fetchAppointments();
        }
      });
    } catch (e) {
      debugPrint("Error fetching patients: $e");
    }
  }

  Future<void> fetchAppointments() async {
    if (selectedPatientId == null) return;
    try {
      final data = await supabase
          .from('appointments')
          .select(
          'appointment_id, appointment_date, appointment_time, reason, status, doctors(specialization, profiles(name))')
          .eq('patient_id', selectedPatientId!)
          .order('appointment_date', ascending: false);

      setState(() {
        appointments = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
    }
  }

  Future<bool> canBookSlot(String doctorId, DateTime date, String slot) async {
    final appointmentDate = DateFormat('yyyy-MM-dd').format(date);

    final response = await supabase
        .from('appointments')
        .select('appointment_id')
        .eq('doctor_id', doctorId)
        .eq('appointment_date', appointmentDate)
        .eq('appointment_time', slot);

    return response.length < 6; // Max 6 patients per slot
  }

  Future<void> bookAppointment() async {
    if (selectedPatientId == null ||
        selectedDoctor == null ||
        selectedDate == null ||
        selectedTimeSlot == null ||
        reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final slotAvailable = await canBookSlot(
        selectedDoctor!['doctor_id'], selectedDate!, selectedTimeSlot!);

    if (!slotAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text("Selected time slot is full. Please choose another slot.")),
      );
      return;
    }

    try {
      final appointmentDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

      await supabase.from('appointments').insert({
        'patient_id': selectedPatientId,
        'doctor_id': selectedDoctor!['doctor_id'],
        'appointment_date': appointmentDate,
        'appointment_time': selectedTimeSlot,
        'reason': reasonController.text,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment booked successfully!")),
      );

      reasonController.clear();
      fetchAppointments();

      // Navigate back to patient dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientDashboard(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error booking appointment: $e")),
      );
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> selectDoctorOnMap() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DoctorMapPage()),
    );

    if (selected != null) {
      setState(() {
        selectedDoctorInfo = selected;
        selectedDoctor = {
          'doctor_id': selected['doctorId'],
          'name': selected['doctorName'],
          'specialization': selected['specialization'],
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPatient = patients.firstWhere(
          (p) => p['patient_id'] == selectedPatientId,
      orElse: () => <String, dynamic>{},
    );

    final patientName = selectedPatient['name'] ?? 'Unknown';
    final patientAge = selectedPatient['age']?.toString() ?? 'N/A';
    final patientGender = selectedPatient['gender'] ?? 'N/A';

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
          "Book Appointment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor selection
              GestureDetector(
                onTap: () async {
                  final selected = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorMapPage()),
                  );

                  if (selected != null) {
                    setState(() {
                      selectedDoctorInfo = selected;
                      selectedDoctor = {
                        'doctor_id': selected['doctorId'],
                        'name': selected['doctorName'],
                        'specialization': selected['specialization'],
                      };
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDoctor == null
                            ? "Select Doctor – Tap to view map"
                            : "Selected: ${selectedDoctor?['name'] ?? 'Unknown'}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.search, color: Colors.blue),
                    ],
                  ),
                ),
              ),
              // Display selected doctor info
              if (selectedDoctorInfo != null) ...[
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${selectedDoctorInfo!['doctorName']} (${selectedDoctorInfo!['specialization']})",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Clinic: ${selectedDoctorInfo!['clinicName']}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Address: ${selectedDoctorInfo!['address']}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: pickDate,
                      child: Text(selectedDate == null
                          ? "Pick Date"
                          : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedTimeSlot,
                items: timeSlots.map((slot) {
                  final formatted = DateFormat('hh:mm a')
                      .format(DateFormat("HH:mm:ss").parse(slot));
                  return DropdownMenuItem<String>(
                    value: slot,
                    child: Text(formatted),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTimeSlot = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Select Time Slot",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Patient Details
              const Text(
                "Patient Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPatientId,
                items: patients.map<DropdownMenuItem<String>>((patient) {
                  return DropdownMenuItem<String>(
                    value: patient['patient_id'],
                    child: Text(patient['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPatientId = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Select Patient",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text("Name: $patientName"),
              Text("Age: $patientAge"),
              Text("Gender: $patientGender"),
              const SizedBox(height: 20),

              // Reason
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Reason for Appointment",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              // Book Appointment button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(2, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: bookAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Book Appointment",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
