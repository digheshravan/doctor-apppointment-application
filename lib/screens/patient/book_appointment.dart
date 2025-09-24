import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/patient/patient.dart';
import 'package:medi_slot/screens/patient/doctor_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class BookAppointmentPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedDoctor; // optional preselected doctor

  const BookAppointmentPage({Key? key, this.preselectedDoctor}) : super(key: key);

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final supabase = Supabase.instance.client;

  String? selectedPatientId;
  Map<String, dynamic>? selectedDoctor; // For booking
  Map<String, dynamic>? selectedDoctorInfo; // For displaying card info
  DateTime? selectedDate;
  String? selectedTimeSlot;

  List<dynamic> patients = [];
  List<dynamic> appointments = [];
  List<dynamic> availableSlots = []; // Slots for selected doctor/date

  final TextEditingController reasonController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // If a doctor is passed from dashboard, set it as selected
    if (widget.preselectedDoctor != null) {
      selectedDoctor = widget.preselectedDoctor;
      selectedDoctorInfo = widget.preselectedDoctor;
    }

    fetchPatients();
  }

  // Fetch patients
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

  // Fetch appointments
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

  // Fetch available slots for selected doctor and date
  Future<void> fetchAvailableSlots() async {
    if (selectedDoctor == null || selectedDate == null) {
      setState(() => availableSlots = []);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final now = DateTime.now();

    try {
      final response = await supabase
          .from('appointment_slots')
          .select('slot_time, slot_limit, booked_count, status')
          .eq('doctor_id', selectedDoctor!['doctor_id'])
          .eq('slot_date', dateStr)
          .eq('status', 'open');

      final slots = (response as List)
          .where((slot) => slot['booked_count'] < slot['slot_limit'])
          .map((slot) {
        // Convert slot_time to DateTime for comparison
        final slotTimeStr = slot['slot_time'] as String; // HH:mm:ss
        final slotDateTime = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          int.parse(slotTimeStr.split(':')[0]),
          int.parse(slotTimeStr.split(':')[1]),
          int.parse(slotTimeStr.split(':')[2]),
        );
        slot['slotDateTime'] = slotDateTime;
        return slot;
      })
      // Only future slots
          .where((slot) {
        final slotDateTime = slot['slotDateTime'] as DateTime;
        return slotDateTime.isAfter(now);
      })
          .toList();

      // Sort ascending by slotDateTime
      slots.sort((a, b) =>
          (a['slotDateTime'] as DateTime).compareTo(b['slotDateTime'] as DateTime));

      setState(() {
        availableSlots = slots;
        selectedTimeSlot = null; // reset selection
      });
    } catch (e) {
      debugPrint("Error fetching slots: $e");
      setState(() => availableSlots = []);
    }
  }

  // Check slot availability (optional, extra safety)
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

  // Book appointment
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

    final appointmentDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

    try {
      // 1️⃣ Fetch the slot row to get slot_id
      final slotResponse = await supabase
          .from('appointment_slots')
          .select('slot_id, slot_limit, booked_count')
          .eq('doctor_id', selectedDoctor!['doctor_id'])
          .eq('slot_date', appointmentDate)
          .eq('slot_time', selectedTimeSlot!)
          .maybeSingle();

      if (slotResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selected slot not found!")),
        );
        return;
      }

      final slotId = slotResponse['slot_id'];

      // 2️⃣ Insert appointment with slot_id
      await supabase.from('appointments').insert({
        'patient_id': selectedPatientId,
        'doctor_id': selectedDoctor!['doctor_id'],
        'slot_id': slotId, // ✅ Insert slot_id here
        'appointment_date': appointmentDate,
        'appointment_time': selectedTimeSlot,
        'reason': reasonController.text,
        'status': 'pending',
      });

      // 3️⃣ Optionally, update booked_count in appointment_slots
      await supabase.from('appointment_slots').update({
        'booked_count': slotResponse['booked_count'] + 1,
      }).eq('slot_id', slotId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment booked successfully!")),
      );

      reasonController.clear();
      fetchAppointments();

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

  // Select doctor
  Future<void> selectDoctorOnMap() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DoctorMapPage()),
    );

    if (selected != null) {
      final doctorId = selected['doctorId'] ?? selected['doctor_id'];
      final doctorName = selected['doctorName'] ?? selected['doctor_name'] ?? "Unknown";
      final specialization = selected['specialization'] ?? "General";
      final clinicName = selected['clinicName'] ?? selected['clinic_name'] ?? "N/A";
      final address = selected['address'] ?? "N/A";

      setState(() {
        selectedDoctorInfo = {
          'doctorName': doctorName,
          'specialization': specialization,
          'clinicName': clinicName,
          'address': address,
        };
        selectedDoctor = {
          'doctor_id': doctorId,
          'name': doctorName,
          'specialization': specialization,
          'clinicName': clinicName,
          'address': address,
        };
      });

      // Fetch slots for selected doctor
      await fetchAvailableSlots();
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
                onTap: selectDoctorOnMap,
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
                            : "Selected: Dr. ${selectedDoctor?['name'] ?? 'Unknown'}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.search, color: Colors.blue),
                    ],
                  ),
                ),
              ),

              // Doctor info card
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
                          "Dr. ${selectedDoctorInfo!['doctorName']} (${selectedDoctorInfo!['specialization']})",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Clinic: ${selectedDoctorInfo!['clinicName'] ?? 'N/A'}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Address: ${selectedDoctorInfo!['address'] ?? 'N/A'}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Date selection
              const Text(
                "Select Date",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: selectedDate ?? DateTime.now(),
                calendarFormat: CalendarFormat.month,
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) async {
                  setState(() {
                    selectedDate = selectedDay;
                  });
                  await fetchAvailableSlots();
                },
                enabledDayPredicate: (day) {
                  final now = DateTime.now();
                  final fiveDaysLater = now.add(const Duration(days: 5));
                  return day.isAfter(now.subtract(const Duration(days: 1))) &&
                      day.isBefore(fiveDaysLater.add(const Duration(days: 1)));
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  disabledTextStyle: TextStyle(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 20),

              // Time slot dropdown
              DropdownButtonFormField<String>(
                value: selectedTimeSlot,
                items: availableSlots.map<DropdownMenuItem<String>>((slot) {
                  final formatted = DateFormat('hh:mm a')
                      .format((slot['slotDateTime'] as DateTime));
                  return DropdownMenuItem<String>(
                    value: slot['slot_time'],
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

              // Patient selection
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

              // Book button
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
