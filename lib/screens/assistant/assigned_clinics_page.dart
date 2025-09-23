import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignedClinicsPage extends StatefulWidget {
  final String assistantId;

  const AssignedClinicsPage({super.key, required this.assistantId});

  @override
  State<AssignedClinicsPage> createState() => _AssignedClinicsPageState();
}

class _AssignedClinicsPageState extends State<AssignedClinicsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> assignedClinics = [];

  @override
  void initState() {
    super.initState();
    fetchAssignedClinics();
  }

  /// Fetch clinics assigned to this assistant
  Future<void> fetchAssignedClinics() async {
    try {
      final data = await Supabase.instance.client
          .from('clinic_assistants')
          .select('''
            clinic_id,
            clinic_locations(
              clinic_id,
              clinic_name,
              address,
              doctor_id,
              doctors!inner(
                doctor_id,
                user_id,
                profiles!inner(name)
              )
            )
          ''')
          .eq('assistant_id', widget.assistantId);

      final clinics = (data as List).map<Map<String, dynamic>>((ca) {
        final clinic = ca['clinic_locations'];
        final doctorProfile = clinic['doctors']?['profiles'];

        return {
          'clinic_id': clinic['clinic_id'],
          'clinic_name': clinic['clinic_name'] ?? 'Unnamed Clinic',
          'address': clinic['address'] ?? 'No address',
          'doctor_name': doctorProfile?['name'] ?? 'Unknown Doctor',
        };
      }).toList();

      if (mounted) {
        setState(() {
          assignedClinics = clinics;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assigned clinics: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Clinics"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignedClinics.isEmpty
          ? const Center(
        child: Text(
          "No clinics assigned.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: assignedClinics.length,
        itemBuilder: (context, index) {
          final clinic = assignedClinics[index];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.transparent,
                    backgroundImage:
                    const AssetImage('assets/icon/doctor_marker.png'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clinic['clinic_name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                clinic['address'],
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Dr. ${clinic['doctor_name']}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
