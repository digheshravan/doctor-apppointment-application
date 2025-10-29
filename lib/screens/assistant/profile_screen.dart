import 'package:flutter/material.dart';
// Note: Make sure these import paths are correct for your project
import 'package:medi_slot/auth/auth_service.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart'; // Added for shimmer effect

class AssistantProfileScreen extends StatefulWidget {
  const AssistantProfileScreen({super.key});

  @override
  State<AssistantProfileScreen> createState() => _AssistantProfileScreenState();
}

class _AssistantProfileScreenState extends State<AssistantProfileScreen> {
  // --- UI Colors from CheckInScreen Theme ---
  static const Color primaryColor = Color(0xFF00AEEF); // Main blue
  static const Color primaryVariant = Color(0xFF00B0F0); // Lighter blue
  static const Color accentColor = Color(0xFF4CAF50); // Green
  static const Color backgroundColor = Color(0xFFF8F9FA); // Off-white
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  // --- End of Theme Colors ---

  final _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService(); // Ensure this class exists

  bool _isLoading = true;
  bool _isEditingPersonalInfo = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();

  String? _assistantId;
  String? _assignedDoctorName;
  List<Map<String, dynamic>> _assignedClinics = [];

  @override
  void initState() {
    super.initState();
    // Simulate a longer load for shimmer to be visible
    // Future.delayed(Duration(seconds: 2), () {
    _fetchAssistantData();
    // });
  }

