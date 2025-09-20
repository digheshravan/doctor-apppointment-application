import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DoctorMapPage extends StatefulWidget {
  const DoctorMapPage({super.key});

  @override
  State<DoctorMapPage> createState() => _DoctorMapPageState();
}

class _DoctorMapPageState extends State<DoctorMapPage> {
  late GoogleMapController _mapController;

  // Example doctor data (replace with DB fetch later)
  final List<Map<String, dynamic>> doctors = [
    {
      "id": 1,
      "name": "Dr. Amit Sharma",
      "specialization": "Cardiologist",
      "lat": 19.0760,
      "lng": 72.8777,
      "clinic": "Heart Care Clinic"
    },
    {
      "id": 2,
      "name": "Dr. Priya Mehta",
      "specialization": "Dermatologist",
      "lat": 19.2183,
      "lng": 72.9781,
      "clinic": "Skin & Glow Clinic"
    },
  ];

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadDoctorMarkers();
  }

  void _loadDoctorMarkers() {
    Set<Marker> tempMarkers = {};
    for (var doc in doctors) {
      tempMarkers.add(
        Marker(
          markerId: MarkerId(doc["id"].toString()),
          position: LatLng(doc["lat"], doc["lng"]),
          infoWindow: InfoWindow(title: doc["name"]),
          onTap: () {
            _showDoctorBottomSheet(doc);
          },
        ),
      );
    }
    setState(() {
      _markers = tempMarkers;
    });
  }

  void _showDoctorBottomSheet(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor["name"],
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 5),
              Text("Specialization: ${doctor["specialization"]}"),
              Text("Clinic: ${doctor["clinic"]}"),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF2193b0),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close bottom sheet
                    // Navigate to book appointment page
                    Navigator.pushNamed(context, "/bookAppointment",
                        arguments: doctor);
                  },
                  child: const Text("Book Appointment",
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Doctors"),
        backgroundColor: Colors.teal,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(19.0760, 72.8777), // Mumbai as example
          zoom: 12,
        ),
        markers: _markers,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
