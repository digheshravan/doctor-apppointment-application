import 'package:flutter/material.dart';
import 'package:medi_slot/screens/patient/DoctorClinicsMapPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorDetailsPage extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorDetailsPage({super.key, required this.doctor});

  @override
  State<DoctorDetailsPage> createState() => _DoctorDetailsPageState();
}

class _DoctorDetailsPageState extends State<DoctorDetailsPage> {
  List<Map<String, dynamic>> clinics = [];
  bool isLoadingClinics = true;

  @override
  void initState() {
    super.initState();
    fetchClinics();
  }

  Future<void> fetchClinics() async {
    try {
      final response = await Supabase.instance.client
          .from('clinic_locations')
          .select()
          .eq('doctor_id', widget.doctor['doctor_id']);

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        isLoadingClinics = false;
      });
    } catch (e) {
      debugPrint("Error fetching clinics: $e");
      setState(() => isLoadingClinics = false);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri url =
    Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch Maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.doctor["profiles"] ?? {};
    final doctorName = profile["name"] ?? "Doctor";
    final doctorEmail = profile["email"] ?? "No email";
    final doctorSpecialty =
        widget.doctor["specialization"] ?? "Not available";
    final doctorExperience =
        widget.doctor["years_of_experience"]?.toString() ?? "0";
    final doctorPhone = widget.doctor["phone"] ?? "Not available";
    final doctorGender = widget.doctor["gender"] ?? "Not specified";
    final doctorStatus = widget.doctor["status"] ?? "pending";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Details"),
        backgroundColor: const Color(0xFF2D8CFF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Doctor Photo ---
            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey[200],
                backgroundImage: widget.doctor["image_url"] != null &&
                    widget.doctor["image_url"].isNotEmpty
                    ? NetworkImage(widget.doctor["image_url"])
                    : null,
                child: (widget.doctor["image_url"] == null ||
                    widget.doctor["image_url"].isEmpty)
                    ? Icon(Icons.person, size: 70, color: Colors.grey[400])
                    : null,
              ),
            ),

            const SizedBox(height: 20),

            // --- Doctor Name ---
            Center(
              child: Text(
                doctorName,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // --- Details ---
            Text("Specialization: $doctorSpecialty",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text("Experience: $doctorExperience years",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text("Phone: $doctorPhone", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text("Email: $doctorEmail", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text("Gender: $doctorGender",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text("Status: $doctorStatus",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            // --- Clinics Section ---
            const Text(
              "Clinics",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (isLoadingClinics)
              const Center(child: CircularProgressIndicator())
            else if (clinics.isEmpty)
              const Text("No clinics available")
            else ...[
                // --- View All Clinics on Map Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorClinicsMapPage(clinics: clinics),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text("View All Clinics on Map"),
                  ),
                ),
                const SizedBox(height: 20),

                // --- List of Clinics with Directions Buttons ---
                Column(
                  children: clinics.map((clinic) {
                    final double? lat = clinic["latitude"] != null
                        ? double.tryParse(clinic["latitude"].toString())
                        : null;
                    final double? lng = clinic["longitude"] != null
                        ? double.tryParse(clinic["longitude"].toString())
                        : null;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(clinic["clinic_name"] ?? "Clinic",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(clinic["address"] ?? "No address",
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87)),

                          const SizedBox(height: 10),

                          if (lat != null && lng != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _openMap(lat, lng),
                                icon: const Icon(Icons.directions),
                                label: const Text("Directions"),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            const SizedBox(height: 30),

            // --- Book Appointment Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8CFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "Booking appointment with Dr. $doctorName..."),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  "Book Appointment",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}