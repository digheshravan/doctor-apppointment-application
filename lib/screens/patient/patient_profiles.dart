import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Fetch all patients for current logged-in user
  Future<void> fetchPatients() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response =
    await supabase.from('patients').select().eq('user_id', user.id);

    setState(() {
      patients = response;
      isLoading = false;
    });
  }

  /// Delete patient by ID
  Future<void> deletePatient(String patientId) async {
    try {
      await supabase.from('patients').delete().eq('patient_id', patientId);
      fetchPatients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile deleted successfully")),
        );
      }
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

    Future<void> saveEdit() async {
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
            const SnackBar(content: Text("Profile updated successfully!")),
          );
          Navigator.pop(context);
          fetchPatients();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error updating profile: $e")),
          );
        }
      }
    }

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
              backgroundColor: const Color(0xFF2193b0),
            ),
            child: const Text("Save"),
            onPressed: saveEdit,
          ),
        ],
      ),
    );
  }

  /// Build patient card UI
  Widget buildPatientCard(Map patient, int index) {
    final colors = [
      [Colors.deepPurple, Colors.purpleAccent],
      [Colors.teal, Colors.greenAccent],
      [Colors.indigo, Colors.blueAccent],
      [Colors.orange, Colors.deepOrangeAccent],
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors[index % colors.length],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  patient['name'][0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Age: ${patient['age']} • ${patient['gender']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "Relation: ${patient['relation']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => editPatient(patient),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => deletePatient(patient['patient_id']),
                  ),
                ],
              )
            ],
          ),
        ),
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

    Future<void> savePatient() async {
      if (!formKey.currentState!.validate()) return;
      try {
        final user = supabase.auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Not logged in")),
          );
          return;
        }

        await supabase.from('patients').insert({
          'user_id': user.id,
          'name': nameController.text.trim(),
          'age': int.tryParse(ageController.text.trim()),
          'gender': selectedGender,
          'relation': selectedRelation,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile added successfully!")),
          );
          Navigator.pop(context);
          fetchPatients();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Profile"),
        content: Form(
          key: formKey,
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
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, // transparent for gradient
                shadowColor: Colors.transparent,     // avoid double shadow
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: savePatient,
              child: const Text(
                "Add",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Family Profiles",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : patients.isEmpty
          ? const Center(
        child: Text(
          "No profiles found",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: patients.length,
        itemBuilder: (context, index) =>
            buildPatientCard(patients[index], index),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => addPatientDialog(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Add Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent, // transparent for gradient
          elevation: 0,
        ),
      ),
    );
  }
}