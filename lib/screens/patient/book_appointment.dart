import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/patient/doctor_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../auth/auth_service.dart';

class BookAppointmentPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedDoctor;

  const BookAppointmentPage({Key? key, this.preselectedDoctor}) : super(key: key);

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
    final supabase = Supabase.instance.client;
    final _formKey = GlobalKey<FormState>(); // For validating the reason

    String? selectedPatientId;
    Map<String, dynamic>? _selectedPatientDetails;
    Map<String, dynamic>? selectedDoctor;
    Map<String, dynamic>? selectedDoctorInfo;
    DateTime? selectedDate;
    String? selectedTimeSlot;
    String? selectedTimeRange;
    List<String> availableTimeRanges = [];
    bool isLoadingTimeRanges = false;
    List<Map<String, dynamic>> allFetchedSlotsForDate = [];
    List<dynamic> allSlots = [];
    List<dynamic> filteredSlots = [];

    String? selectedTimeSlotString; // To store the time string like "09:00"
    String? selectedSlotId; // To store the UUID of the selected slot


  // Stores all slots for a selected date before range filtering

    final Color primaryThemeColor = const Color(
      0xFF2193b0); // From your existing code
    final Color secondaryThemeColor = const Color(
      0xFF6dd5ed); // From your existing code
    final Color pageBackgroundColor = const Color(
      0xFFF0F5FF); // From patient.dart
    final Color cardBackgroundColor = Colors.white; // Common card color

    List<Map<String, dynamic>> patients = [];
    List<dynamic> appointments = []; // Not directly used in booking UI but fetched for context
    List<dynamic> availableSlots = []; // Slots filtered by time range

    final TextEditingController reasonController = TextEditingController();
    bool isLoading = true; // For initial patient list loading
    bool _isBooking = false; // NEW: For loading state during booking process

    File? selectedFile;
    String? uploadedFileUrl;
    String? uploadedFilePath;

    @override
    void initState() {
      super.initState();
      debugPrint("--- BookAppointmentPage initState CALLED ---"); // Log 1
      debugPrint("BookAppointmentPage initState: widget.preselectedDoctor = ${widget.preselectedDoctor}"); // Log 2

      // In BookAppointmentPage's initState
      final String instanceIdentifier = DateTime.now().millisecondsSinceEpoch.toString(); // Or a random number
      debugPrint("--- BookAppointmentPage ($instanceIdentifier) initState CALLED ---");
      debugPrint("BookAppointmentPage ($instanceIdentifier) initState: widget.preselectedDoctor = ${widget.preselectedDoctor}");
      // ... and so on for other logs in initState

      if (widget.preselectedDoctor != null) {
        selectedDoctorInfo = Map<String, dynamic>.from(widget.preselectedDoctor!);
        selectedDoctor = Map<String, dynamic>.from(widget.preselectedDoctor!);
        debugPrint("BookAppointmentPage initState: SUCCESSFULLY SET selectedDoctorInfo = $selectedDoctorInfo"); // Log 3
      } else {
        debugPrint("BookAppointmentPage initState: widget.preselectedDoctor was NULL."); // Log 4
      }

      fetchPatients(); // This call leads to the logs you ARE seeing
    }

    @override
    void dispose() {
    reasonController.dispose();
    super.dispose();
    }

    Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryThemeColor, size: 20),
          const SizedBox(width: 12),
          Text(
            "$label:",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
    }

    Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Row(
        children: [
          Icon(icon, color: primaryThemeColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ],
      ),
    );
    }

    // Inside fetchPatients() in _BookAppointmentPageState
    Future<void> fetchPatients() async {
      setState(() { // Assuming you have an isLoadingPatients state
        isLoading = true; // Or some specific isLoadingPatients = true;
      });
      try {
        final userId = AuthService().currentUserId;
        debugPrint("BookAppointmentPage fetchPatients: Current User ID = $userId");

        if (userId == null) {
          debugPrint("BookAppointmentPage fetchPatients: No logged-in user found. Patients list will be empty.");
          setState(() {
            patients = [];
            isLoading = false;
          });
          return;
        }

        final response = await supabase
            .from('patients')
            .select()
            .eq('user_id', userId);

        debugPrint("BookAppointmentPage fetchPatients: Supabase response = $response");

        // Check for errors from Supabase if response is a PostgrestResponse
        // if (response.error != null) {
        //   debugPrint("BookAppointmentPage fetchPatients: Supabase error: ${response.error!.message}");
        //   setState(() {
        //     patients = [];
        //     isLoading = false;
        //   });
        //   return;
        // }

        final data = (response as List) // Assuming response is directly a List
            .map((e) => e as Map<String, dynamic>)
            .toList();

        debugPrint("BookAppointmentPage fetchPatients: Fetched data = $data");

        setState(() {
          patients = data;
          if (patients.length == 1 && widget.preselectedDoctor == null) { // Only auto-select if no doctor is preselected
            selectedPatientId = patients.first['patient_id'];
            _selectedPatientDetails = patients.first; // Also populate details
            debugPrint("BookAppointmentPage fetchPatients: Auto-selected single patient: $selectedPatientId, Details: $_selectedPatientDetails");
          } else if (patients.isNotEmpty) {
            debugPrint("BookAppointmentPage fetchPatients: Multiple patients found or doctor preselected. No auto-selection of patient.");
          } else {
            debugPrint("BookAppointmentPage fetchPatients: No patients found for user.");
          }
          isLoading = false;
        });
      } catch (e) {
        debugPrint("BookAppointmentPage fetchPatients: Error fetching patients: $e");
        setState(() {
          patients = []; // Ensure patients is empty on error
          isLoading = false;
        });
      }
    }

    Future<void> selectDoctorOnMap() async {
      final selected = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const DoctorMapPage()),
      );

      if (selected != null && mounted) {
        final doctorId = selected['doctorId'] ?? selected['doctor_id'];
        final doctorName = selected['doctorName'] ?? selected['doctor_name'] ??
            "Unknown";
        final specialization = selected['specialization'] ?? "General";
        final clinicName = selected['clinicName'] ?? selected['clinic_name'] ??
            "N/A";
        final address = selected['address'] ?? "N/A";

        setState(() {
          selectedDoctorInfo = {
            'name': selected['doctorName'] ?? selected['name'] ?? "Unknown",
            // Primary key for doctor's name
            'doctor_id': selected['doctorId'] ?? selected['doctor_id'],
            // Essential
            'specialization': selected['specialization'] ?? "General",
            'clinicName': selected['clinicName'] ?? "N/A",
            'address': selected['address'] ?? "N/A",
          };
          selectedDoctor = Map<String, dynamic>.from(
              selectedDoctorInfo!); // Update the other copy too
          debugPrint(
              "BookAppointmentPage: Doctor selected/changed via map: $selectedDoctorInfo");


          selectedDoctor = {
            'doctor_id': doctorId,
            'clinic_id': selected['clinic_id'], // make sure this exists
            'name': doctorName,
            'specialization': specialization,
            'clinicName': clinicName,
            'address': address,
          };

          selectedDate = null;
          selectedTimeRange = null;
          availableTimeRanges = [];
          selectedTimeSlot = null;
          availableSlots = [];
          allFetchedSlotsForDate = [];
          reasonController.clear();
          selectedFile = null;
          uploadedFileUrl = null;
          uploadedFilePath = null;
        });
      }
    }

    List<String> _generateHourlyRanges(List<Map<String, dynamic>> slots) {
      if (slots.isEmpty) return [];

      // Extract all slot times from DB (slot_time assumed as HH:mm string)
      final times = slots.map((s) => s['slot_time'] as String).toList();

      // Parse into DateTime objects for sorting
      final parsed = times.map((t) {
        final parts = t.split(':');
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }).toList()
        ..sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));

      if (parsed.isEmpty) return [];

      // Generate 1-hour ranges
      final List<String> ranges = [];
      for (int i = 0; i < parsed.length; i++) {
        final start = parsed[i];
        final endHour = (start.hour + 1) % 24;
        final end = TimeOfDay(hour: endHour, minute: start.minute);

        final startStr = start.format(context);
        final endStr = end.format(context);
        ranges.add("$startStr - $endStr");
      }

      return ranges.toSet().toList(); // unique
    }

    Future<void> fetchAvailableSlots() async {
      if (selectedDoctor == null || selectedDoctor!['doctor_id'] == null ||
          selectedDate == null) {
        // ... (your existing pre-condition checks)
        return;
      }

      setState(() {
        isLoadingTimeRanges = true;
        allFetchedSlotsForDate = [];
        availableTimeRanges = [];
        availableSlots = []; // Clear previous slots
        selectedTimeRange = null; // Clear selected range
        selectedTimeSlotString = null; // Clear selected slot
        selectedSlotId = null;
      });

      try {
        final response = await supabase
            .from('appointment_slots')
            .select('slot_id, slot_time, status, booked_count, slot_limit')
            .eq('doctor_id', selectedDoctor!['doctor_id'])
            .eq('slot_date', selectedDate!.toIso8601String().substring(0, 10));

        final List<Map<String, dynamic>> fetchedSlotsFromDB = (response is List)
            ? response.where((e) => e != null).map((e) =>
        Map<String,
            dynamic>.from(e as Map)).toList()
            : [];

        final DateTime now = DateTime.now();
        final TimeOfDay currentTimeOfDay = TimeOfDay.fromDateTime(now);
        final bool isToday = isSameDay(selectedDate, now);

        List<Map<String, dynamic>> openAndFutureSlots = fetchedSlotsFromDB
            .where((slot) {
          final status = slot['status'] ?? '';
          final bookedCount = slot['booked_count'] ?? 0;
          final slotLimit = slot['slot_limit'] ?? 1;
          bool isSlotOpen = status == 'open' && bookedCount < slotLimit;

          if (!isSlotOpen) return false;

          // If today, also check if slot time is in the future
          if (isToday) {
            final slotTimeStr = slot['slot_time']?.toString() ?? '';
            if (slotTimeStr.contains(':')) {
              final parts = slotTimeStr.split(':');
              final hourInt = int.tryParse(parts[0]);
              final minuteInt = int.tryParse(parts[1]);
              if (hourInt != null && minuteInt != null) {
                final slotTimeOfDay = TimeOfDay(
                    hour: hourInt, minute: minuteInt);
                // Compare current time with slot time
                if ((slotTimeOfDay.hour * 60 + slotTimeOfDay.minute) <
                    (currentTimeOfDay.hour * 60 + currentTimeOfDay.minute)) {
                  return false; // Slot is in the past
                }
              }
            }
          }
          return true;
        }).toList();

        // Sort the valid slots by time
        openAndFutureSlots.sort((a, b) {
          final timeA = a['slot_time']?.toString() ?? '23:59';
          final timeB = b['slot_time']?.toString() ?? '23:59';
          return timeA.compareTo(timeB);
        });

        // Build time ranges dynamically from these valid slots
        final ranges = openAndFutureSlots.map((slot) {
          final timeStr = slot['slot_time']?.toString() ?? '';
          if (!timeStr.contains(':')) return null;

          final parts = timeStr.split(':');
          final hourInt = int.tryParse(parts[0]);
          if (hourInt == null) return null;

          // No need to filter range start by current time here again,
          // because openAndFutureSlots already contains only future slots for today.
          final startHourStr = hourInt.toString().padLeft(2, '0');
          final endHourInt = (hourInt + 1) % 24; // Handles 23:00 -> 00:00
          final endHourStr = endHourInt.toString().padLeft(2, '0');

          return "$startHourStr:00 - $endHourStr:00";
        })
            .whereType<String>()
            .toSet()
            .toList(); // .toSet().toList() for uniqueness

        setState(() {
          allFetchedSlotsForDate =
              openAndFutureSlots; // Store all valid (open and future) slots
          availableTimeRanges = ranges..sort(); // Sort the generated ranges
          isLoadingTimeRanges = false;
          // If ranges are now empty, but there are slots, _filterSlotsByTimeRange("") might be called
          // or you can directly populate availableSlots with allFetchedSlotsForDate
          if (availableTimeRanges.isEmpty &&
              allFetchedSlotsForDate.isNotEmpty) {
            availableSlots =
            List<dynamic>.from(allFetchedSlotsForDate); // Show all if no ranges
          } else {
            availableSlots = [
            ]; // Or filter based on the first available range if you want to auto-select
          }
        });
      } catch (e, st) {
        debugPrint("❌ Error fetching slots: $e\n$st");
        setState(() => isLoadingTimeRanges = false);
      }
    }

    void _filterSlotsByTimeRange(String? rangeString) {
      // Allow null for when no range is selected
      if (allFetchedSlotsForDate.isEmpty) {
        setState(() => availableSlots = []);
        return;
      }

      // If no range is selected (e.g. rangeString is null or empty),
      // and it's today, show all available (future) slots for the day.
      // If ranges ARE available, typically user must select one.
      // The logic here depends on how you want to handle the "no range selected" state.
      if (rangeString == null || rangeString.isEmpty) {
        // If availableTimeRanges is empty (meaning we show all slots directly)
        // or if you want to default to showing all slots if no range is chosen.
        // The current fetchAvailableSlots already populates availableSlots if ranges are empty.
        // So, if rangeString is null/empty, we might not need to do anything here if
        // fetchAvailableSlots already handled it.
        // However, if a range *was* selected and then cleared, we might need to reset.
        if (availableTimeRanges
            .isNotEmpty) { // Only clear if ranges exist and user de-selected
          setState(() {
            availableSlots = [];
            selectedTimeSlot = null; // Also clear selected slot
            selectedTimeSlotString = null;
            selectedSlotId = null;
          });
        } else { // No ranges were generated, allFetchedSlotsForDate is what's available
          setState(() {
            availableSlots = List<dynamic>.from(allFetchedSlotsForDate);
            selectedTimeSlot = null;
            selectedTimeSlotString = null;
            selectedSlotId = null;
          });
        }
        return;
      }


      try {
        final parts = rangeString.split(' - ');
        // ... (rest of your parsing logic for startStr, endStr, startHour, endHour etc.)
        // This part should remain largely the same.
        final startStr = parts[0];
        final endStr = parts[1];
        // ... parse startHour, startMinute, endHour, endMinute ...
        // Ensure robust parsing as before
        final startTODParts = startStr.split(':');
        final endTODParts = endStr.split(':');

        if (startTODParts.length != 2 || endTODParts.length != 2) {
          debugPrint("⚠️ Invalid time format in range parts: $rangeString");
          setState(() => availableSlots = []);
          return;
        }

        final startHour = int.tryParse(startTODParts[0]);
        final startMinute = int.tryParse(
            startTODParts[1]); // Typically 00 for ranges
        final endHour = int.tryParse(endTODParts[0]);
        final endMinute = int.tryParse(
            endTODParts[1]); // Typically 00 for ranges

        if (startHour == null || startMinute == null || endHour == null ||
            endMinute == null) {
          debugPrint(
              "⚠️ Failed to parse hours/minutes from range: $rangeString");
          setState(() => availableSlots = []);
          return;
        }

        final rangeStart = TimeOfDay(hour: startHour, minute: startMinute);
        final rangeEnd = TimeOfDay(hour: endHour,
            minute: endMinute); // This is the start of the next hour

        final DateTime now = DateTime.now();
        final bool isToday = isSameDay(selectedDate, now);
        final TimeOfDay currentTimeOfDay = TimeOfDay.fromDateTime(now);

        final filtered = allFetchedSlotsForDate.where((slot) {
          final slotData = slot as Map<String, dynamic>; // Ensure type
          final slotTimeStr = slotData['slot_time']?.toString() ?? '';
          if (slotTimeStr.isEmpty || !slotTimeStr.contains(':')) return false;

          final slotTODParts = slotTimeStr.split(':');
          if (slotTODParts.length < 2) return false;

          final slotHour = int.tryParse(slotTODParts[0]);
          final slotMinute = int.tryParse(slotTODParts[1]);

          if (slotHour == null || slotMinute == null) return false;

          final currentSlotTime = TimeOfDay(hour: slotHour, minute: slotMinute);

          // Check if slot falls within the selected hour-long range
          // The slot's hour must match the range's start hour.
          bool isInRange = currentSlotTime.hour == rangeStart.hour;


          // If today, ensure the slot itself is in the future (already handled by allFetchedSlotsForDate)
          // but double-checking here or relying on the pre-filtered list is fine.
          // This check is somewhat redundant if allFetchedSlotsForDate is correctly pre-filtered in fetchAvailableSlots.
          if (isToday) {
            if ((currentSlotTime.hour * 60 + currentSlotTime.minute) <
                (currentTimeOfDay.hour * 60 + currentTimeOfDay.minute)) {
              // This slot is in the past, even if the range itself is valid
              // This should ideally not happen if allFetchedSlotsForDate is already filtered.
              return false;
            }
          }

          return isInRange;
        }).toList();

        // Sort the final list of slots for display
        filtered.sort((a, b) {
          final timeA = (a as Map<String, dynamic>)['slot_time']?.toString() ??
              '23:59';
          final timeB = (b as Map<String, dynamic>)['slot_time']?.toString() ??
              '23:59';
          return timeA.compareTo(timeB);
        });

        setState(() {
          availableSlots = filtered;
          selectedTimeSlot = null; // Reset selection when range changes
          selectedTimeSlotString = null;
          selectedSlotId = null;
        });
      } catch (e, st) {
        debugPrint("❌ Error filtering slots by range: $e\n$st");
        setState(() => availableSlots = []);
      }
    }

    // Your existing pickFile method, slightly adjusted for clarity if needed
    Future<void> pickFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          selectedFile = file;
          uploadedFileUrl =
          null; // Clear previous URL while new one is uploading
          uploadedFilePath = null; // Clear previous path
        });

        // Call your existing uploadFile method
        final uploadedDetails = await uploadFile(
            file); // uploadFile will handle Supabase interaction

        if (!mounted) return; // Check if the widget is still in the tree

        if (uploadedDetails != null) {
          setState(() {
            uploadedFileUrl = uploadedDetails['url'];
            uploadedFilePath = uploadedDetails['path'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("File uploaded successfully!"),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Failed to upload file. Please try again."),
                backgroundColor: Colors.redAccent),
          );
          setState(() {
            selectedFile = null; // Clear selection on upload failure
          });
        }
      } else {
        // User canceled the picker
        debugPrint("File picking cancelled.");
      }
    }

