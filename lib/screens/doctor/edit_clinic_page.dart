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

  @override
  void initState() {
    super.initState();
    // Pre-fill fields with existing data
    _clinicNameController.text = widget.clinicData['clinic_name'] ?? '';
    _addressController.text = widget.clinicData['address'] ?? '';
    _latitude = widget.clinicData['latitude'];
    _longitude = widget.clinicData['longitude'];
  }

  Future<void> _saveClinic() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a location on the map!')),
      );
      return;
    }

    try {
      await supabase.from('clinic_locations').upsert(
        {
          'id': widget.clinicData['id'], // keep id if updating
          'doctor_id': widget.doctorId,
          'clinic_name': _clinicNameController.text,
          'address': _addressController.text,
          'latitude': _latitude,
          'longitude': _longitude,
        },
        onConflict: 'id',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Clinic details updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error saving clinic: $e')),
      );
    }
  }

  Widget _buildTextField(
      {required TextEditingController controller,
        required String label,
        required IconData icon}) {
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
                icon: Icons.local_hospital),
            _buildTextField(
                controller: _addressController,
                label: "Address",
                icon: Icons.location_on),
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
                        content:
                        Text("📍 Picked: $_latitude, $_longitude")),
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
                  backgroundColor: Colors.transparent, // transparent to show gradient
                  shadowColor: Colors.transparent,     // remove shadow to look clean
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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