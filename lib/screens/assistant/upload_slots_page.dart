import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _duration = 10;

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

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    // Generate slots in 10 minute intervals
    List<DateTime> slotTimes = [];
    DateTime slotTime = startDateTime;

    while (slotTime.isBefore(endDateTime)) {
      slotTimes.add(slotTime);
      slotTime = slotTime.add(Duration(minutes: _duration)); // _duration = 10
    }

    try {
      for (var dt in slotTimes) {
        final data = <String, Object>{
          'doctor_id': widget.doctorId,
          'slot_date': dt.toIso8601String().split('T').first,
          'slot_time':
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00',
          'slot_limit': 1,
          'booked_count': 0,
          'status': 'open',
        };

        if (widget.assistantId != null) {
          data['assistant_id'] = widget.assistantId!;
        }

        await supabase.from('appointment_slots').insert([data]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Slots uploaded successfully ✅")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading slots: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
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
        title: const Text("Upload Slots", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 6,
      ),
      body: Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                margin: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Set Appointment Slots",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2193b0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // Date picker
                        TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Select Date",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _pickDate,
                            ),
                          ),
                          controller: TextEditingController(
                            text: _selectedDate != null
                                ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                                : "",
                          ),
                          validator: (_) => _selectedDate == null ? "Please select a date" : null,
                        ),
                        const SizedBox(height: 20),

                        // Start time picker
                        TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Start Time",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time),
                              onPressed: () => _pickTime(true),
                            ),
                          ),
                          controller: TextEditingController(text: _startTime?.format(context) ?? ""),
                          validator: (_) => _startTime == null ? "Please select start time" : null,
                        ),
                        const SizedBox(height: 20),

                        // End time picker
                        TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "End Time",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time),
                              onPressed: () => _pickTime(false),
                            ),
                          ),
                          controller: TextEditingController(text: _endTime?.format(context) ?? ""),
                          validator: (_) => _endTime == null ? "Please select end time" : null,
                        ),
                        const SizedBox(height: 20),

                        // Duration dropdown
                        DropdownButtonFormField<int>(
                          value: _duration,
                          decoration: InputDecoration(
                            labelText: "Slot Duration",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 5, child: Text("5 minutes")),
                            DropdownMenuItem(value: 10, child: Text("10 minutes")),
                            DropdownMenuItem(value: 15, child: Text("15 minutes")),
                            DropdownMenuItem(value: 20, child: Text("20 minutes")),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _duration = val);
                          },
                        ),
                        const SizedBox(height: 30),

                        // Upload button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: const Color(0xFF2193b0),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _uploadSlots,
                          child: const Text("Upload Slots"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
