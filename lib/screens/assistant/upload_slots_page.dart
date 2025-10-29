import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class UploadSlotsPage extends StatefulWidget {
  final String doctorId;
  final String? assistantId;

  const UploadSlotsPage({
    super.key,
    required this.doctorId,
    this.assistantId,
  });

  @override
  State<UploadSlotsPage> createState() => _UploadSlotsPageState();
}

class _UploadSlotsPageState extends State<UploadSlotsPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _duration = 10; // This is controlled by the dropdown

  bool _isViewingSlots = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _slots = [];

  // --- UI Colors from CheckInScreen Theme ---
  static const Color primaryColor = Color(0xFF00AEEF); // Main blue
  static const Color primaryVariant = Color(0xFF00B0F0); // Lighter blue
  static const Color accentColor = Color(0xFF4CAF50); // Green
  static const Color backgroundColor = Color(0xFFF8F9FA); // Off-white
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  // Re-added inactiveTabColor as it's used in InputDecoration
  static const Color inactiveTabColor = Color(0xFFF0F4F8);
  // --- End Theme Colors ---


  // --- BACKEND LOGIC (Unchanged) ---
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _uploadSlots() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all date and time fields.")),
      );
      return;
    }


    if (widget.doctorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Doctor ID is missing")),
      );
      return;
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    final existingSlots = await supabase
        .from('appointment_slots')
        .select('slot_id')
        .eq('doctor_id', widget.doctorId)
        .eq('slot_date', DateFormat('yyyy-MM-dd').format(_selectedDate!));

    if (existingSlots.isNotEmpty) {
      if (!mounted) return; // Add mounted check before showing dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Slots Already Exist"),
          content: const Text("Slots for this date are already present."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    List<DateTime> slotTimes = [];
    DateTime slotTime = startDateTime;
    while (slotTime.isBefore(endDateTime)) {
      slotTimes.add(slotTime);
      slotTime = slotTime.add(Duration(minutes: _duration));
    }

    if (slotTimes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No slots generated. Check your time range.")),
      );
      return;
    }

    // Indicate loading
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> slotsToInsert = [];
      for (var dt in slotTimes) {
        final data = <String, dynamic>{
          'doctor_id': widget.doctorId,
          'slot_date': dt.toIso8601String().split('T').first,
          'slot_time': '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00',
          'slot_limit': 1,
          'booked_count': 0,
          'status': 'open',
        };
        if (widget.assistantId != null && widget.assistantId!.isNotEmpty) {
          data['assistant_id'] = widget.assistantId!;
        }
        slotsToInsert.add(data);
      }

      // Perform batch insert
      await supabase.from('appointment_slots').insert(slotsToInsert);


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${slotTimes.length} slots uploaded successfully ✅")),
      );
      // Clear form after successful upload
      setState(() {
        _selectedDate = null;
        _startTime = null;
        _endTime = null;
        _duration = 10; // Reset duration
      });
      _formKey.currentState?.reset(); // Reset form state


    } catch (e) {
      debugPrint("Error uploading slots: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading slots: ${e.toString()}")), // Use toString() for better error message
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Stop loading indicator
      }
    }
  }


  Future<void> _fetchSlots() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date first")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    try {
      final response = await supabase
          .from('appointment_slots')
          .select('slot_id, slot_time, status, slot_limit, booked_count')
          .eq('doctor_id', widget.doctorId)
          .eq('slot_date', dateStr)
          .order('slot_time', ascending: true);

      // Handle potential errors (response might not be a list)
      if (response is List) {
        setState(() {
          _slots = response
              .map<Map<String, dynamic>>((slot) => {
            'id': slot['slot_id'],
            'time': slot['slot_time'] ?? 'N/A',
            'status': slot['status'] ?? 'open',
            'limit': slot['slot_limit'] ?? 1,
            'booked': slot['booked_count'] ?? 0,
          })
              .toList();
        });
        if (_slots.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No slots found for this date.")),
          );
        }
      } else {
        // Handle unexpected response format
        throw Exception('Unexpected response format from Supabase');
      }

    } catch (e) {
      debugPrint("Error fetching slots: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching slots: ${e.toString()}")),
        );
        setState(() { _slots = []; }); // Clear slots on error
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // --- END OF BACKEND LOGIC ---

  @override
  Widget build(BuildContext context) {
    // --- Applied Scaffold and AppBar from CheckInScreen ---
    return Scaffold(
      backgroundColor: backgroundColor, // Use theme color
      appBar: AppBar(                 // Use the consistent AppBar style
        backgroundColor: backgroundColor,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.access_time_outlined,
                  color: primaryColor, size: 30),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Appointment Slots', // Title specific to this screen
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Manage doctor availability', // Subtitle specific to this screen
                  style: TextStyle(
                    color: lightTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // --- End AppBar ---

      body: Column(
        children: [
          _buildActionTabs(),
          Expanded(
            child: _isViewingSlots
                ? _buildSlotsList()
                : _buildFormCard(), // Removed SingleChildScrollView here, added RefreshIndicator inside
          ),
        ],
      ),
    );
  }


  Widget _buildSlotsList() {
    return Column(
      children: [
        // Date picker row at top
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white, // Use white for card-like elements
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1), // Softer shadow
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                              : 'Select Date',
                          style: const TextStyle(
                            fontSize: 16,
                            color: textColor, // Use theme color
                          ),
                        ),
                        const Icon(Icons.calendar_today, color: primaryColor), // Use theme color
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchSlots, // Disable button while loading
                icon: _isLoading
                    ? Container( // Show spinner in button
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.search, color: Colors.white),
                label: const Text("View"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor, // Use theme color
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Slot List below
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchSlots,
            color: primaryColor, // Use theme color for indicator
            child: _isLoading && _slots.isEmpty // Show shimmer only if list is empty initially
                ? _buildShimmerSlotList() // Use shimmer list
                : !_isLoading && _slots.isEmpty
                ? ListView( // Allows pull-to-refresh on empty list
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2), // Center message vertically
                const Center(child: Text("No slots found. Pull down to refresh.")),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16,0,16,16), // Adjusted padding
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                // Format time properly
                String formattedTime = 'N/A';
                try {
                  formattedTime = DateFormat('hh:mm a').format(DateFormat('HH:mm:ss').parse(slot['time']));
                } catch (e) {
                  debugPrint("Error formatting time: ${slot['time']} - $e");
                }
                final status = slot['status'];
                final booked = slot['booked'];
                final limit = slot['limit'];

                return Card(
                  elevation: 1, // Reduced elevation
                  color: Colors.white, // Standard card color
                  shadowColor: Colors.black.withOpacity(0.04), // Softer shadow
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200) // Subtle border
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.1), // Use theme color
                      child: const Icon(Icons.access_time,
                          color: primaryColor), // Use theme color
                    ),
                    title: Text("Time: $formattedTime"), // Use formatted time
                    subtitle: Text("Status: ${status.toUpperCase()}\nBooked: $booked / $limit"),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent), // Outline icon
                      onPressed: () async {
                        // Keep delete confirmation dialog
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Delete Slot"),
                            content: const Text("Are you sure you want to delete this slot?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel")),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ) ?? false; // Default to false if dialog dismissed

                        if (confirm) {
                          try {
                            await supabase
                                .from('appointment_slots')
                                .delete()
                                .eq('slot_id', slot['id']);
                            // Update UI immediately
                            setState(() {
                              _slots.removeAt(index);
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Slot deleted successfully ✅")),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error deleting slot: $e")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the "Add New Slot" and "View Slots" buttons
  Widget _buildActionTabs() {
    // Apply consistent styling based on selection
    final addButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: !_isViewingSlots ? accentColor : inactiveTabColor,
      foregroundColor: !_isViewingSlots ? Colors.white : textColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: _isViewingSlots ? 0 : 2, // Only elevate the active tab slightly
    );
    final viewButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: _isViewingSlots ? accentColor : inactiveTabColor,
      foregroundColor: _isViewingSlots ? Colors.white : textColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: _isViewingSlots ? 2 : 0, // Only elevate the active tab slightly
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.add, color: !_isViewingSlots ? Colors.white : textColor),
              label: const Text('Add New Slot'),
              onPressed: () {
                if (_isViewingSlots) { // Only change state if needed
                  setState(() => _isViewingSlots = false);
                }
              },
              style: addButtonStyle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.calendar_today_outlined, color: _isViewingSlots ? Colors.white : textColor),
              label: const Text('View Slots'),
              onPressed: () {
                if (!_isViewingSlots) { // Only change state if needed
                  setState(() {
                    _isViewingSlots = true;
                    // Optionally clear date/slots when switching to view
                    _slots.clear();
                    _selectedDate = null;
                  });
                }
              },
              style: viewButtonStyle,
            ),
          ),
        ],
      ),
    );
  }


  /// Builds the white card containing the form
  Widget _buildFormCard() {
    // Wrap the form content in RefreshIndicator
    return RefreshIndicator(
      onRefresh: () async {
        // Optionally add a refresh action here, e.g., clear form
        setState(() {
          _selectedDate = null;
          _startTime = null;
          _endTime = null;
          _duration = 10;
        });
        _formKey.currentState?.reset();
        // Simulate delay or fetch related data if needed
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: primaryColor, // Use theme color
      child: SingleChildScrollView( // Ensure content scrolls if needed
        physics: const AlwaysScrollableScrollPhysics(), // Allow scrolling for refresh
        padding: const EdgeInsets.all(16.0), // Padding applied here
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white, // Use theme color
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05), // Softer shadow
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create New Slot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor, // Use theme color
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel('Date'),
                _buildDateTextField(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Start Time'),
                          _buildTimeTextField(isStart: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('End Time'),
                          _buildTimeTextField(isStart: false),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Slot Duration'),
                _buildDurationDropdown(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: _isLoading
                      ? Container( // Show spinner in button
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: const Text(
                    'Create Slot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isLoading ? null : _uploadSlots, // Disable button while loading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor, // Use theme color
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Shimmer Widget for Slot List ---
  Widget _buildShimmerSlotList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6, // Show several shimmer placeholders
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Card(
          elevation: 1,
          color: Colors.white,
          shadowColor: Colors.black.withOpacity(0.04),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200)
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              radius: 24,
            ),
            title: Container(height: 16, width: 100, color: Colors.grey.shade300),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(height: 12, width: 150, color: Colors.grey.shade300),
                const SizedBox(height: 4),
                Container(height: 12, width: 80, color: Colors.grey.shade300),
              ],
            ),
            isThreeLine: true,
          ),
        ),
      ),
    );
  }

  // --- Other Helper Widgets (Unchanged but using theme colors) ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: textColor, // Use theme color
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDateTextField() {
    final controller = TextEditingController(
      text: _selectedDate != null
          ? DateFormat('dd-MM-yyyy').format(_selectedDate!)
          : '',
    );

    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: _pickDate,
      decoration: _inputDecoration('dd-mm-yyyy', Icons.calendar_today_outlined),
      validator: (value) =>
      _selectedDate == null ? 'Please select a date' : null,
    );
  }

  Widget _buildTimeTextField({required bool isStart}) {
    final time = isStart ? _startTime : _endTime;
    final controller = TextEditingController(
      text: time != null ? time.format(context) : '',
    );

    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickTime(isStart),
      decoration: _inputDecoration('--:--', Icons.access_time_outlined),
      validator: (value) {
        if (time == null) {
          return isStart ? 'Set start time' : 'Set end time';
        }
        return null;
      },
    );
  }

  Widget _buildDurationDropdown() {
    return DropdownButtonFormField<int>(
      value: _duration,
      decoration: _inputDecoration(null, null, isDropdown: true),
      items: const [
        DropdownMenuItem(value: 5, child: Text("5 minutes")),
        DropdownMenuItem(value: 10, child: Text("10 minutes")),
        DropdownMenuItem(value: 15, child: Text("15 minutes")),
        DropdownMenuItem(value: 20, child: Text("20 minutes")),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _duration = val);
      },
      validator: (value) =>
      value == null ? 'Please set a duration' : null,
    );
  }

  InputDecoration _inputDecoration(String? hint, IconData? icon,
      {bool isDropdown = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: lightTextColor), // Use theme color
      suffixIcon: isDropdown
          ? null
          : Icon(icon, color: lightTextColor), // Use theme color
      filled: true,
      fillColor: inactiveTabColor, // Use theme color (check if this name is still appropriate)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}