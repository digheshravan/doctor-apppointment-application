import 'package:flutter/material.dart';
import 'package:medi_slot/auth/auth_service.dart'; // Adjust path if needed
import 'package:medi_slot/screens/login_screen.dart'; // Adjust path if needed

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

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // You would fetch this data, but for the UI, we'll pre-fill it
    _nameController.text = "Dr. David Smith";
    _emailController.text = "david.smith@hospital.com";
    _phoneController.text = "+1 234-567-8900";
    _specializationController.text = "General Medicine";
    _feeController.text = "₹200"; // 👈 CHANGED HERE
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  // Handle Logout
  Future<void> _logout(BuildContext context) async {
    await _authService.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Header
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
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
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
              ),
              const SizedBox(height: 24),
              _buildSaveChangesButton(onPressed: () {
                // TODO: Handle save personal info
              }),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Clinics
          _buildSectionTitle("Clinics"),
          _buildFormCard(
            children: [
              _buildClinicTile(
                name: "Main Clinic",
                address: "123 Medical Center, New York, NY 10001",
              ),
              const Divider(height: 24),
              _buildClinicTile(
                name: "Downtown Clinic",
                address: "456 Health Plaza, New York, NY 10002",
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  // TODO: Handle View/Edit Clinics
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "View / Edit Clinics",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              ),
              const SizedBox(height: 16),
              _buildInfoTextField(
                controller: _feeController,
                label: "Consultation Fee",
                icon: const IconData(0x20B9, fontFamily: 'MaterialIcons'), // 👈 CHANGED HERE (Rupee Icon)
              ),
              const SizedBox(height: 24),
              _buildSaveChangesButton(onPressed: () {
                // TODO: Handle save professional details
              }),
            ],
          ),
          const SizedBox(height: 24),

          // --- ADDED SECTION START ---
          // 🔹 Assigned Assistant
          _buildSectionTitle("Assigned Assistant"),
          Card(
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: _buildAssistantTile(
                name: "Sarah Johnson",
                role: "Medical Assistant",
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Handle Add/Remove Assistant
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Add / Remove Assistant",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // --- ADDED SECTION END ---

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
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF00B2C3).withOpacity(0.1),
                    child: const Text(
                      "DS",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00B2C3),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.blue.shade700,
                        child: const Icon(
                          Icons.home_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Dr. David Smith",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "General Physician",
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
                  "15 Years Experience",
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      shadowColor: Colors.black.withOpacity(0.04),
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
    required IconData icon, // Changed to IconData
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
            prefixIcon: Icon(icon, color: Colors.grey.shade600), // Use the IconData
            filled: true,
            fillColor: Colors.grey.shade50,
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

  Widget _buildSaveChangesButton({required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: const Color(0xFF00B2C3), // Teal color from image
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        "Save Changes",
        style: TextStyle(
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

  // --- ADDED HELPER WIDGET ---
  Widget _buildAssistantTile({required String name, required String role}) {
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
                role,
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