// Your existing uploadFile method, ensure it's robust
// This method will be called by pickFile
    Future<Map<String, String>?> uploadFile(File file) async {
      final fileName = '${DateTime
          .now()
          .millisecondsSinceEpoch}_${file.path
          .split('/')
          .last}';
      final filePath = 'medical_reports/$fileName';

      try {
        final bytes = await file.readAsBytes();
        await supabase.storage.from('reports').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: file.path.endsWith('.pdf')
              ? 'application/pdf'
              : 'image/${file.path
              .split('.')
              .last}'),
        );
        final publicUrlResponse = supabase.storage.from('reports').getPublicUrl(
            filePath);
        return {'url': publicUrlResponse, 'path': filePath};
      } catch (e) {
        debugPrint("Error uploading file: $e");
        return null;
      }
    }

    Future<void> deleteFileFromUIAndStorage() async {
      if (uploadedFilePath == null) return;

      setState(() {
        // Optimistically remove from UI
        selectedFile = null;
        uploadedFileUrl = null;
      });

      try {
        await supabase.storage
            .from('medical_reports') // Your Supabase bucket name
            .remove([uploadedFilePath!]); // Pass path in a list

        setState(() {
          uploadedFilePath = null; // Clear the path after successful deletion
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File deleted successfully."),
              backgroundColor: Colors.orangeAccent),
        );
      } on StorageException catch (e) {
        debugPrint("Error deleting file from Supabase: ${e.message}");
        // Optionally, revert UI state if deletion fails, though often not necessary
        // For simplicity, we just show an error.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting file: ${e.message}")),
        );
      } catch (e) {
        debugPrint("Generic error deleting file: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred while deleting file: $e")),
        );
      }
    }

    Future<void> openReportFile(String fileUrl) async {
      try {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final fileName = fileUrl
              .split('?')
              .first
              .split('/')
              .last;
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
            const SnackBar(
                content: Text("Error opening file: Could not load report.")),
          );
        }
      }
    }

    // NEW: Function to reset all relevant fields
  void _resetFormAndSelections() {setState(() {
    // Keep the preselected doctor if one was provided initially
      selectedDoctorInfo = null;
      selectedDoctor = null;




    // Clear all other selections and data
    selectedPatientId = null;
    _selectedPatientDetails = null;
    selectedDate = null;
    selectedTimeRange = null;
    availableTimeRanges = [];
    allFetchedSlotsForDate = [];
    availableSlots = [];
    selectedTimeSlotString = null;
    selectedSlotId = null;

    // Clear file and form controller
      debugPrint("Before reasonController.clear(): text is '${reasonController.text}'");
      reasonController.clear();
      debugPrint("After reasonController.clear(): text is '${reasonController.text}'");
    selectedFile = null;
    uploadedFileUrl = null;
    uploadedFilePath = null;
    _formKey.currentState?.reset(); // Resets validation state

    // Reset loading flags
    isLoadingTimeRanges = false;
    _isBooking = false;
  });
  }

    Future<void> bookAppointment() async {
      if (selectedDoctorInfo == null ||
          selectedDoctor == null ||
          selectedDoctor!['doctor_id'] == null ||
          selectedPatientId == null ||
          selectedDate == null ||
          selectedSlotId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              "Please select a Doctor, Patient, Date, and Time Slot.")),
        );
        return;
      }

      setState(() => _isBooking = true);

      final String currentSlotIdToUpdate = selectedSlotId!; // Capture before any resets

      try {
        // 1. Insert the appointment
        await supabase.from('appointments').insert({
          'doctor_id': selectedDoctor!['doctor_id'],
          'patient_id': selectedPatientId,
          'appointment_date': selectedDate!.toIso8601String().substring(0, 10),
          'appointment_time': selectedTimeSlotString,
          'reason': reasonController.text,
          'report_url': uploadedFileUrl,
          'status': 'pending',
          'slot_id': currentSlotIdToUpdate, // Use the captured slot_id
        });

        // 2. Fetch the current slot details to update it
        try {
          final slotResponse = await supabase
              .from('appointment_slots')
              .select('booked_count, slot_limit, status')
              .eq('slot_id', currentSlotIdToUpdate)
              .single(); // Use .single() as slot_id should be unique

          // final slotData = slotResponse; // Supabase Flutter v1 already returns data or throws
          final currentBookedCount = slotResponse['booked_count'] as int? ?? 0;
          final slotLimit = slotResponse['slot_limit'] as int? ?? 1;
          // String currentStatus = slotResponse['status'] as String? ?? 'open'; // Not strictly needed if we recalculate

          final newBookedCount = currentBookedCount + 1;
          String newStatus = "open"; // Default to open

          if (newBookedCount >= slotLimit) {
            newStatus = "closed";
          }

          // 3. Update the slot
          await supabase
              .from('appointment_slots')
              .update({
            'booked_count': newBookedCount,
            'status': newStatus,
          })
              .eq('slot_id', currentSlotIdToUpdate);

          debugPrint(
              "Slot $currentSlotIdToUpdate updated: booked_count=$newBookedCount, status=$newStatus");
        } catch (slotUpdateError) {
          debugPrint(
              "Error fetching/updating slot $currentSlotIdToUpdate: $slotUpdateError");
          // Log this error. The appointment is booked, but the slot update failed.
          // This might require manual reconciliation or a more robust error handling strategy.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                "Appointment booked, but error syncing slot details: ${slotUpdateError
                    .toString()}")),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment booked successfully!")),
        );
        _resetFormAndSelections();
        if (mounted) {
          setState(() {
            _isBooking = false;
          });
        }
      } catch (e) {
        debugPrint("Error booking appointment or updating slot: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Failed to book appointment: ${e.toString()}")),
        );
        setState(() => _isBooking = false);
      }
    }
  // Inside class _BookAppointmentPageState:

  @override
    Widget build(BuildContext context) {
      // Define today and the limit for selectable dates
      final DateTime now = DateTime.now();
      // Defines the START of today (00:00:00)
      final DateTime firstSelectableDate = DateTime(
          now.year, now.month, now.day);
      // Defines the END of the 5th day from today (effectively today + 4 full days)
      final DateTime lastSelectableDate = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 4));

      return Scaffold(
        // 1. Set the Scaffold background color
        backgroundColor: pageBackgroundColor,
        appBar: AppBar(
          title: const Text("Book Appointment"),
          titleTextStyle: TextStyle( // Style for the title
            color: Color(0xFF0D47A1),
            // Choose a color that contrasts well with pageBackgroundColor
            // For 0xFFF0F5FF (light blue), a dark blue or black is good.
            fontWeight: FontWeight.bold,
            fontSize: 28, // Adjust as needed

          ),
          backgroundColor: pageBackgroundColor,
          // Make AppBar background match the page background
          elevation: 0,
          // Keeps it flat, or add a slight shadow if preferred
          iconTheme: IconThemeData(
              color: primaryThemeColor), // Back button color
        ),
        body: SafeArea(
          child: RefreshIndicator( // <<<--- ONLY ONE RefreshIndicator
            onRefresh: () async {
              _resetFormAndSelections();
              // Optional: await fetchPatients();
            },
            color: primaryThemeColor,
            child: SingleChildScrollView( // <<<--- This is the direct child that will be scrollable and refreshable
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section: Select Doctor
                    _buildSectionHeader(
                        "Select Doctor*", Icons.person_search_outlined),

                    if (_formKey.currentState?.validate() == false &&
                        selectedDoctorInfo == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, top: 0),
                        child: Text("Please select a doctor.", style: TextStyle(
                            color: Theme
                                .of(context)
                                .colorScheme
                                .error, fontSize: 12)),
                      ),
                    const SizedBox(height: 10),

                    if (selectedDoctorInfo == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map_outlined,
                              color: Colors.white),
                          label: const Text("Choose Doctor from Map",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          onPressed: selectDoctorOnMap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryThemeColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        color: cardBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedDoctorInfo!['name'] ??
                                          'N/A',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue
                                            .shade800, // Theme consistent
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: primaryThemeColor),
                                    onPressed: selectDoctorOnMap,
                                    tooltip: "Change Doctor",
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDoctorInfo!['specialization'] ?? 'N/A',
                                style: TextStyle(
                                    fontSize: 15, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 10),
                              _buildDetailRow(Icons.business_outlined, "Clinic",
                                  selectedDoctorInfo!['clinicName'] ?? 'N/A'),
                              _buildDetailRow(
                                  Icons.location_on_outlined, "Address",
                                  selectedDoctorInfo!['address'] ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                    if (_formKey.currentState?.validate() == false &&
                        selectedDoctorInfo == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, top: 0),
                        child: Text("Please select a doctor.", style: TextStyle(
                            color: Theme
                                .of(context)
                                .colorScheme
                                .error, fontSize: 12)),
                      ),
                    const SizedBox(height: 10),


                    // Section: Select Patient (If applicable)
                    // ... inside your build method, in the "Select Patient" section:
                    // Section: Select Patient (If applicable)
                    if (patients.isNotEmpty) ...[
                      _buildSectionHeader(
                          "Select Patient*", Icons.person_outline),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        color: cardBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Select a patient profile",
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 15),
                            ),
                            value: selectedPatientId,
                            isExpanded: true,
                            items: patients.map((patient) {
                              return DropdownMenuItem<String>(
                                value: patient['patient_id'] as String?,
                                child: Text(
                                  patient['name'] as String? ??
                                      'Unnamed Patient',
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.black87),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedPatientId = value; // Update the ID of the selected patient
                                if (value != null) {
                                  try {
                                    // No need to cast 'p' as it's already Map<String, dynamic>
                                    // from the `patients` list.
                                    _selectedPatientDetails = patients.firstWhere(
                                          (p) => p['patient_id'] == value,
                                    );
                                  } catch (e) {
                                    // This catch is for StateError if no element satisfies the condition.
                                    _selectedPatientDetails = null;
                                    debugPrint("Patient with ID '$value' not found in the list. Error: $e");
                                  }
                                } else {
                                  _selectedPatientDetails = null; // Clear details if dropdown selection is cleared
                                }

                                // Reset subsequent fields that depend on the patient, date, or time
                                selectedDate = null;
                                selectedTimeRange = null;
                                availableTimeRanges = [];
                                selectedTimeSlot = null; // Clear selected specific time slot string
                                selectedSlotId = null;    // Clear selected slot ID
                                availableSlots = [];      // Clear filtered slots for UI
                                allFetchedSlotsForDate = []; // Clear all slots fetched for a date

                                // Do NOT automatically fetch slots here.
                                // Slot fetching should depend on a valid DOCTOR and DATE.
                                // Changing the patient means the user will likely need to re-select a date.
                              });
                            },
                            validator: (value) {
                              if (value == null && patients.isNotEmpty) {
                                return 'Please select a patient.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      // const SizedBox(height: 10), // Original SizedBox, can be adjusted or removed depending on spacing preference

                      // Display Selected Patient Details Card (conditionally within the same block)
                      if (_selectedPatientDetails != null) ...[
                        // You can add a SizedBox here if you want space between dropdown and details card
                        // const SizedBox(height: 8),
                        // No need for another _buildSectionHeader here if it's part of "Select Patient"
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          // Consistent margin
                          color: cardBackgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Patient Information",
                                  // Title for this card section
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue
                                        .shade800, // Theme consistent
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  Icons.person_outline,
                                  "Name",
                                  _selectedPatientDetails!['name']
                                      ?.toString() ?? 'N/A',
                                ),
                                if (_selectedPatientDetails!['age'] != null)
                                  _buildDetailRow(
                                    Icons.cake_outlined,
                                    "Age",
                                    _selectedPatientDetails!['age']
                                        ?.toString() ?? 'N/A',
                                  ),
                                if (_selectedPatientDetails!['gender'] != null)
                                  _buildDetailRow(
                                    _selectedPatientDetails!['gender']
                                        ?.toString()
                                        .toLowerCase() == 'male'
                                        ? Icons.male_outlined
                                        : _selectedPatientDetails!['gender']
                                        ?.toString()
                                        .toLowerCase() == 'female'
                                        ? Icons.female_outlined
                                        : Icons.transgender_outlined,
                                    "Gender",
                                    _selectedPatientDetails!['gender']
                                        ?.toString() ?? 'N/A',
                                  ),
                                if (_selectedPatientDetails!['email'] != null)
                                  _buildDetailRow(
                                    Icons.email_outlined,
                                    "Email",
                                    _selectedPatientDetails!['email']
                                        ?.toString() ?? 'N/A',
                                  ),
                                if (_selectedPatientDetails!['phone_number'] !=
                                    null)
                                  _buildDetailRow(
                                    Icons.phone_outlined,
                                    "Phone",
                                    _selectedPatientDetails!['phone_number']
                                        ?.toString() ?? 'N/A',
                                  ),
                                // Add other details as needed
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // SizedBox after the entire patient selection block
                    ],

                    // Section: Select Date
                    _buildSectionHeader(
                      "Select Date*",
                      Icons.calendar_today_outlined,
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: (selectedDoctorInfo != null &&
                          (patients.isEmpty || selectedPatientId != null))
                          ? cardBackgroundColor
                          : Colors.grey.shade200,
                      // Visually disable card if prerequisites not met
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: (selectedDoctorInfo != null && (patients
                            .isEmpty || selectedPatientId != null))
                            ? TableCalendar(
                          firstDay: DateTime.utc(now.year - 1, 1, 1),
                          lastDay: DateTime.utc(now.year + 1, 12, 31),
                          focusedDay: selectedDate ?? firstSelectableDate,
                          selectedDayPredicate: (day) =>
                              isSameDay(selectedDate, day),
                          enabledDayPredicate: (DateTime day) {
                            final DateTime dayToCheck = DateTime(
                                day.year, day.month, day.day);
                            return (dayToCheck.isAtSameMomentAs(
                                firstSelectableDate) ||
                                dayToCheck.isAfter(firstSelectableDate)) &&
                                (dayToCheck.isAtSameMomentAs(
                                    lastSelectableDate) ||
                                    dayToCheck.isBefore(lastSelectableDate));
                          },
                          onDaySelected: (newSelectedDay, newFocusedDay) {
                            // No SnackBar for disabled days, relying on enabledDayPredicate
                            setState(() {
                              selectedDate = newSelectedDay;
                              selectedTimeRange = null;
                              availableTimeRanges = [];
                              selectedTimeSlotString =
                              null; // Use new state variable
                              selectedSlotId = null; // Use new state variable
                              availableSlots = [];
                              allFetchedSlotsForDate = [];
                              fetchAvailableSlots();
                            });
                          },
                          calendarStyle: CalendarStyle(
                            selectedDecoration: BoxDecoration(
                                color: primaryThemeColor,
                                shape: BoxShape.circle),
                            todayDecoration: BoxDecoration(
                                color: secondaryThemeColor.withOpacity(0.7),
                                shape: BoxShape.circle),
                            defaultTextStyle: const TextStyle(
                                fontSize: 15, color: Colors.black87),
                            weekendTextStyle: TextStyle(
                                fontSize: 15, color: Colors.red.shade600),
                            outsideTextStyle: TextStyle(
                                fontSize: 15, color: Colors.grey.shade400),
                            disabledTextStyle: TextStyle(
                                fontSize: 15, color: Colors.grey.shade400),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800),
                            leftChevronIcon: Icon(
                                Icons.chevron_left, color: primaryThemeColor),
                            rightChevronIcon: Icon(
                                Icons.chevron_right, color: primaryThemeColor),
                          ),
                        )
                            : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              selectedDoctorInfo == null
                                  ? "Please select a doctor first."
                                  : "Please select a patient first.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Section: Select Time Range
                    _buildSectionHeader(
                        "Select Time Range*", Icons.access_time_outlined),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: selectedDate != null ? cardBackgroundColor : Colors
                          .grey.shade200,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        child: isLoadingTimeRanges && selectedDate != null
                            ? const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: CircularProgressIndicator()))
                            : DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: selectedDate == null
                                ? "Select a date first"
                                : "Select a time period",
                            hintStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 15),
                          ),
                          value: selectedTimeRange,
                          isExpanded: true,
                          items: selectedDate !=
                              null // Only populate items if a date is selected
                              ? availableTimeRanges.map((range) {
                            return DropdownMenuItem<String>(
                              value: range,
                              child: Text(range, style: const TextStyle(
                                  fontSize: 15, color: Colors.black87)),
                            );
                          }).toList()
                              : [],
                          // Empty list if no date selected
                          onChanged: selectedDate !=
                              null // Only enable onChanged if a date is selected
                              ? (value) {
                            setState(() {
                              selectedTimeRange = value;
                              selectedTimeSlotString = null;
                              selectedSlotId = null;
                              availableSlots = [];
                              if (value != null) {
                                _filterSlotsByTimeRange(value);
                              }
                            });
                          }
                              : null,
                          // Disable onChanged
                          validator: (value) {
                            if (selectedDate != null && value == null &&
                                availableTimeRanges.isNotEmpty) {
                              return 'Please select a time range.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    if (selectedDate != null && !isLoadingTimeRanges &&
                        availableTimeRanges.isEmpty &&
                        allFetchedSlotsForDate.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 8.0),
                        child: Text(
                            "All available slots for the day are shown below.",
                            style: TextStyle(color: Colors.grey.shade700,
                                fontSize: 14)),
                      )
                    else
                      if (selectedDate != null && !isLoadingTimeRanges &&
                          availableTimeRanges.isEmpty &&
                          allFetchedSlotsForDate.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 8.0),
                          child: Text("No time ranges available for this date.",
                              style: TextStyle(
                                  color: Colors.orange.shade800, fontSize: 14)),
                        ),
                    const SizedBox(height: 10),

                    // Section: Choose a Slot
                    _buildSectionHeader(
                      "Choose a Slot* ${selectedTimeRange != null &&
                          selectedDate != null
                          ? 'in $selectedTimeRange'
                          : selectedDate != null ? '(Full Day)' : ''}",
                      Icons.watch_later_outlined,
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: (selectedDate != null &&
                          (selectedTimeRange != null ||
                              (availableTimeRanges.isEmpty &&
                                  allFetchedSlotsForDate.isNotEmpty)))
                          ? cardBackgroundColor
                          : Colors.grey.shade200,
                      // Disabled look
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: (selectedDate != null && (selectedTimeRange !=
                            null || (availableTimeRanges.isEmpty &&
                            allFetchedSlotsForDate.isNotEmpty)))
                            ? (availableSlots.isNotEmpty
                            ? FormField<String>(
                          initialValue: selectedSlotId,
                          validator: (value) {
                            if (selectedSlotId == null) {
                              return 'Please select an available time slot.';
                            }
                            return null;
                          },
                          builder: (FormFieldState<String> field) {
                            // --- Logic to build columns ---
                            const int maxItemsPerColumn = 3;
                            List<Widget> columns = [];
                            List<Widget> currentColumnChildren = [];

                            for (int i = 0; i < availableSlots.length; i++) {
                              final slotData = availableSlots[i];
                              final slotTime = slotData['slot_time']
                                  ?.toString() ?? '';
                              final slotIdFromServer = slotData['slot_id']
                                  ?.toString() ?? '';
                              bool isSelected = selectedSlotId ==
                                  slotIdFromServer;
                              String displayTime = 'N/A';
                              if (slotTime.isNotEmpty) {
                                try {
                                  // Assuming slotTime from DB is "HH:mm:ss" or "HH:mm"
                                  final parsedTime = DateFormat("HH:mm:ss")
                                      .parse(
                                      slotTime, true); // Parse the time string
                                  displayTime = DateFormat('HH:mm').format(
                                      parsedTime); // Format it as "HH:mm" (24-hour)
                                } catch (e) {
                                  debugPrint(
                                      "Error parsing slotTime '$slotTime': $e");
                                  // Fallback or handle differently if parsing fails
                                  // For example, try parsing just "HH:mm" if "HH:mm:ss" fails
                                  try {
                                    final parsedTime = DateFormat("HH:mm")
                                        .parse(slotTime, true);
                                    displayTime =
                                        DateFormat('HH:mm').format(parsedTime);
                                  } catch (e2) {
                                    debugPrint(
                                        "Error parsing slotTime '$slotTime' as HH:mm either: $e2");
                                    displayTime =
                                        slotTime; // As a last resort, show original if parsing fails completely
                                  }
                                }
                              }

                              currentColumnChildren.add(
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4.0),
                                  child: ChoiceChip(
                                    label: Text(
                                      displayTime,
                                      // Now uses the 24-hour formatted time
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : primaryThemeColor,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (bool newSelectedState) {
                                      setState(() {
                                        if (newSelectedState) {
                                          selectedTimeSlotString =
                                              slotTime; // Keep original "HH:mm:ss" for DB
                                          selectedSlotId = slotIdFromServer;
                                        } else {
                                          if (selectedSlotId ==
                                              slotIdFromServer) {
                                            selectedTimeSlotString = null;
                                            selectedSlotId = null;
                                          }
                                        }
                                        field.didChange(selectedSlotId);
                                      });
                                    },
                                    backgroundColor: Colors.grey.shade100,
                                    selectedColor: primaryThemeColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6.0),
                                      side: BorderSide(
                                        color: isSelected
                                            ? primaryThemeColor
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0, vertical: 8.0),
                                    materialTapTargetSize: MaterialTapTargetSize
                                        .shrinkWrap,
                                    elevation: isSelected ? 1.0 : 0.0,
                                    pressElevation: 2.0,
                                  ),
                                ),
                              );

                              if (currentColumnChildren.length ==
                                  maxItemsPerColumn ||
                                  i == availableSlots.length - 1) {
                                columns.add(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    mainAxisSize: MainAxisSize.min,
                                    // Important for column width
                                    children: List.from(currentColumnChildren),
                                  ),
                                );
                                currentColumnChildren.clear();
                              }
                            }
                            // --- End of logic to build columns ---

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: columns.map((col) =>
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 12.0),
                                          // Slightly reduced spacing between columns
                                          child: col,
                                        )).toList(),
                                  ),
                                ),
                                if (field.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 12.0, left: 4.0),
                                    // Or any other EdgeInsets you prefer
                                    child: Text(
                                      field.errorText!,
                                      style: TextStyle(
                                        color: Theme
                                            .of(context)
                                            .colorScheme
                                            .error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        )
                            : Center(/* ... UI for when availableSlots is empty ... */
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy_outlined, size: 48,
                                    color: Colors.orange.shade700),
                                const SizedBox(height: 12),
                                Text(
                                  selectedTimeRange != null
                                      ? "No specific slots available in this time period."
                                      : "No slots available for this date/range.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Please try another time range or date.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ))
                            : Center(/* ... UI for when prerequisites (date/range) are not met ... */
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              selectedDate == null
                                  ? "Please select a date first."
                                  : "Please select a time range or check if slots are available.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section: Reason for Visit
                    _buildSectionHeader(
                        "Reason for Visit*", Icons.notes_outlined),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: selectedSlotId != null
                          ? cardBackgroundColor
                          : Colors.grey.shade200,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: TextFormField(
                          controller: reasonController,
                          enabled: selectedSlotId != null,
                          // Enable/disable based on slot selection
                          decoration: InputDecoration(
                            hintText: selectedSlotId != null
                                ? "e.g., Annual Checkup, Flu Symptoms"
                                : "Select a time slot first",
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 15),
                          ),
                          maxLines: 3,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black87),
                          validator: (value) {
                            if (selectedSlotId != null && (value == null || value.trim().isEmpty)) {
                              return 'Please enter the reason for your visit.';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),


                    // Section: Medical Report (Optional)
                    _buildSectionHeader("Medical Report (Optional)",
                        Icons.attach_file_outlined),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: selectedSlotId != null
                          ? cardBackgroundColor
                          : Colors.grey.shade200,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: selectedSlotId != null
                            ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selectedFile != null &&
                                uploadedFileUrl != null) ...[
                              // --- MODIFIED LISTTILE FOR UPLOADED FILE ---
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  // Subtle background
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                      color: Colors.green.shade200, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.insert_drive_file_outlined,
                                            color: Colors.green.shade700,
                                            size: 36),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment
                                                .start,
                                            children: [
                                              Text(
                                                selectedFile!
                                                    .path
                                                    .split('/')
                                                    .last,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Uploaded successfully",
                                                style: TextStyle(fontSize: 12,
                                                    color: Colors.green
                                                        .shade800,
                                                    fontStyle: FontStyle
                                                        .italic),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      // Align buttons to the right
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(Icons.visibility_outlined,
                                              color: primaryThemeColor,
                                              size: 20),
                                          label: Text("View", style: TextStyle(
                                              color: primaryThemeColor)),
                                          onPressed: () {
                                            if (uploadedFileUrl != null) {
                                              openReportFile(
                                                  uploadedFileUrl!); // Ensure this function exists
                                            }
                                          },
                                          style: TextButton.styleFrom(
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 10)),
                                        ),
                                        TextButton.icon(
                                          icon: Icon(Icons.edit_outlined,
                                              color: Colors.orange.shade700,
                                              size: 20),
                                          label: Text("Change",
                                              style: TextStyle(
                                                  color: Colors.orange
                                                      .shade700)),
                                          onPressed: pickFile,
                                          // This will trigger the file picker again
                                          style: TextButton.styleFrom(
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 10)),
                                        ),
                                        TextButton.icon(
                                          icon: Icon(Icons.delete_outline,
                                              color: Colors.red.shade700,
                                              size: 20),
                                          label: Text("Delete",
                                              style: TextStyle(
                                                  color: Colors.red.shade700)),
                                          onPressed: deleteFileFromUIAndStorage,
                                          // Ensure this function exists
                                          style: TextButton.styleFrom(
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 10)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Space after the uploaded file info
                            ] else
                              if (selectedFile != null &&
                                  uploadedFileUrl == null) ...[
                                // --- UI FOR FILE BEING UPLOADED (WITH CANCEL) ---
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(
                                        color: Colors.blue.shade200, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start,
                                          children: [
                                            Text(
                                              selectedFile!
                                                  .path
                                                  .split('/')
                                                  .last,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87),
                                            ),
                                            const SizedBox(height: 2),
                                            Text("Uploading...",
                                                style: TextStyle(fontSize: 12,
                                                    color: Colors.blue
                                                        .shade700)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.cancel_outlined,
                                            color: Colors.orange.shade700),
                                        tooltip: "Cancel Upload",
                                        onPressed: () {
                                          // TODO: Implement cancellation of the actual upload process if it's in progress
                                          // For now, just clears the UI selection
                                          setState(() {
                                            selectedFile = null;
                                            uploadedFileUrl = null;
                                            uploadedFilePath = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                            // --- "UPLOAD REPORT" OR "CHANGE REPORT" BUTTON ---
                            // This button is always visible if a slot is selected,
                            // but its text changes based on whether a file is already uploaded.
                            // If a file is uploaded, this effectively becomes another way to "Change" it.
                            OutlinedButton.icon(
                              icon: Icon(
                                  (selectedFile != null &&
                                      uploadedFileUrl != null) ? Icons
                                      .sync_alt_outlined : Icons.attach_file,
                                  color: primaryThemeColor
                              ),
                              label: Text(
                                (selectedFile != null &&
                                    uploadedFileUrl != null)
                                    ? "Replace Report"
                                    : "Upload Report",
                                style: TextStyle(
                                    color: primaryThemeColor, fontSize: 15),
                              ),
                              onPressed: pickFile,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: primaryThemeColor),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        )
                            : Center( // Placeholder if slot not selected
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "Select a time slot to enable report upload.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Booking Button
                    if (selectedSlotId != null && reasonController.text
                        .trim()
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: ElevatedButton(
                          onPressed: _isBooking ? null : bookAppointment,
                          // Disable while booking
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryThemeColor,
                            // Use your primary theme color
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isBooking
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white)),
                          )
                              : const Text("Book Appointment",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
}