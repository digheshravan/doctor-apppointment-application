import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/patient/patient.dart'; // Assuming your theme colors might be here or used indirectly
import 'package:medi_slot/screens/patient/doctor_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BookAppointmentPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedDoctor;
  final Map<String, dynamic>? selectedDoctor;

  const BookAppointmentPage({Key? key, this.preselectedDoctor, this.selectedDoctor}) : super(key: key);

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
  // Using colors consistent with PatientDashboard if needed, or define locally
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
    } else if (widget.selectedDoctor != null) { // Handle selectedDoctor passed from patient.dart
      selectedDoctor = widget.selectedDoctor;
      selectedDoctorInfo = widget.selectedDoctor;
    }
    fetchPatients();
    // If a doctor is preselected, fetch slots immediately if a date is also known or default to today
    if (selectedDoctorInfo != null) {
      // Assuming selectedDate might be set or you want to fetch for today initially
      // For now, fetchAvailableSlots will be called when a date is picked
    }
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
        // Reset date and time slot when doctor changes
        selectedDate = null;
        selectedTimeSlot = null;
        availableSlots = [];
      });

      // No need to call fetchAvailableSlots here, it's called when date is selected
    }
  }

  // Fetch Appointments (relevant for patient history, not directly for booking UI here)
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
        // isLoading = false; //isLoading controls the whole page, primarily for patient data
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

    // Show loading indicator specifically for slots
    // setState(() { isLoadingSlots = true; }); // You might want a separate loading state for slots

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
        // If the selected date is today, filter out past slots.
        // If selected date is in the future, all open slots are valid.
        if (selectedDate!.year == now.year &&
            selectedDate!.month == now.month &&
            selectedDate!.day == now.day) {
          return slotDateTime.isAfter(now);
        }
        return true;
      })
          .toList();

      slots.sort((a, b) =>
          (a['slotDateTime'] as DateTime).compareTo(b['slotDateTime'] as DateTime));

      setState(() {
        availableSlots = slots;
        selectedTimeSlot = null; // Reset time slot when new slots are fetched
        // isLoadingSlots = false;
      });
    } catch (e) {
      debugPrint("Error fetching slots: $e");
      setState(() {
        availableSlots = [];
        // isLoadingSlots = false;
      });
    }
  }

  // Fetch Patients
  Future<void> fetchPatients() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final data = await supabase
          .from('patients')
          .select('patient_id, name, age, gender')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          patients = data;
          if (patients.isNotEmpty) {
            selectedPatientId = patients.first['patient_id'];
            fetchAppointments(); // Fetches past appointments for this patient
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching patients: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // File picker
  Future<void> pickFile() async {
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
          uploadedFilePath = uploadResult['path'];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error uploading file. Please try again.")),
          );
        }
      }
    } else {
      setState(() {
        selectedFile = null;
        uploadedFileUrl = null;
        uploadedFilePath = null;
      });
    }
  }

  // Upload file
  Future<Map<String, String>?> uploadFile(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final filePath = 'medical_reports/$fileName';

    try {
      final bytes = await file.readAsBytes();
      await supabase.storage.from('reports').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'application/octet-stream'), // More generic for mixed types
      );
      final publicUrlResponse = supabase.storage.from('reports').getPublicUrl(filePath);
      return {'url': publicUrlResponse, 'path': filePath};
    } catch (e) {
      debugPrint("Error uploading file: $e");
      return null;
    }
  }

  // Open File
  Future<void> openReportFile(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = fileUrl.split('?').first.split('/').last; // Handle potential query params in URL
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
          SnackBar(content: Text("Error opening file: Could not load report.")),
        );
      }
    }
  }

  // Delete file
  Future<void> deleteFile(String filePath) async {
    try {
      await supabase.storage.from('reports').remove([filePath]);
      debugPrint("Successfully deleted file: $filePath");
    } catch (e) {
      debugPrint("Error deleting file: $e");
      // Optionally show a snackbar, but maybe not necessary if pickFile handles UI update
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
        const SnackBar(content: Text("Please fill all required fields and select a time slot.")),
      );
      return;
    }

    final appointmentDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

    // Add a loading state for the booking process
    setState(() {
      // e.g. _isBooking = true; // you'd need to define this boolean
    });

    try {
      final slotResponse = await supabase
          .from('appointment_slots')
          .select('slot_id, slot_limit, booked_count')
          .eq('doctor_id', selectedDoctor!['doctor_id'])
          .eq('slot_date', appointmentDate)
          .eq('slot_time', selectedTimeSlot!)
          .maybeSingle();

      if (slotResponse == null) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selected slot is no longer available or not found!")),
          );
        }
        await fetchAvailableSlots(); // Refresh slots
        return;
      }
      if (slotResponse['booked_count'] >= slotResponse['slot_limit']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selected slot has just been filled. Please select another.")),
          );
        }
        await fetchAvailableSlots(); // Refresh slots
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
        'status': 'pending', // Default status
        if (uploadedFileUrl != null) 'report_url': uploadedFileUrl,
      });

      await supabase.from('appointment_slots').update({
        'booked_count': slotResponse['booked_count'] + 1,
      }).eq('slot_id', slotId);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment booked successfully!")),
        );
        reasonController.clear();
        setState(() {
          selectedFile = null;
          uploadedFileUrl = null;
          uploadedFilePath = null;
          // Optionally reset date and time or navigate away
          selectedDate = null;
          selectedTimeSlot = null;
          availableSlots = [];
        });
        // fetchAppointments(); // Already called in fetchPatients and after booking below

        // Navigate back to patient dashboard or a confirmation screen
        // Consider which page is most appropriate
        Navigator.pop(context); // Pops the current booking page
        // Or if it's part of the PatientDashboard's IndexedStack, you might not pop
        // but rather switch the index back in PatientDashboard
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error booking appointment: ${e.toString()}")),
        );
      }
    } finally {
      if(mounted) {
        setState(() {
          // _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPatient = patients.firstWhere(
          (p) => p['patient_id'] == selectedPatientId,
      orElse: () => <String, dynamic>{}, // Provide a default empty map
    );

    // Safe access to patient details
    final patientName = selectedPatient['name'] ?? 'N/A';
    final patientAge = selectedPatient['age']?.toString() ?? 'N/A';
    final patientGender = selectedPatient['gender'] ?? 'N/A';

    return Scaffold(
      // appBar: AppBar( // REMOVED APP BAR
      //   flexibleSpace: Container(
      //     decoration: BoxDecoration(
      //       gradient: LinearGradient(
      //         colors: [primaryThemeColor, secondaryThemeColor],
      //         begin: Alignment.topLeft,
      //         end: Alignment.bottomRight,
      //       ),
      //     ),
      //   ),
      //   title: const Text(
      //     "Book Appointment",
      //     style: TextStyle(
      //       fontWeight: FontWeight.bold,
      //       color: Colors.black,
      //     ),
      //   ),
      //   centerTitle: true,
      //   elevation: 6,
      // ),
      backgroundColor: Colors.white, // Or your app's default background
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
              // ADDED "Book Appointment" Text here
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                child: Text(
                  "Book Appointment",
                  textAlign: TextAlign.center, // <<< THIS MAKES THE TEXT CENTERED
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryThemeColor,
                  ),
                ),
              ),

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
                          "Select a Doctor from Map",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Icon(Icons.map_outlined, color: primaryThemeColor),
                      ],
                    )
                        : Row( // Display selected doctor info
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
                              Text(
                                selectedDoctorInfo!['doctorName'] ?? 'N/A',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                selectedDoctorInfo!['specialization'] ?? 'N/A',
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                              ),
                              Text(
                                selectedDoctorInfo!['clinicName'] ?? 'N/A',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 18),
                      ],
                    ),
                  ),
                ),
              ),

              // --- DATE SELECTION ---
              _buildSectionHeader("Date", Icons.calendar_today_outlined),
              Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0), // Reduced padding for calendar
                    child: TableCalendar(
                      firstDay: DateTime.now(), // Disable past dates
                      lastDay: DateTime.now().add(const Duration(days: 90)), // Allow booking up to 90 days in advance
                      focusedDay: selectedDate ?? DateTime.now(),
                      selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          selectedDate = selectedDay;
                          // focusedDay = focusedDay; // No need to set focusedDay here, it's handled by TableCalendar
                          selectedTimeSlot = null; // Reset time slot when date changes
                          availableSlots = [];   // Clear previous slots
                        });
                        if (selectedDoctor != null) {
                          fetchAvailableSlots();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please select a doctor first to see available slots.")),
                          );
                        }
                      },
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: primaryThemeColor,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: secondaryThemeColor.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(color: primaryThemeColor, shape: BoxShape.circle),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        leftChevronIcon: Icon(Icons.chevron_left, color: primaryThemeColor),
                        rightChevronIcon: Icon(Icons.chevron_right, color: primaryThemeColor),
                      ),
                    ),
                  )),

              // --- TIME SLOT SELECTION ---
              if (selectedDate != null && selectedDoctor != null) ...[
                _buildSectionHeader("Available Time Slots", Icons.access_time_outlined),
                if (availableSlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                        child: Text(
                          "No available slots for this date or doctor.\nPlease try another date or doctor.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                        )
                    ),
                  )
                else
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: availableSlots.map<Widget>((slot) {
                      final time = slot['slot_time'] as String;
                      // Format time for display (e.g., 09:00:00 to 9:00 AM)
                      final displayTime = DateFormat.jm().format(DateFormat("HH:mm:ss").parse(time));
                      return ChoiceChip(
                        label: Text(displayTime),
                        selected: selectedTimeSlot == time,
                        onSelected: (selected) {
                          setState(() {
                            selectedTimeSlot = selected ? time : null;
                          });
                        },
                        selectedColor: primaryThemeColor,
                        labelStyle: TextStyle(
                          color: selectedTimeSlot == time ? Colors.white : Colors.black,
                        ),
                        backgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
              ],

              // --- PATIENT SELECTION ---
              if (patients.isNotEmpty) ...[
                _buildSectionHeader("Patient Details", Icons.person_outline),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: "Select Patient",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: Icon(Icons.person_search_outlined, color: primaryThemeColor),
                          ),
                          value: selectedPatientId,
                          items: patients.map<DropdownMenuItem<String>>((patient) {
                            return DropdownMenuItem<String>(
                              value: patient['patient_id'],
                              child: Text(patient['name'] ?? 'Unknown Patient'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPatientId = value;
                              fetchAppointments(); // Update appointments for selected patient
                            });
                          },
                        ),
                        if(selectedPatientId != null && selectedPatient.isNotEmpty)...[
                          const SizedBox(height: 16),
                          _buildDetailRow(Icons.person, "Name", patientName),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.cake, "Age", patientAge),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.wc, "Gender", patientGender),
                        ]
                      ],
                    ),
                  ),
                ),
              ] else if (patients.isEmpty && !isLoading) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 50, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text("No patient profiles found.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text("Add Patient Profile"),
                          onPressed: () {
                            // Navigate to add patient profile screen
                            // Assuming you have a route for this:
                            // Navigator.push(context, MaterialPageRoute(builder: (_) => AddPatientProfileScreen()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Navigation to add profile not implemented yet.")),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryThemeColor,
                            foregroundColor: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],

              // --- REASON FOR APPOINTMENT ---
              _buildSectionHeader("Reason for Appointment", Icons.notes_outlined),
              TextFormField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: "Briefly describe your reason for visit...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a reason for the appointment.';
                  }
                  return null;
                },
              ),

              // --- FILE UPLOAD ---
              _buildSectionHeader("Upload Medical Report (Optional)", Icons.attach_file_outlined),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(selectedFile == null ? Icons.upload_file_outlined : Icons.change_circle_outlined),
                        label: Text(selectedFile == null ? "Select File" : "Change File"),
                        onPressed: pickFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryThemeColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (selectedFile != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.insert_drive_file_outlined, color: primaryThemeColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFile!.path.split('/').last,
                                style: const TextStyle(fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.preview_outlined, color: primaryThemeColor),
                              onPressed: () {
                                if (uploadedFileUrl != null) {
                                  openReportFile(uploadedFileUrl!);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("File not uploaded yet or URL is missing.")),
                                  );
                                }
                              },
                              tooltip: "Preview File",
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                if (uploadedFilePath != null) {
                                  await deleteFile(uploadedFilePath!);
                                }
                                setState(() {
                                  selectedFile = null;
                                  uploadedFileUrl = null;
                                  uploadedFilePath = null;
                                });
                              },
                              tooltip: "Remove File",
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),


              // --- BOOK APPOINTMENT BUTTON ---
              Padding(
                padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                child: Center(
                  child: ElevatedButton(
                    onPressed: bookAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryThemeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 3,
                    ),
                    child: const Text("Book Appointment", style: TextStyle(color: Colors.white)),
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
