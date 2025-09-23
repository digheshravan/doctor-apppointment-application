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
          .select()
          .eq('doctor_id', widget.doctorId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          clinics = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching clinics: $e");
      if (mounted) {
        setState(() => isLoading = false);
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
          // clinicData is empty, so EditClinicPage will be in "add" mode
        ),
      ),
    );
    // Refresh list after potentially adding a new one
    fetchClinics();
  }

  void goToEditClinic(Map<String, dynamic> clinic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditClinicPage(
          doctorId: widget.doctorId,
          clinicData: clinic, // ✅ pass existing clinic details
        ),
      ),
    );

    // Refresh clinic list after editing
    fetchClinics();
  }

  Future<void> _deleteClinic(int clinicId) async {
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
      // Refresh the list
      fetchClinics();
    } catch (e) {
      debugPrint("Error deleting clinic: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting clinic: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
        title: const Text(
          "Manage Clinics",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(100.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: FloatingActionButton.extended(
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            highlightElevation: 0.0,
            onPressed: goToAddClinic,
            label: const Text('Add Clinic',
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.add, color: Colors.white),
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
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.local_hospital,
                      color: Colors.teal),
                  title:
                  Text(clinic['clinic_name'] ?? "Unnamed Clinic"),
                  subtitle: Text(clinic['address'] ?? "No address"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue),
                        onPressed: () => goToEditClinic(clinic),
                        tooltip: 'Edit Clinic',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.redAccent),
                        onPressed: () =>
                            _deleteClinic(clinic['clinic_id']),
                        tooltip: 'Delete Clinic',
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