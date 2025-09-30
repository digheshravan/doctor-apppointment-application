import 'package:flutter/material.dart';
// Make sure this path is correct for your project structure
import 'package:medi_slot/screens/login_screen.dart'; // Ensure this path is correct
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
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // State variables
  String? _selectedRole;
  String? _gender;
  String? _selectedDoctorId;
  final List<String> _roles = ["Patient", "Doctor", "Assistant"];
  Map<String, String> _doctorsMap = {}; // Maps doctor name to doctor_id

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Fetch doctors when the screen loads, for the assistant role
    fetchDoctors();
  }

  @override
  void dispose() {
    // Clean up controllers
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Fetch all approved doctors from Supabase
  Future<void> fetchDoctors() async {
    try {
      final List<dynamic> response = await supabase
          .from('doctors')
          .select('doctor_id, user_id')
          .eq('status', 'approved')
          .order('doctor_id', ascending: true);

      Map<String, String> doctorsMap = {};
      for (var doc in response) {
        final profile = await supabase
            .from('profiles')
            .select('name')
            .eq('id', doc['user_id'])
            .single();
        doctorsMap[profile['name']] = doc['doctor_id'];
      }

      if (mounted) {
        setState(() {
          _doctorsMap = doctorsMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching doctors: $e")),
        );
      }
    }
  }

  // Main signup function
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
    final genderValue = _gender!; // Renamed to avoid conflict
    final assignedDoctorId = _selectedDoctorId;

    try {
      final response =
      await supabase.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) throw Exception("Signup failed: No user created");
      final userId = user.id;

      await supabase.from('profiles').insert({
        'id': userId,
        'name': name,
        'email': email,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (role == "Patient") {
        await supabase.from('patients').insert({
          'user_id': userId,
          'phone': phone,
          'age': age,
          'gender': genderValue
        });
      } else if (role == "Doctor") {
        await supabase.from('doctors').insert({
          'user_id': userId,
          'phone': phone,
          'gender': genderValue,
          'specialization': "General", // Default value
          'years_of_experience': 0, // Default value
          'status': "pending",
        });
      } else if (role == "Assistant") {
        await supabase.from('assistants').insert({
          'user_id': userId,
          'phone': phone,
          'gender': genderValue,
          'assigned_doctor_id': assignedDoctorId,
          'status': "pending",
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Signup successful! Please verify your email and login."),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Signup Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define your color scheme (example)
    final Color primaryColor = const Color(0xFF00A9F1);
    final Color accentColor = const Color(0xFF0077B6);
    final Color backgroundColor = Colors.white;
    // final Color textFieldFillColor = Colors.grey[100]!; // Defined in _buildTextField & _buildDropdown
    // final Color errorColor = Colors.redAccent; // Defined in _buildTextField

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Create Account',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
        const IconThemeData(color: Colors.black87), // Ensure back button is visible
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Optional: Add a logo or header image here
                // Image.asset('assets/your_logo.png', height: 100),
                // const SizedBox(height: 24),

                Text(
                  "Let's Get Started!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create an account to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),

                // Role Dropdown
                _buildDropdown(
                  label: 'I am a...',
                  value: _selectedRole,
                  items: _roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedRole = v;
                    _selectedDoctorId = null;
                  }),
                  validator: (v) => v == null ? "Please select a role" : null,
                  icon: Icons.person_search_outlined,
                ),
                const SizedBox(height: 20),

                // Conditional Doctor assignment for Assistant
                if (_selectedRole == "Assistant")
                  _buildDropdown(
                    label: 'Assign to Doctor',
                    value: _selectedDoctorId,
                    items: _doctorsMap.entries
                        .map((e) =>
                        DropdownMenuItem(value: e.value, child: Text(e.key)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDoctorId = v),
                    validator: (v) =>
                    v == null ? "Please select a doctor" : null,
                    icon: Icons.medical_services_outlined,
                  ),
                if (_selectedRole == "Assistant") const SizedBox(height: 20),

                // Form Fields
                _buildTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    validator: (v) =>
                    v!.isEmpty ? "Please enter your full name" : null,
                    icon: Icons.person_outline),
                const SizedBox(height: 20),
                _buildTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                    !v!.contains("@") ? "Enter a valid email address" : null,
                    icon: Icons.email_outlined),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isObscure: _obscurePassword,
                  validator: (v) => v!.length < 6
                      ? "Password must be at least 6 characters"
                      : null,
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[600]),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  isObscure: _obscureConfirmPassword,
                  validator: (v) =>
                  v != _passwordController.text ? "Passwords do not match" : null,
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[600]),
                    onPressed: () => setState(() =>
                    _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                    label: 'Phone Number (10 digits)',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) => !RegExp(r'^[0-9]{10}$').hasMatch(v!)
                        ? "Enter a valid 10-digit phone number"
                        : null,
                    icon: Icons.phone_outlined),
                const SizedBox(height: 20),
                _buildTextField(
                    label: 'Age',
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                    int.tryParse(v!) == null || int.parse(v) <= 0
                        ? "Enter a valid age"
                        : null,
                    icon: Icons.cake_outlined),
                const SizedBox(height: 24),

                // Gender Selection
                Text('Gender',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[800])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Male"),
                          value: "Male",
                          groupValue: _gender,
                          onChanged: (v) => setState(() => _gender = v),
                          activeColor: primaryColor,
                          contentPadding: EdgeInsets.zero,
                        )),
                    Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Female"),
                          value: "Female",
                          groupValue: _gender,
                          onChanged: (v) => setState(() => _gender = v),
                          activeColor: primaryColor,
                          contentPadding: EdgeInsets.zero,
                        )),
                  ],
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding:
                    const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ))
                      : const Text('Sign Up',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account?",
                        style: TextStyle(color: Colors.grey[700])),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      child: Text('Sign In',
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable helper widget for text form fields
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    IconData? icon,
  }) {
    final Color primaryColor = const Color(0xFF00A9F1);
    final Color textFieldFillColor = Colors.grey[100]!;
    final Color errorColor = Colors.redAccent[700]!; // Slightly darker red

    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.grey[800], fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        prefixIcon:
        icon != null ? Icon(icon, color: primaryColor, size: 20) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: textFieldFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[350]!, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        errorStyle: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Consistent padding
      ),
    );
  }

  // Reusable helper widget for dropdowns
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
    required String? Function(String?)? validator,
    IconData? icon,
  }) {
    final Color primaryColor = const Color(0xFF00A9F1);
    final Color textFieldFillColor = Colors.grey[100]!;
    final Color errorColor = Colors.redAccent[700]!;


    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor, size: 28),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        prefixIcon:
        icon != null ? Icon(icon, color: primaryColor, size: 20) : null,
        filled: true,
        fillColor: textFieldFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[350]!, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        errorStyle: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Consistent padding
      ),
      dropdownColor: Colors.white,
      style: TextStyle(color: Colors.grey[800], fontSize: 16),
    );
  }
}