  Future<void> _fetchAssistantData() async {
    // Keep _isLoading true during the fetch
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final responseList = await _supabase
          .from('assistants')
          .select('*, profiles!inner(*)')
          .eq('user_id', userId)
          .limit(1);

      if (responseList.isEmpty) throw Exception('No assistant profile found');
      final response = responseList.first;

      _assistantId = response['assistant_id']?.toString();

      String? doctorName;
      if (response['assigned_doctor_id'] != null) {
        final doctorRes = await _supabase
            .from('doctors')
            .select('profiles!inner(name)')
            .eq('doctor_id', response['assigned_doctor_id'])
            .maybeSingle();
        doctorName = doctorRes?['profiles']?['name'] ?? 'Unknown';
      }

      List<Map<String, dynamic>> clinics = [];
      if (_assistantId != null) {
        final clinicsRes = await _supabase
            .from('clinic_assistants')
            .select('clinic_locations!inner(clinic_name, address)')
            .eq('assistant_id', _assistantId!);

        if (clinicsRes is List) {
          clinics = clinicsRes
              .map((e) => e['clinic_locations'] as Map<String, dynamic>)
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _nameController.text = response['profiles']?['name'] ?? '';
          _emailController.text = response['profiles']?['email'] ?? '';
          _phoneController.text = response['phone'] ?? '';
          _genderController.text = response['gender'] ?? '';
          _assignedDoctorName = doctorName;
          _assignedClinics = clinics;
          _isLoading = false; // <-- Data is loaded, stop shimmer
        });
      }
    } catch (e) {
      print('Error fetching assistant data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    // ... (Your logout dialog logic is unchanged)
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _handleLogout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    // ... (Your logout logic is unchanged)
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error signing out: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _savePersonalInfo() async {
    // ... (Your save logic is unchanged)
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('profiles').update({
        'name': _nameController.text,
        'email': _emailController.text,
      }).eq('id', userId);

      await _supabase.from('assistants').update({
        'phone': _phoneController.text,
        'gender': _genderController.text,
      }).eq('user_id', userId);

      if (mounted) {
        setState(() => _isEditingPersonalInfo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    super.dispose();
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_outline,
                  color: primaryColor, size: 30),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Assistant Profile',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  "Manage your account settings",
                  style: TextStyle(
                    color: lightTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // Use AnimatedOpacity to fade in the content after loading
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isLoading ? 0 : 1,
        child: RefreshIndicator(
          onRefresh: _fetchAssistantData, // <-- PULL-TO-REFRESH
          color: primaryColor,
          child: _isLoading
              ? _buildShimmerLayout() // <-- SHIMMER LAYOUT
              : SingleChildScrollView(
            // Added physics to always allow scrolling for pull-to-refresh
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildAssistantInfoCard(),
                const SizedBox(height: 24),
                _buildSectionTitleWithEdit(
                  "Personal Information",
                  isEditing: _isEditingPersonalInfo,
                  onEditToggle: () {
                    setState(() {
                      _isEditingPersonalInfo = !_isEditingPersonalInfo;
                    });
                  },
                ),
                _buildFormCard(
                  children: [
                    _buildInfoTextField(
                      controller: _nameController,
                      label: "Full Name",
                      icon: Icons.person_outline_rounded,
                      readOnly: !_isEditingPersonalInfo,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                      readOnly: !_isEditingPersonalInfo,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoTextField(
                      controller: _phoneController,
                      label: "Phone Number",
                      icon: Icons.phone_outlined,
                      readOnly: !_isEditingPersonalInfo,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoTextField(
                      controller: _genderController,
                      label: "Gender",
                      icon: Icons.wc,
                      readOnly: !_isEditingPersonalInfo,
                    ),
                    // Animated switcher for the "Save" button
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                        child: _isEditingPersonalInfo
                            ? Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: _buildSaveChangesButton(
                              onPressed: _savePersonalInfo),
                        )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Assigned Doctor - Enhanced UI
                _buildSectionTitle("Assigned Doctor"),
                Card(
                  elevation: 1,
                  color: Colors.white,
                  shadowColor: Colors.black.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: _assignedDoctorName != null
                      ? ListTile(
                    leading: const Icon(
                      Icons.medical_services_outlined,
                      color: primaryColor,
                    ),
                    title: Text(
                      _assignedDoctorName!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  )
                      : ListTile(
                    title: Text(
                      "No doctor assigned",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                // Assigned Clinics Section - Enhanced UI
                const SizedBox(height: 24),
                _buildSectionTitle("Assigned Clinics"),
                _assignedClinics.isEmpty
                    ? Card(
                  elevation: 1,
                  color: Colors.white,
                  shadowColor: Colors.black.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    title: Text(
                      "No clinics assigned",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
                    : Column(
                  children: _assignedClinics
                      .map((clinic) => _buildClinicCard(clinic))
                      .toList(),
                ),

                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout,
                      color: Colors.white, size: 20),
                  label: const Text(
                    "Logout",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Shimmer Layout ---
  Widget _buildShimmerLayout() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Shimmer for Info Card
            Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
            // Shimmer for Section Title
            Container(height: 20, width: 200, color: Colors.white),
            const SizedBox(height: 12),
            // Shimmer for Form Card
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
            // Shimmer for Section Title
            Container(height: 20, width: 150, color: Colors.white),
            const SizedBox(height: 12),
            // Shimmer for Doctor Card
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildAssistantInfoCard() {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase()
        : 'AS';

    return Card(
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Text(
                  initials,
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _nameController.text,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitleWithEdit(String title,
      {required bool isEditing, required VoidCallback onEditToggle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          IconButton(
            onPressed: onEditToggle,
            icon: Icon(isEditing ? Icons.close : Icons.edit,
                color: primaryColor, size: 22),
            tooltip: isEditing ? 'Cancel' : 'Edit',
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _buildInfoTextField(
      {required TextEditingController controller,
        required String label,
        required IconData icon,
        bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        // Animated the fill color for a smoother edit transition
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.transparent, // Handled by AnimatedContainer
              border: OutlineInputBorder(borderSide: BorderSide.none),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveChangesButton({required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text("Save Changes",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
    );
  }

  // Enhanced Clinic Card to use ListTile
  Widget _buildClinicCard(Map<String, dynamic> clinic) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.apartment_outlined, color: primaryColor),
        title: Text(
          clinic['clinic_name'] ?? 'Unnamed Clinic',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: clinic['address'] != null
            ? Text(
          clinic['address'],
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        )
            : null,
      ),
    );
  }
}