import 'package:flutter/material.dart';
import 'package:medi_slot/screens/doctor/MapPickerPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditClinicPage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> clinicData;

  const EditClinicPage({
    super.key,
    required this.doctorId,
    required this.clinicData,
  });

  @override
  State<EditClinicPage> createState() => _EditClinicPageState();
}

class _EditClinicPageState extends State<EditClinicPage> {
  final _clinicNameController = TextEditingController();
  final _addressController = TextEditingController();
  double? _latitude;
  double? _longitude;

  final supabase = Supabase.instance.client;

  // Assistants data
  List<Map<String, dynamic>> assistants = [];
  List<String> selectedAssistantIds = [];

  @override
  void initState() {
    super.initState();
    _clinicNameController.text = widget.clinicData['clinic_name'] ?? '';
    _addressController.text = widget.clinicData['address'] ?? '';
    _latitude = widget.clinicData['latitude'];
    _longitude = widget.clinicData['longitude'];

    fetchAssistants();
  }

  Future<void> fetchAssistants() async {
    try {
      // Fetch all assistants of the doctor
      final response = await supabase
          .from('assistants')
          .select('assistant_id, profiles(name)')
          .eq('assigned_doctor_id', widget.doctorId);

      setState(() {
        assistants = List<Map<String, dynamic>>.from(response);
      });

      // Fetch assistants already assigned to this clinic
      if (widget.clinicData['clinic_id'] != null) {
        final assigned = await supabase
            .from('clinic_assistants')
            .select('assistant_id')
            .eq('clinic_id', widget.clinicData['clinic_id'].toString());

        setState(() {
          selectedAssistantIds = List<Map<String, dynamic>>.from(assigned)
              .map((a) => a['assistant_id'].toString())
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error loading assistants: $e")),
      );
    }
  }

  Future<void> _saveClinic() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a location on the map!')),
      );
      return;
    }

    try {
      // Build clinic data
      final clinicData = {
        'doctor_id': widget.doctorId,
        'clinic_name': _clinicNameController.text,
        'address': _addressController.text,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      if (widget.clinicData['clinic_id'] != null) {
        clinicData['clinic_id'] = widget.clinicData['clinic_id'].toString();
      }

      // Upsert clinic
      final clinic = await supabase
          .from('clinic_locations')
          .upsert(clinicData, onConflict: 'clinic_id')
          .select()
          .single();

      final clinicId = clinic['clinic_id'].toString();

      // Upsert assigned assistants (id is auto-generated in DB)
      if (selectedAssistantIds.isNotEmpty) {
        final data = selectedAssistantIds
            .map((assistantId) => {
          'clinic_id': clinicId,
          'assistant_id': assistantId.toString(),
        })
            .toList();

        await supabase.from('clinic_assistants').upsert(
          data,
          onConflict: 'clinic_id,assistant_id', // unique constraint
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Clinic details updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error saving clinic: $e')),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.teal),
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
          "Edit Clinic",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              controller: _clinicNameController,
              label: "Clinic Name",
              icon: Icons.local_hospital,
            ),
            _buildTextField(
              controller: _addressController,
              label: "Address",
              icon: Icons.location_on,
            ),
            // Assistants Multi-Select
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: const Text("Assign Assistants"),
                leading: const Icon(Icons.people, color: Colors.teal),
                children: assistants.map((a) {
                  final id = a['assistant_id'].toString();
                  final name = a['profiles']?['name'] ?? "Unnamed";
                  return CheckboxListTile(
                    title: Text(name),
                    value: selectedAssistantIds.contains(id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedAssistantIds.add(id);
                        } else {
                          selectedAssistantIds.remove(id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text(
                "Pick Location on Map",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerPage()),
                );

                if (result != null) {
                  setState(() {
                    _latitude = result["lat"];
                    _longitude = result["lng"];
                    _addressController.text = result["address"];
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("📍 Picked: $_latitude, $_longitude")),
                  );
                }
              },
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "Save Clinic",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                onPressed: _saveClinic,
              ),
            )
          ],
        ),
      ),
    );
  }
}
