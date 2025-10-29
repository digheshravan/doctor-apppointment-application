import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// Write Prescription Screen for Assistant
// -----------------------------------------------------------------------------
class AssistantWritePrescriptionScreen extends StatefulWidget {
  final Map<String, dynamic> patient; // pass patient info

  const AssistantWritePrescriptionScreen({
    super.key,
    this.patient = const {}, // default empty map
  });

  @override
  State<AssistantWritePrescriptionScreen> createState() =>
      _AssistantWritePrescriptionScreenState();
}

class _AssistantWritePrescriptionScreenState
    extends State<AssistantWritePrescriptionScreen> {
  // Controllers for text fields
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(DateTime.now()));
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _additionalNotesController =
  TextEditingController();
  final TextEditingController _recommendedTestsController =
  TextEditingController();
  final TextEditingController _followUpDateController =
  TextEditingController();

  String? _selectedFrequency;

  // List to hold added medicines
  final List<Map<String, String>> _addedMedicines = [];
  List<Map<String, dynamic>> _todayAppointments = [];
  Map<String, dynamic>? _selectedPatient;
  bool _isLoading = false;
  String? _selectedGender;
  String? _assignedDoctorId;

  @override
  void initState() {
    super.initState();

    _selectedPatient = widget.patient.isNotEmpty ? widget.patient : null;

    // Pre-fill only if patient data was passed
    if (_selectedPatient != null) {
      _patientNameController.text = _selectedPatient!['name'] ?? '';
      _ageController.text = _selectedPatient!['age']?.toString() ?? '';
      _selectedGender = _selectedPatient!['gender'] ?? '';

      if (_selectedPatient!['appointment_id'] != null) {
        _selectedPatient!['appointment_id'] = _selectedPatient!['appointment_id'];
      }
    }

    // Always fetch today's appointments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAssignedDoctorAndAppointments();
    });
  }

  // Function to add a medicine to the list
  void _addMedicine() {
    if (_medicineNameController.text.isNotEmpty &&
        _dosageController.text.isNotEmpty) {
      setState(() {
        _addedMedicines.add({
          "name": _medicineNameController.text,
          "dosage": _dosageController.text,
          "frequency": _selectedFrequency ?? "Daily",
          "duration": _durationController.text,
          "instructions": _instructionsController.text,
        });
        _medicineNameController.clear();
        _dosageController.clear();
        _durationController.clear();
        _instructionsController.clear();
        _selectedFrequency = null;
      });
    }
  }

  Future<void> _fetchAssignedDoctorAndAppointments() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Get assistant's assigned doctor
      final assistantData = await supabase
          .from('assistants')
          .select('assistant_id, assigned_doctor_id')
          .eq('user_id', user.id)
          .single();

      _assignedDoctorId = assistantData['assigned_doctor_id'];

      if (_assignedDoctorId == null) {
        throw Exception('No doctor assigned to this assistant');
      }

      // Get today's date in 'yyyy-MM-dd' format
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch all appointments for assigned doctor today
      final appointments = await supabase
          .from('appointments')
          .select('''
          appointment_id, 
          appointment_date, 
          patients!inner(patient_id, name, age, gender)
        ''')
          .eq('doctor_id', _assignedDoctorId!)
          .eq('appointment_date', today)
          .eq('visit_status', 'active');

      setState(() {
        _todayAppointments = List<Map<String, dynamic>>.from(appointments);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Full error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching appointments: $e')),
      );
    }
  }

  Future<void> _savePrescription() async {
    final supabase = Supabase.instance.client;

    if (_patientNameController.text.isEmpty ||
        _diagnosisController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    // Validate patient selection
    if (_selectedPatient == null || _selectedPatient?['patient_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first')),
      );
      return;
    }

    // Validate assigned doctor
    if (_assignedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No doctor assigned. Cannot save prescription.')),
      );
      return;
    }

    try {
      // Debug print
      print('🔍 Selected Patient: $_selectedPatient');
      print('🔍 Patient ID: ${_selectedPatient?['patient_id']}');
      print('🔍 Appointment ID: ${_selectedPatient?['appointment_id']}');
      print('🔍 Assigned Doctor ID: $_assignedDoctorId');

      // Parse dates properly
      DateTime prescriptionDate = DateTime.now();
      if (_dateController.text.isNotEmpty) {
        try {
          prescriptionDate =
              DateFormat('dd-MM-yyyy').parse(_dateController.text);
        } catch (e) {
          print('Date parse error: $e');
        }
      }

      DateTime? followUpDate;
      if (_followUpDateController.text.isNotEmpty) {
        try {
          followUpDate =
              DateFormat('dd-MM-yyyy').parse(_followUpDateController.text);
        } catch (e) {
          print('Follow-up date parse error: $e');
        }
      }

      // Insert into prescriptions table (using assigned doctor's ID)
      final prescriptionResponse = await supabase.from('prescriptions').insert({
        'doctor_id': _assignedDoctorId, // Using assigned doctor's ID
        'patient_id': _selectedPatient!['patient_id'],
        'appointment_id': _selectedPatient!['appointment_id'],
        'diagnosis': _diagnosisController.text,
        'symptoms': _symptomsController.text,
        'additional_notes': _additionalNotesController.text,
        'recommended_tests': _recommendedTestsController.text,
        'follow_up_date': followUpDate?.toIso8601String().split('T').first,
        'date': prescriptionDate.toIso8601String().split('T').first,
      }).select().single();

      print('✅ Prescription saved: $prescriptionResponse');

      final prescriptionId = prescriptionResponse['prescription_id'];

      // Insert all medicines
      if (_addedMedicines.isNotEmpty) {
        for (var med in _addedMedicines) {
          await supabase.from('prescription_medicines').insert({
            'prescription_id': prescriptionId,
            'name': med['name'],
            'dosage': med['dosage'],
            'frequency': med['frequency'],
            'duration': med['duration'],
            'instructions': med['instructions'],
          });
        }
      }

      // Update visit_status to 'completed' in appointments table
      if (_selectedPatient?['appointment_id'] != null) {
        await supabase
            .from('appointments')
            .update({'visit_status': 'completed'})
            .eq('appointment_id', _selectedPatient!['appointment_id']);

        print('✅ Appointment visit_status updated to completed');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Prescription saved and visit completed!')),
      );

      // Clear form
      _diagnosisController.clear();
      _symptomsController.clear();
      _additionalNotesController.clear();
      _recommendedTestsController.clear();
      _followUpDateController.clear();
      _addedMedicines.clear();
      setState(() {
        _selectedPatient = null;
        _patientNameController.clear();
        _ageController.clear();
        _selectedGender = null;
      });

      // Refresh today's appointments
      await _fetchAssignedDoctorAndAppointments();
    } catch (e) {
      print('❌ Full error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save prescription: $e')),
      );
    }
  }

  // Date picker for prescription date
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _dateController.dispose();
    _diagnosisController.dispose();
    _symptomsController.dispose();
    _medicineNameController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _additionalNotesController.dispose();
    _recommendedTestsController.dispose();
    _followUpDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description_outlined,
                            color: Colors.blue.shade700, size: 36),
                        const SizedBox(height: 8),
                        const Text(
                          "Write Prescription",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Create prescription for assigned doctor",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔹 Patient Information Section
              _buildCard(
                context,
                title: "Patient Information",
                icon: Icons.person_outline_rounded,
                children: [
                  _buildLabel("Patient Name"),
                  _buildDropdownField(
                    _isLoading ? "Loading..." : "Select patient",
                    items: _todayAppointments.map<String>((a) {
                      return a['patients']['name'] ?? 'Unknown';
                    }).toList(),
                    onChanged: (value) {
                      final selected = _todayAppointments.firstWhere(
                            (a) => a['patients']['name'] == value,
                        orElse: () => {},
                      );
                      if (selected.isNotEmpty) {
                        setState(() {
                          _patientNameController.text =
                              selected['patients']['name'] ?? '';
                          _ageController.text =
                              selected['patients']['age']?.toString() ?? '';
                          _selectedGender = selected['patients']['gender'] ?? '';
                          _selectedPatient = {
                            "name": selected['patients']['name'],
                            "age": selected['patients']['age'],
                            "gender": selected['patients']['gender'],
                            "patient_id": selected['patients']['patient_id'],
                            "appointment_id": selected['appointment_id'],
                          };
                        });
                      }
                    },
                    value: _selectedPatient?['name'],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Age"),
                            TextField(
                              controller: _ageController,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: "Age",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Gender"),
                            TextField(
                              controller: TextEditingController(
                                  text: _selectedGender ?? ''),
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: "Select",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Date"),
                  TextField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "dd-MM-yyyy",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // 🔹 Diagnosis & Symptoms Section
              _buildCard(
                context,
                title: "Diagnosis & Symptoms",
                icon: Icons.assignment_outlined,
                children: [
                  _buildLabel("Diagnosis"),
                  _buildTextField(
                    _diagnosisController,
                    hint: "e.g., Common Cold, Hypertension",
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Symptoms"),
                  _buildMultilineTextField(
                    _symptomsController,
                    hint: "Describe symptoms...",
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔹 Add Medicines Section
              _buildCard(
                context,
                title: "Add Medicines",
                icon: Icons.medication_outlined,
                children: [
                  // Display added medicines
                  if (_addedMedicines.isNotEmpty) ...[
                    ..._addedMedicines.map((med) => _AddedMedicineTile(
                      medicine: med,
                      onDelete: () {
                        setState(() {
                          _addedMedicines.remove(med);
                        });
                      },
                    )),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 16),
                  ],

                  _buildLabel("Medicine Name"),
                  _buildTextField(
                    _medicineNameController,
                    hint: "e.g., Paracetamol",
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Dosage"),
                            _buildTextField(
                              _dosageController,
                              hint: "e.g., 500mg",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Frequency"),
                            _buildDropdownField(
                              "Select",
                              items: [
                                "Daily",
                                "Twice a day",
                                "Thrice a day",
                                "As needed"
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedFrequency = value),
                              value: _selectedFrequency,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Duration"),
                  _buildTextField(
                    _durationController,
                    hint: "e.g., 5 days",
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Instructions"),
                  _buildMultilineTextField(
                    _instructionsController,
                    hint: "e.g., After meals",
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add, color: Colors.blue),
                    label: const Text(
                      "Add Medicine",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔹 Additional Notes Section
              _buildCard(
                context,
                title: "Additional Notes",
                icon: Icons.notes_outlined,
                children: [
                  _buildMultilineTextField(
                    _additionalNotesController,
                    hint: "Any additional instructions or notes...",
                    minLines: 4,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔹 Tests & Follow-up Section
              _buildCard(
                context,
                title: "Tests & Follow-up",
                icon: Icons.assignment_turned_in_outlined,
                children: [
                  _buildLabel("Recommended Tests"),
                  _buildMultilineTextField(
                    _recommendedTestsController,
                    hint: "e.g., Blood test, X-ray...",
                    minLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Follow-up Date"),
                  _buildDateField(
                    context,
                    _followUpDateController,
                    hint: "dd-mm-yyyy",
                    onTap: () => _selectDate(context, _followUpDateController),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 🔹 Action Buttons: Preview & Save Prescription
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Handle Preview action
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(
                            color: Colors.blue.shade700, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "Preview",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _savePrescription,
                      icon: const Icon(Icons.save_outlined,
                          color: Colors.white, size: 20),
                      label: const Text(
                        "Save Prescription",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80), // Extra space for nav bar
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for form elements ---

  Widget _buildCard(BuildContext context,
      {required String title,
        required IconData icon,
        required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller,
      {String hint = "", TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildMultilineTextField(TextEditingController controller,
      {String hint = "", int minLines = 2, int maxLines = 5}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField(
      String hint, {
        required List<String> items,
        Function(String?)? onChanged,
        String? value,
      }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
      onChanged: onChanged,
      items: items
          .map((String item) => DropdownMenuItem<String>(
        value: item,
        child: Text(item),
      ))
          .toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDateField(
      BuildContext context,
      TextEditingController controller, {
        required String hint,
        required VoidCallback onTap,
      }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        suffixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Display for Added Medicines
// -----------------------------------------------------------------------------
class _AddedMedicineTile extends StatelessWidget {
  final Map<String, String> medicine;
  final VoidCallback onDelete;

  const _AddedMedicineTile({
    required this.medicine,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${medicine['dosage'] ?? ''} - ${medicine['frequency'] ?? ''} (${medicine['duration'] ?? ''})",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (medicine['instructions'] != null &&
                    medicine['instructions']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Instructions: ${medicine['instructions']}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.blue.shade800, size: 20),
            onPressed: onDelete,
            tooltip: "Remove medicine",
          ),
        ],
      ),
    );
  }
}