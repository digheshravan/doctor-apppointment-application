import 'package:flutter/material.dart';
import 'package:medi_slot/screens/doctor/MapPickerPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditClinicPage extends StatefulWidget {
  final String doctorId; // ✅ Add doctorId property

  const EditClinicPage({
    super.key,
    required this.doctorId, // ✅ Require doctorId when creating this page
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
          'doctor_id': widget.doctorId, // ✅ use widget.doctorId
          'clinic_name': _clinicNameController.text,
          'address': _addressController.text,
          'latitude': _latitude,
          'longitude': _longitude,
        },
        onConflict: 'doctor_id', // ✅ must be a single string
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinic saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving clinic: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Clinic Location')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _clinicNameController,
              decoration: const InputDecoration(labelText: 'Clinic Name'),
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerPage()),
                );

                if (result != null) {
                  setState(() {
                    _latitude = result["lat"];
                    _longitude = result["lng"];
                    _addressController.text = result["address"]; // ✅ autofill address
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Picked: $_latitude, $_longitude")),
                  );
                }
              },
              child: const Text('Pick Location on Map'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveClinic,
              child: const Text('Save Clinic'),
            ),
          ],
        ),
      ),
    );
  }
}
