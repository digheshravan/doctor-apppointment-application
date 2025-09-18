import 'package:flutter/material.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // Role and gender
  String? _selectedRole;
  String? _gender;
  String? _selectedDoctorId;

  // Roles and doctor map
  final List<String> _roles = ["Patient", "Doctor", "Assistant"];
  Map<String, String> _doctorsMap = {}; // name -> userId
  List<String> _doctorNames = []; // for dropdown

  // Loading and password visibility
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    fetchDoctors();
  }

  // Fetch all doctors from Supabase profiles table
  Future<void> fetchDoctors() async {
    try {
      final List<dynamic> response = await supabase
          .from('doctors')
          .select('doctor_id, user_id')
          .eq('status', 'approved') // only approved doctors
          .order('doctor_id', ascending: true);

      // Map doctor name from profiles
      Map<String, String> doctorsMap = {};
      for (var doc in response) {
        final profile = await supabase
            .from('profiles')
            .select('name')
            .eq('id', doc['user_id'])
            .single();
        doctorsMap[profile['name']] = doc['doctor_id']; // map name -> doctor_id
      }

      setState(() {
        _doctorsMap = doctorsMap;
        _doctorNames = _doctorsMap.keys.toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching doctors: $e")),
        );
      }
    }
  }

  // Signup function
  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a gender")),
      );
      return;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a role")),
      );
      return;
    }

    // If Assistant, ensure doctor is selected
    if (_selectedRole == "Assistant" && _selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a doctor to assign")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final role = _selectedRole!;
    final gender = _gender!;
    final assignedDoctorId = _selectedDoctorId;

    try {
      // 1️⃣ Signup with Supabase Auth
      final response = await supabase.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) throw Exception("Signup failed");
      final userId = user.id;

      print("User signed up: userId=$userId");

      // 2️⃣ Insert into profiles table
      await supabase.from('profiles').insert({
        'id': userId,
        'name': name,
        'email': email,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });
      print("Profile created for $role: $name");

      // 3️⃣ Role-specific insertion
      if (role == "Patient") {
        await supabase.from('patients').insert({
          'user_id': userId,
          'phone': phone,
          'age': age,
          'gender': gender,
        });
        print("Patient data inserted");
      }
      else if (role == "Doctor") {
        await supabase.from('doctors').insert({
          'user_id': userId,
          'phone': phone,
          'gender': gender,
          'specialization': "General",
          'years_of_experience': 0,
          'status': "pending", // pending admin approval
        });
        print("Doctor data inserted");
      }
      else if (role == "Assistant") {
        print("Assigning assistant: userId=$userId, doctorId=$assignedDoctorId");
        final insertResponse = await supabase.from('assistants').insert({
          'user_id': userId,
          'phone': phone,
          'gender': gender,
          'assigned_doctor_id': assignedDoctorId,
          'status': "pending", // needs doctor approval
        }).select(); // using select() to see if insert succeeds

        print("Assistant insert response: $insertResponse");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signup successful! Please login.")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e, st) {
      print("Signup error: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          "Sign Up",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black,),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Select Role",
                    border: OutlineInputBorder(),
                  ),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v),
                  validator: (v) => v == null ? "Please select a role" : null,
                ),
                const SizedBox(height: 16),

                // Doctor assignment for Assistant
                if (_selectedRole == "Assistant")
                  DropdownButtonFormField<String>(
                    value: _selectedDoctorId,
                    decoration: const InputDecoration(
                      labelText: "Assign Doctor",
                      border: OutlineInputBorder(),
                    ),
                    items: _doctorsMap.entries
                        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDoctorId = v),
                    validator: (v) => v == null ? "Please select a doctor" : null,
                  ),
                if (_selectedRole == "Assistant") const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains("@") ? null : "Enter a valid email",
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v != null && v.length >= 6 ? null : "Password must be at least 6 chars",
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Please confirm password";
                    if (v != _passwordController.text) return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter your phone number";
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) return "Enter a valid 10-digit phone number";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Age
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v != null && int.tryParse(v) != null ? null : "Enter a valid age",
                ),
                const SizedBox(height: 16),

                // Gender
                const Text("Gender:"),
                Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text("Male"),
                      value: "Male",
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    RadioListTile<String>(
                      title: const Text("Female"),
                      value: "Female",
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Signup Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : signUp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.transparent, // transparent for gradient
                      shadowColor: Colors.transparent,     // no default shadow
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Sign Up",
                      style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already signed up? "),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text("Login here", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
