import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/patient/patient.dart';
import 'package:medi_slot/screens/patient/doctor_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BookAppointmentPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedDoctor;

  const BookAppointmentPage({Key? key, this.preselectedDoctor}) : super(key: key);

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final supabase = Supabase.instance.client;

  String? selectedPatientId;
  Map<String, dynamic>? selectedDoctor;
  Map<String, dynamic>? selectedDoctorInfo;
  DateTime? selectedDate;
  String? selectedTimeSlot;
  String? selectedTimeRange;

  // --- THEME COLORS ---
  final Color primaryThemeColor = const Color(0xFF2193b0);
  final Color secondaryThemeColor = const Color(0xFF6dd5ed);

  // Helper widget for creating a styled detail row in a card
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryThemeColor, size: 22),
        const SizedBox(width: 16),
        Text(
          "$label:",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  // Helper widget for section headers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: primaryThemeColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }



  List<dynamic> patients = [];
  List<dynamic> appointments = [];
  List<dynamic> availableSlots = [];

  final TextEditingController reasonController = TextEditingController();
  bool isLoading = true;

  // file picker
  File? selectedFile;
  String? uploadedFileUrl;
  String? uploadedFilePath;


  @override
  void initState() {
    super.initState();

    if (widget.preselectedDoctor != null) {
      selectedDoctor = widget.preselectedDoctor;
      selectedDoctorInfo = widget.preselectedDoctor;
    }
    fetchPatients();
  }

  // Select Doctor on Map
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

      await fetchAvailableSlots();
    }
  }

  // Fetch Appointments
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

  // Fetch Available Slots
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
        final slotTimeStr = slot['slot_time'] as String;
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
          .where((slot) {
        final slotDateTime = slot['slotDateTime'] as DateTime;
        return slotDateTime.isAfter(now);
      })
          .toList();

      slots.sort((a, b) =>
          (a['slotDateTime'] as DateTime).compareTo(b['slotDateTime'] as DateTime));

      setState(() {
        availableSlots = slots;
        selectedTimeSlot = null;
      });
    } catch (e) {
      debugPrint("Error fetching slots: $e");
      setState(() => availableSlots = []);
    }
  }

  // Fetch Patients
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

  // File picker (handles both upload and update)
  Future<void> pickFile() async {
    // If a file is already uploaded, remove it first before picking a new one.
    if (uploadedFilePath != null) {
      await deleteFile(uploadedFilePath!);
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final uploadResult = await uploadFile(file);

      if (uploadResult != null) {
        setState(() {
          selectedFile = file;
          uploadedFileUrl = uploadResult['url'];
          uploadedFilePath = uploadResult['path']; // Store the path
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error uploading file. Please try again.")),
          );
        }
      }
    } else {
      // If user cancels picking a new file, clear the old file state.
      setState(() {
        selectedFile = null;
        uploadedFileUrl = null;
        uploadedFilePath = null;
      });
    }
  }

  // Upload file to Supabase
  Future<Map<String, String>?> uploadFile(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final filePath = 'medical_reports/$fileName';

    try {
      final bytes = await file.readAsBytes();
      await supabase.storage.from('reports').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'application/octet-stream'),
      );

      final publicUrlResponse = supabase.storage.from('reports').getPublicUrl(filePath);

      // Return both the URL and the path
      return {'url': publicUrlResponse, 'path': filePath};
    } catch (e) {
      debugPrint("Error uploading file: $e");
      return null;
    }
  }

  // Open File to preview
  Future<void> openReportFile(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = fileUrl.split('/').last;
        final filePath = '${dir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        await OpenFilex.open(file.path);
      } else {
        throw Exception("Failed to download file: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error opening file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening file: $e")),
        );
      }
    }
  }

  // Delete file from Supabase
  Future<void> deleteFile(String filePath) async {
    try {
      await supabase.storage.from('reports').remove([filePath]);
      debugPrint("Successfully deleted file: $filePath");
    } catch (e) {
      debugPrint("Error deleting file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing file: $e")),
        );
      }
    }
  }

  // Booking Appointment
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

      await supabase.from('appointments').insert({
        'patient_id': selectedPatientId,
        'doctor_id': selectedDoctor!['doctor_id'],
        'slot_id': slotId,
        'appointment_date': appointmentDate,
        'appointment_time': selectedTimeSlot,
        'reason': reasonController.text,
        'status': 'pending',
        if (uploadedFileUrl != null) 'report_url': uploadedFileUrl,
      });

      await supabase.from('appointment_slots').update({
        'booked_count': slotResponse['booked_count'] + 1,
      }).eq('slot_id', slotId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment booked successfully!")),
      );

      reasonController.clear();
      setState(() {
        selectedFile = null;
        uploadedFileUrl = null;
        uploadedFilePath = null;
      });
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryThemeColor, secondaryThemeColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Book Appointment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black, // Changed for better contrast
          ),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryThemeColor),
        ),
      )
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- DOCTOR SELECTION ---
              _buildSectionHeader("Doctor", Icons.medical_services_outlined),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: selectDoctorOnMap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: selectedDoctorInfo == null
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select a Doctor from the Map",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Icon(Icons.map_outlined, color: primaryThemeColor),
                      ],
                    )
                        : Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: primaryThemeColor.withOpacity(0.1),
                          child: Icon(
                            Icons.medical_services_outlined,
                            color: primaryThemeColor,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name and Specialization
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8.0,
                                children: [
                                  Text(
                                    "Dr. ${selectedDoctorInfo!['doctorName']}",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "(${selectedDoctorInfo!['specialization']})",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // --- NEW: Clinic Name ---
                              Row(
                                children: [
                                  Icon(
                                    Icons.business_outlined,
                                    color: Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      selectedDoctorInfo!['clinicName'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Address
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      selectedDoctorInfo!['address'] ?? 'No address provided',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- DATE & TIME SELECTION ---
              _buildSectionHeader("Date & Time", Icons.calendar_today_outlined),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay:
                      DateTime.now().add(const Duration(days: 30)),
                      focusedDay: selectedDate ?? DateTime.now(),
                      calendarFormat: CalendarFormat.month,
                      selectedDayPredicate: (day) =>
                          isSameDay(selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) async {
                        setState(() {
                          selectedDate = selectedDay;
                          selectedTimeRange = null; // Reset the time range
                          selectedTimeSlot = null;  // Also reset the specific slot
                        });
                        await fetchAvailableSlots();
                      },
                      headerStyle: HeaderStyle(
                        titleTextStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        formatButtonVisible: false,
                        titleCentered: true,
                        leftChevronIcon:
                        Icon(Icons.chevron_left, color: primaryThemeColor),
                        rightChevronIcon: Icon(Icons.chevron_right,
                            color: primaryThemeColor),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: primaryThemeColor,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: secondaryThemeColor.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        weekendTextStyle:
                        const TextStyle(color: Colors.redAccent),
                        outsideDaysVisible: false,
                      ),
                    ),
                    if (selectedDate != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- TIME RANGE DROPDOWN ---
                            Builder(builder: (context) {
                              // Determine which hourly ranges have available slots.
                              final Set<int> availableHours = availableSlots
                                  .map<int>((slot) =>
                              (slot['slotDateTime'] as DateTime).hour)
                                  .toSet();

                              if (availableHours.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text("No available slots for this date."),
                                );
                              }

                              // Create the range strings like "10:00 - 11:00"
                              final hourlyRanges = availableHours.map((hour) {
                                final start = hour.toString().padLeft(2, '0');
                                final end = (hour + 1).toString().padLeft(2, '0');
                                return "$start:00 - $end:00";
                              }).toList()
                                ..sort(); // Sort the ranges chronologically

                              return DropdownButtonFormField<String>(
                                value: selectedTimeRange,
                                hint: const Text("Select an hourly range"),
                                decoration: const InputDecoration(
                                  labelText: "Time Range",
                                  border: OutlineInputBorder(),
                                  contentPadding:
                                  EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                                ),
                                items: hourlyRanges.map((range) {
                                  return DropdownMenuItem<String>(
                                    value: range,
                                    child: Text(range),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedTimeRange = value;
                                    selectedTimeSlot = null; // Reset specific slot selection
                                  });
                                },
                              );
                            }),

                            // --- SPECIFIC TIME SLOT BOXES (Filtered by Hourly Range) ---
                            if (selectedTimeRange != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "Select Specific Slot",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Builder(builder: (context) {
                                // Get the start hour from the selected range string
                                final startHour =
                                int.parse(selectedTimeRange!.split(':')[0]);

                                // Filter slots to show only those within the selected hour
                                final filteredSlots = availableSlots.where((slot) {
                                  final hour =
                                      (slot['slotDateTime'] as DateTime).hour;
                                  return hour == startHour;
                                }).toList();

                                if (filteredSlots.isEmpty) {
                                  return const Text(
                                      "No slots available in this range.");
                                }

                                return Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: filteredSlots.map<Widget>((slot) {
                                    final formattedTime = DateFormat('hh:mm a')
                                        .format((slot['slotDateTime'] as DateTime));
                                    final isSelected =
                                        selectedTimeSlot == slot['slot_time'];
                                    return ChoiceChip(
                                      label: Text(formattedTime),
                                      selected: isSelected,
                                      // This line removes the checkmark
                                      showCheckmark: false,
                                      onSelected: (selected) {
                                        setState(() {
                                          selectedTimeSlot =
                                          selected ? slot['slot_time'] : null;
                                        });
                                      },
                                      selectedColor: primaryThemeColor,
                                      labelStyle: TextStyle(
                                          color:
                                          isSelected ? Colors.white : Colors.black),
                                      backgroundColor: Colors.grey.shade200,
                                      // Add a border to the selected chip for better visual distinction
                                      shape: isSelected
                                          ? StadiumBorder(
                                          side: BorderSide(color: primaryThemeColor))
                                          : StadiumBorder(
                                          side: BorderSide(color: Colors.grey.shade300)),
                                    );
                                  }).toList(),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              // --- PATIENT & REASON ---
              _buildSectionHeader("Details", Icons.person_outline),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedPatientId,
                        items: patients
                            .map<DropdownMenuItem<String>>((patient) {
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
                      if (selectedPatientId != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                            Icons.person_outline, "Name", patientName),
                        const Divider(height: 24),
                        _buildDetailRow(
                            Icons.cake_outlined, "Age", patientAge),
                        const Divider(height: 24),
                        _buildDetailRow(
                            Icons.wc_outlined, "Gender", patientGender),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: "Reason for Appointment",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // --- FILE UPLOAD ---
                      selectedFile == null
                          ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: pickFile,
                          icon:
                          const Icon(Icons.upload_file_outlined),
                          label: const Text(
                              "Upload Medical Report (Optional)"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryThemeColor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            side: BorderSide(color: primaryThemeColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                          : Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.attach_file,
                                    color: Colors.black54,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedFile!.path
                                        .split('/')
                                        .last,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 4),
                            // --- FIXED: Using Row with even more compact buttons to prevent overflow ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Preview Button
                                TextButton.icon(
                                  onPressed: () async {
                                    if (uploadedFileUrl != null) {
                                      await openReportFile(
                                          uploadedFileUrl!);
                                    }
                                  },
                                  icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 20),
                                  label: const Text("Preview"),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                    primaryThemeColor,
                                    // Further reduce padding to make the button more compact
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                // Update Button
                                TextButton.icon(
                                  onPressed: pickFile,
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 20),
                                  label: const Text("Update"),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                    primaryThemeColor,
                                    // Further reduce padding to make the button more compact
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                // Remove Button
                                TextButton.icon(
                                  onPressed: () async {
                                    if (uploadedFilePath != null) {
                                      await deleteFile(
                                          uploadedFilePath!);
                                      setState(() {
                                        selectedFile = null;
                                        uploadedFileUrl = null;
                                        uploadedFilePath = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20),
                                  label: const Text("Remove"),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                    Colors.red.shade600,
                                    // Further reduce padding to make the button more compact
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- BOOK APPOINTMENT BUTTON ---
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryThemeColor, secondaryThemeColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: bookAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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