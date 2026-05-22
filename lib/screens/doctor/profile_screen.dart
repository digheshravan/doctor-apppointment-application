import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/doctor/assistant_requests.dart';
import 'package:medi_slot/screens/doctor/profile_checklist_widget.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_clinics.dart';

// -----------------------------------------------------------------------------
// Profile Screen
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controllers to pre-fill the fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _experienceYearsController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();


  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isEditing = false;
  String? _photoUrl;
  String? _doctorId;
  List<Map<String, dynamic>> _clinics = [];
  Map<String, dynamic>? _assistant;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_doctorId == null) return;
    final url = await DoctorPhotoUploader.pickAndUpload(
      context: context,
      doctorId: _doctorId!,
    );
    if (url != null && mounted) {
      setState(() => _photoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated! ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _feeController.dispose();
    _qualificationController.dispose();
    _genderController.dispose();
    _experienceYearsController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  // Fetch doctor data from database
  Future<void> _fetchDoctorData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      print('Fetching doctor data for user_id: $userId');

      final responseList = await _supabase
          .from('doctors')
          .select('*, profiles!inner(*)')
          .eq('user_id', userId)
          .limit(1);

      print('Response: $responseList');

      if (responseList.isEmpty) throw Exception('No doctor profile found for this user');

      final response = responseList.first;

      // Fetch clinics
      final clinicsResponse = await _supabase
          .from('clinic_locations')
          .select('*')
          .eq('doctor_id', response['doctor_id']);

      print('Clinics: $clinicsResponse');

      // Fetch assistant
      Map<String, dynamic>? assistantResponse;
      try {
        assistantResponse = await _supabase
            .from('assistants')
            .select('*, profiles!inner(*)')
            .eq('assigned_doctor_id', response['doctor_id'])
            .limit(1)
            .maybeSingle();
      } catch (e) {
        print('No assistant found or error fetching assistant: $e');
      }

      print('Assistant: $assistantResponse');

      if (mounted) {
        setState(() {
          _doctorId = response['doctor_id']?.toString();
          _nameController.text = response['profiles']?['name'] ?? '';
          _emailController.text = response['profiles']?['email'] ?? '';
          _phoneController.text = response['phone']?.toString() ?? '';
          _specializationController.text = response['specialization'] ?? '';
          _feeController.text = response['consultation_fee']?.toString() ?? '0';
          _photoUrl = response['photo_url'];
          _genderController.text = response['gender'] ?? '';
          _experienceYearsController.text = response['experience_years']?.toString() ?? '0';
          _qualificationController.text = response['qualification'] ?? '';
          _licenseController.text = response['license_number']?.toString() ?? '';
          _clinics = List<Map<String, dynamic>>.from(clinicsResponse);
          _assistant = assistantResponse;
          _isLoading = false;
        });
      }

      print('Experience years fetched: ${response['experience_years']}');
    } catch (e) {
      print('Error in _fetchDoctorData: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Save all profile information
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Update profiles table
      await _supabase.from('profiles').update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      }).eq('id', userId);

      // Update doctors table
      await _supabase.from('doctors').update({
        'phone': _phoneController.text.trim(),
        'gender': _genderController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'consultation_fee': double.tryParse(_feeController.text.trim()) ?? 0.0,
        'experience_years': int.tryParse(_experienceYearsController.text.trim()) ?? 0,
        'qualification': _qualificationController.text.trim(),
        'license_number': _licenseController.text.trim(),
      }).eq('user_id', userId);

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        await _fetchDoctorData(); // re-fetch fresh values from DB
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details updated successfully! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e ❌'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Navigate to manage clinics
  void _navigateToManageClinics() async {
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor ID not found. Please refresh.')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageClinicsPage(doctorId: _doctorId!),
      ),
    );

    // Refresh data if clinics were modified
    if (result == true) {
      setState(() => _isLoading = true);
      await _fetchDoctorData();
    }
  }

  // Navigate to manage assistant
  void _navigateToManageAssistant() async {
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor ID not found. Please refresh.')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorDashboard(doctorId: _doctorId!),
      ),
    );

    if (result == true) {
      _fetchDoctorData(); // refresh after changes
    }
  }

  // Handle Logout
  Future<void> _logout(BuildContext context) async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00B2C3),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Profile",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Manage your account settings",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (!_isEditing)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                  label: const Text(
                    "Edit",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B2C3),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _fetchDoctorData(); // revert
                        });
                      },
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text(
                        "Save",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Doctor Info Card
          _buildDoctorInfoCard(),
          const SizedBox(height: 24),

          // 🔹 Personal Information
          _buildSectionTitle("Personal Information"),
          _buildFormCard(
            children: [
              _buildInfoTextField(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person_outline_rounded,
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email_outlined,
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _genderController,
                label: "Gender",
                icon: Icons.wc,
                readOnly: !_isEditing,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Clinics
          _buildSectionTitle("Clinics"),
          _buildFormCard(
            children: [
              if (_clinics.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      "No clinics added yet",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                ..._clinics.asMap().entries.map((entry) {
                  final index = entry.key;
                  final clinic = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _buildClinicTile(
                        name: clinic['clinic_name'] ?? 'Unnamed Clinic',
                        address: clinic['address'] ?? 'No address provided',
                      ),
                    ],
                  );
                }).toList(),
              const SizedBox(height: 24),
              _buildActionButton(
                onPressed: _navigateToManageClinics,
                label: "View / Edit Clinics",
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Professional Details
          _buildSectionTitle("Professional Details"),
          _buildFormCard(
            children: [
              _buildInfoTextField(
                controller: _specializationController,
                label: "Specialization",
                icon: Icons.business_center_outlined,
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _feeController,
                label: "Consultation Fee",
                icon: const IconData(0x20B9, fontFamily: 'MaterialIcons'),
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _qualificationController,
                label: "Qualification",
                icon: Icons.school_outlined,
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _experienceYearsController,
                label: "Experience (Years)",
                icon: Icons.work_history_outlined,
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _licenseController,
                label: "Medical License Number",
                icon: Icons.badge_outlined,
                readOnly: !_isEditing,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Assigned Assistant
          _buildSectionTitle("Assigned Assistant"),
          Card(
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_assistant == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          "No assistant assigned",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildAssistantTile(
                      name: _assistant!['profiles']['name'] ?? 'Unknown',
                      phone: _assistant!['phone'] ?? 'No phone',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            onPressed: _navigateToManageAssistant,
            label: "Add / Remove Assistant",
          ),
          const SizedBox(height: 32),

          // 🔹 Logout Button
          ElevatedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
            label: const Text(
              "Logout",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 80), // Extra space for nav bar
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildDoctorInfoCard() {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0] : '')
        .take(2)
        .join()
        .toUpperCase()
        : 'DR';

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _photoUrl != null && _photoUrl!.isNotEmpty
                      ? CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(_photoUrl!),
                    onBackgroundImageError: (_, __) {},
                    child: _photoUrl!.isEmpty
                        ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00B2C3),
                      ),
                    )
                        : null,
                  )
                      : CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF00B2C3).withValues(alpha: 0.1),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00B2C3),
                      ),
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadPhoto, // new function
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.blue.shade700,
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _nameController.text,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _specializationController.text.isNotEmpty
                    ? _specializationController.text
                    : "Doctor",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
                const SizedBox(height: 16),
              Chip(
                backgroundColor: Colors.green.shade50,
                avatar: Icon(Icons.check_circle,
                    color: Colors.green.shade700, size: 18),
                label: Text(
                  "${_experienceYearsController.text} Years Experience",
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }



  Widget _buildFormCard({required List<Widget> children}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }



  Widget _buildActionButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: const Color(0xFF00B2C3),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildClinicTile({required String name, required String address}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined, color: Colors.blue.shade700, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantTile({required String name, required String phone}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.person_outline_rounded, color: Colors.blue.shade700, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}