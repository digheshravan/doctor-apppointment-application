import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/auth_service.dart';
import 'edit_clinic_page.dart';

class ManageClinicsPage extends StatefulWidget {
  final String doctorId;

  const ManageClinicsPage({super.key, required this.doctorId});

  @override
  State<ManageClinicsPage> createState() => _ManageClinicsPageState();
}

class _ManageClinicsPageState extends State<ManageClinicsPage> {
  final authService = AuthService();
  bool isLoading = true;
  List<Map<String, dynamic>> clinics = [];

  @override
  void initState() {
    super.initState();
    fetchClinics();
  }

  Future<void> fetchClinics() async {
    try {
      final response = await Supabase.instance.client
          .from('clinic_locations')
          .select(
          'clinic_id, clinic_name, address, latitude, longitude, doctor_id')
          .eq('doctor_id', widget.doctorId);

      if (mounted) {
        setState(() {
          clinics = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load clinics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void goToAddClinic() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditClinicPage(
          doctorId: widget.doctorId,
          clinicData: const {},
        ),
      ),
    );
    fetchClinics();
  }

  void goToEditClinic(Map<String, dynamic> clinic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditClinicPage(
          doctorId: widget.doctorId,
          clinicData: clinic,
        ),
      ),
    );
    fetchClinics();
  }

  Future<void> _deleteClinic(String clinicId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Clinic'),
        content: const Text(
            'Are you sure you want to delete this clinic? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('clinic_locations')
          .delete()
          .eq('clinic_id', clinicId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clinic deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      fetchClinics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting clinic: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Fetch assistants assigned to a clinic
  Future<List<Map<String, dynamic>>> fetchAssignedAssistants(
      String clinicId) async {
    try {
      final assigned = await Supabase.instance.client
          .from('clinic_assistants')
          .select('assistant_id')
          .eq('clinic_id', clinicId);

      final assistantIds =
      List<String>.from(assigned.map((a) => a['assistant_id'].toString()));

      if (assistantIds.isEmpty) return [];

      final assistants = await Supabase.instance.client
          .from('assistants')
          .select('assistant_id, profiles(name)')
          .filter('assistant_id', 'in', assistantIds);

      return List<Map<String, dynamic>>.from(assistants);
    } catch (e) {
      debugPrint("Error fetching assistants: $e");
      return [];
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
        title: const Text(
          "Manage Clinics",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: goToAddClinic,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add Clinic',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchClinics,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : clinics.isEmpty
              ? const Center(
            child: Text(
              "No clinics linked yet. Tap 'Add Clinic' to start.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          )
              : ListView.builder(
            itemCount: clinics.length,
            itemBuilder: (context, index) {
              final clinic = clinics[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    title: Row(
                      children: [
                        // Small logo
                        Image.asset(
                          'assets/icon/doctor_marker.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        // Flexible instead of Expanded, with overflow handling
                        Flexible(
                          child: Text(
                            clinic['clinic_name'] ?? "Unnamed Clinic",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    children: [
                      // Address
                      // Address
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              clinic['address'] ?? "No address",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white, // Changed from white70 to white
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
// Assigned assistants
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: fetchAssignedAssistants(clinic['clinic_id']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Text(
                              'Error loading assistants',
                              style: TextStyle(color: Colors.red),
                            );
                          }
                          final assistants = snapshot.data ?? [];
                          if (assistants.isEmpty) {
                            return const Text(
                              'No assistants assigned',
                              style: TextStyle(color: Colors.white),
                            ); // Changed color here
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: assistants.map((a) {
                              return Row(
                                children: [
                                  const Icon(Icons.person, size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    a['profiles']?['name'] ?? "Unnamed",
                                    style: const TextStyle(color: Colors.white), // Changed color
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Edit & Delete buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => goToEditClinic(clinic),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade400,
                            ),
                            onPressed: () =>
                                _deleteClinic(clinic['clinic_id']),
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
