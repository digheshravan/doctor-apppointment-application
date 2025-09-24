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

  // --- THEME COLORS ---
  final Color primaryThemeColor = const Color(0xFF2193b0);
  final Color secondaryThemeColor = const Color(0xFF6dd5ed);

  @override
  void initState() {
    super.initState();
    fetchPatients();
  }

  /// Fetch all patients for current logged-in user
  Future<void> fetchPatients() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    // Simulate network delay for better shimmer effect
    await Future.delayed(const Duration(milliseconds: 1500));

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

  /// Delete patient by ID
  Future<void> deletePatient(String patientId) async {
    // Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this profile? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('patients').delete().eq('patient_id', patientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile deleted successfully")),
        );
      }
      await fetchPatients(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting profile: $e")),
        );
      }
    }
  }

  /// Edit patient details dialog
  Future<void> editPatient(Map patient) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: patient['name']);
    final ageController =
    TextEditingController(text: patient['age'].toString());
    String? selectedGender = patient['gender'];
    String? selectedRelation = patient['relation'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Profile"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                  val == null || val.isEmpty ? "Enter name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ageController,
                  decoration: const InputDecoration(
                    labelText: "Age",
                    border: OutlineInputBorder(),
                  ),
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
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                  ),
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
                  decoration: const InputDecoration(
                    labelText: "Relation",
                    border: OutlineInputBorder(),
                  ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryThemeColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save"),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await supabase.from('patients').update({
                  'name': nameController.text.trim(),
                  'age': int.tryParse(ageController.text.trim()) ?? patient['age'],
                  'gender': selectedGender,
                  'relation': selectedRelation,
                }).eq('patient_id', patient['patient_id']);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Profile updated successfully!")),
                  );
                  Navigator.pop(context);
                  await fetchPatients();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error updating profile: $e")),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Add patient dialog
  Future<void> addPatientDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    String? selectedGender;
    String? selectedRelation;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add New Profile"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                  val == null || val.isEmpty ? "Enter name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ageController,
                  decoration: const InputDecoration(
                    labelText: "Age",
                    border: OutlineInputBorder(),
                  ),
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
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                  ),
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
                    labelText: "Relation",
                    border: OutlineInputBorder(),
                  ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryThemeColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final user = supabase.auth.currentUser;
                if (user == null) throw "Not logged in";

                await supabase.from('patients').insert({
                  'user_id': user.id,
                  'name': nameController.text.trim(),
                  'age': int.tryParse(ageController.text.trim()),
                  'gender': selectedGender,
                  'relation': selectedRelation,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Profile added successfully!")),
                  );
                  Navigator.pop(context);
                  await fetchPatients();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryThemeColor, secondaryThemeColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Family Profiles",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: isLoading
          ? _buildShimmerList()
          : patients.isEmpty
          ? const _EmptyState(
        title: "No Profiles Found",
        message: "Tap the 'Add Profile' button to add a family member.",
      )
          : RefreshIndicator(
        onRefresh: fetchPatients,
        color: primaryThemeColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            return _PatientCard(
              patient: patients[index],
              themeColor: primaryThemeColor,
              onEdit: () => editPatient(patients[index]),
              onDelete: () =>
                  deletePatient(patients[index]['patient_id']),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPatientDialog,
        label: const Text("Add Profile"),
        icon: const Icon(Icons.add),
        backgroundColor: primaryThemeColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => const _ShimmerPatientCard(),
    );
  }
}

// --- UI WIDGETS ---

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final Color themeColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PatientCard({
    required this.patient,
    required this.themeColor,
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
        return Icons.child_care_outlined;
      case 'daughter':
        return Icons.child_care_outlined;
      case 'brother':
        return Icons.man_2_outlined;
      case 'other':
      default:
        return Icons.group_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final genderIcon = patient['gender'] == 'Male' ? Icons.male : Icons.female;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Icon
          Positioned(
            right: -40,
            bottom: -40,
            child: Icon(
              genderIcon,
              size: 150,
              color: (patient['gender'] == 'Male' ? Colors.blue : Colors.pink)
                  .withOpacity(0.05),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: themeColor.withOpacity(0.1),
                      child: Icon(
                        _getRelationIcon(patient['relation']),
                        color: themeColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['name'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            patient['relation'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(Icons.cake_outlined, "Age: ${patient['age'] ?? 'N/A'}"),
                    _buildInfoChip(genderIcon, patient['gender'] ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: 18, color: themeColor),
                      label: Text("Edit", style: TextStyle(color: themeColor)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40, child: VerticalDivider(width: 1)),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      label: const Text("Delete", style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, color: Colors.grey.shade700, size: 16),
      label: Text(text),
      backgroundColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPatientCard extends StatelessWidget {
  const _ShimmerPatientCard();

  Widget _buildShimmerBox({required double height, required double width, double radius = 8}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildShimmerBox(height: 60, width: 60, radius: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(height: 22, width: 180),
                        const SizedBox(height: 8),
                        _buildShimmerBox(height: 16, width: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildShimmerBox(height: 32, width: 120),
                  _buildShimmerBox(height: 32, width: 120),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 48), // Placeholder for buttons
          ],
        ),
      ),
    );
  }
}