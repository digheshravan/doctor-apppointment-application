import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({Key? key}) : super(key: key);

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  // UI Colors
  static const Color primaryColor = Color(0xFF00AEEF);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);

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
              backgroundColor: primaryColor,
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Profile added successfully")));
                } else {
                  await supabase.from('patients').update({
                    'name': nameController.text.trim(),
                    'age': int.tryParse(ageController.text.trim()),
                    'gender': selectedGender,
                    'relation': selectedRelation,
                  }).eq('patient_id', patient['patient_id']);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Profile updated successfully")));
                }

                Navigator.pop(context);
                await fetchPatients();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("Error: $e")));
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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.group_outlined,
                  color: primaryColor, size: 30),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family Profiles',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Manage family members',
                    style: TextStyle(
                      color: lightTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Add Profile Button in AppBar
            InkWell(
              onTap: () => addOrEditPatient(),
              borderRadius: BorderRadius.circular(28),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: primaryColor,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? _buildShimmerList()
          : patients.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: fetchPatients,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            return _PatientCard(
              patient: patient,
              onEdit: () => addOrEditPatient(patient: patient),
              onDelete: () => deletePatient(patient['patient_id']),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => const _ShimmerPatientCard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Profiles Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add family members to get started',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => addOrEditPatient(),
            icon: const Icon(Icons.add),
            label: const Text('Add Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade50,
                child: Icon(
                  _getRelationIcon(patient['relation']),
                  size: 30,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient['name'] ?? "No Name",
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(patient['relation'] ?? "N/A",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
              Icon(genderIcon, color: Colors.black54, size: 24)
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(
                icon: Icons.cake_outlined,
                label: "Age: ${patient['age'] ?? 'N/A'}",
              ),
              _buildInfoChip(
                icon: genderIcon,
                label: patient['gender'] ?? 'N/A',
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                label: const Text("Edit", style: TextStyle(color: Colors.blue)),
              ),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade300,
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                label: const Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
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
        margin: const EdgeInsets.only(bottom: 12),
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}