import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({Key? key}) : super(key: key);

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> patients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPatients();
  }

  Future<void> fetchPatients() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    await Future.delayed(const Duration(milliseconds: 800)); // shimmer effect

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      final response =
      await supabase.from('patients').select().eq('user_id', user.id);

      if (mounted) {
        setState(() {
          patients = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching profiles: $e")),
        );
      }
    }
  }

  Future<void> addOrEditPatient({Map? patient}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: patient?['name'] ?? '');
    final ageController =
    TextEditingController(text: patient?['age']?.toString() ?? '');
    String? selectedGender = patient?['gender'];
    String? selectedRelation = patient?['relation'];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(patient == null ? "Add Profile" : "Edit Profile"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: "Name", border: OutlineInputBorder()),
                  validator: (val) =>
                  val == null || val.isEmpty ? "Enter name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ageController,
                  decoration: const InputDecoration(
                      labelText: "Age", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                  val == null || val.isEmpty ? "Enter age" : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                  ],
                  onChanged: (val) => selectedGender = val,
                  validator: (val) => val == null ? "Select gender" : null,
                  decoration: const InputDecoration(
                      labelText: "Gender", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRelation,
                  items: const [
                    DropdownMenuItem(value: "Self", child: Text("Self")),
                    DropdownMenuItem(value: "Father", child: Text("Father")),
                    DropdownMenuItem(value: "Mother", child: Text("Mother")),
                    DropdownMenuItem(value: "Son", child: Text("Son")),
                    DropdownMenuItem(value: "Daughter", child: Text("Daughter")),
                    DropdownMenuItem(value: "Brother", child: Text("Brother")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                  ],
                  onChanged: (val) => selectedRelation = val,
                  validator: (val) => val == null ? "Select relation" : null,
                  decoration: const InputDecoration(
                      labelText: "Relation", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text(patient == null ? "Add" : "Save"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D8CFF),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final user = supabase.auth.currentUser;
                if (user == null) throw "Not logged in";

                if (patient == null) {
                  await supabase.from('patients').insert({
                    'user_id': user.id,
                    'name': nameController.text.trim(),
                    'age': int.tryParse(ageController.text.trim()),
                    'gender': selectedGender,
                    'relation': selectedRelation,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile added successfully")));
                } else {
                  await supabase.from('patients').update({
                    'name': nameController.text.trim(),
                    'age': int.tryParse(ageController.text.trim()),
                    'gender': selectedGender,
                    'relation': selectedRelation,
                  }).eq('patient_id', patient['patient_id']);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile updated successfully")));
                }

                Navigator.pop(context);
                await fetchPatients();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> deletePatient(String patientId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
            "Are you sure you want to delete this profile? This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('patients').delete().eq('patient_id', patientId);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile deleted successfully")));
      await fetchPatients();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error deleting profile: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Text(
                "Family Profiles",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? _buildShimmerList()
                  : patients.isEmpty
                  ? const Center(child: Text("No profiles found"))
                  : RefreshIndicator(
                onRefresh: fetchPatients,
                color: const Color(0xFF2D8CFF),
                child: ListView.builder(
                  padding: EdgeInsets.only(
                      top: 0,
                      bottom: MediaQuery.of(context).padding.bottom +
                          110),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return _PatientCard(
                      patient: patient,
                      onEdit: () => addOrEditPatient(patient: patient),
                      onDelete: () =>
                          deletePatient(patient['patient_id']),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addOrEditPatient(),
        label: const Text("Add Profile"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2D8CFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (_, __) => const _ShimmerPatientCard(),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PatientCard({
    required this.patient,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _getRelationIcon(String? relation) {
    switch (relation?.toLowerCase()) {
      case 'self':
        return Icons.person_outline;
      case 'father':
        return Icons.man_outlined;
      case 'mother':
        return Icons.woman_outlined;
      case 'son':
      case 'daughter':
        return Icons.child_care_outlined;
      case 'brother':
        return Icons.man_2_outlined;
      default:
        return Icons.group_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final genderIcon = patient['gender'] == 'Male' ? Icons.male : Icons.female;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                child: Icon(
                  _getRelationIcon(patient['relation']),
                  size: 32,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient['name'] ?? "No Name",
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(patient['relation'] ?? "N/A",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
              Icon(genderIcon, color: Colors.black54)
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Chip(
                avatar: const Icon(Icons.cake_outlined, size: 18),
                label: Text("Age: ${patient['age'] ?? 'N/A'}"),
                backgroundColor: Colors.grey[100],
              ),
              Chip(
                avatar: Icon(genderIcon, size: 18),
                label: Text(patient['gender'] ?? 'N/A'),
                backgroundColor: Colors.grey[100],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  label: const Text("Edit",
                      style: TextStyle(color: Colors.blue))),
              TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label:
                  const Text("Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerPatientCard extends StatelessWidget {
  const _ShimmerPatientCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}