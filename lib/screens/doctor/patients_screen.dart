import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../auth/auth_service.dart';

// -----------------------------------------------------------------------------
// Patients Screen
// -----------------------------------------------------------------------------
class PatientsScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onWritePrescription;
  const PatientsScreen({super.key, this.onWritePrescription});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<Map<String, dynamic>> _allTodayPatients = [];
  List<Map<String, dynamic>> _allPatients = [];
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _currentFilter = "Total"; // Total / Active / New
  int _currentIndex = 0;
  Map<String, dynamic>? _selectedPatient;


  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients({String filter = "Total"}) async {
    setState(() => _isLoading = true);

    try {
      final patients = await _authService.getAppointmentsForCurrentDoctor();

      final today = DateTime.now().toIso8601String().split('T').first;

      // ✅ Store ALL patients (excluding cancelled/rejected)
      _allPatients = patients.where((p) =>
      p['status'] != 'cancelled' && p['status'] != 'rejected'
      ).toList();

      // Only today's appointments with accepted/confirmed status
      _allTodayPatients = patients.where((p) =>
      p['appointment_date'] == today &&
          (p['status'] == 'confirmed' || p['status'] == 'accepted')
      ).toList();

      // Filter for list display
      if (filter == "Total") {
        // ✅ Show ALL patients when Total is selected
        _patients = List.from(_allPatients);
      } else if (filter == "Active") {
        _patients = _allTodayPatients
            .where((p) => p['visit_status'] == 'active')
            .toList();
      } else if (filter == "New") {
        _patients = _allTodayPatients
            .where((p) => p['visit_status'] == 'inactive')
            .toList();
      }

      setState(() {
        _currentFilter = filter;
        _isLoading = false;
      });
    } catch (e) {
      print('⚠️ Error fetching patients: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onWritePrescription(Map<String, dynamic> patient) {
    if (widget.onWritePrescription != null) {
      widget.onWritePrescription!(patient);
    }
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Patients",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "View and manage patient records",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // 🔹 Stats
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _fetchPatients(filter: "Total"),
                  child: _PatientStatCard(
                    count: _isLoading ? "..." : _allPatients.length.toString(), // ✅ FIXED
                    label: "Total",
                    color: Colors.blue.shade50,
                    textColor: Colors.blue.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _fetchPatients(filter: "Active"),
                  child: _PatientStatCard(
                    count: _isLoading ? "..." : _allTodayPatients.where((p) => p['visit_status'] == 'active').length.toString(),
                    label: "Active",
                    color: Colors.green.shade50,
                    textColor: Colors.green.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _fetchPatients(filter: "New"),
                  child: _PatientStatCard(
                    count: _isLoading ? "..." : _allTodayPatients.where((p) => p['visit_status'] == 'inactive').length.toString(),
                    label: "New",
                    color: Colors.orange.shade50,
                    textColor: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Patient list
          Text(
            _currentFilter == "Total"
                ? "All Patients"
                : _currentFilter == "Active"
                ? "Active Patients"
                : "New Patients",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            Column(
              children: List.generate(5, (index) => const _ShimmerPatientCard()),
            )
          else if (_patients.isEmpty)
            const Center(child: Text("No patients found"))
          else
            Column(
              children: _patients.map((p) => _PatientListCard(
                patient: {
                  'name': p['patients']?['name'] ?? 'Unknown',
                  'phone': p['patients']?['relation'] ?? 'N/A',
                  'gender': p['patients']?['gender'] ?? 'N/A',
                  'age': p['patients']?['age']?.toString() ?? '-',
                  'status': p['visit_status'] ?? '-',
                  'appointment_date': p['appointment_date'] ?? '-',
                },
                onWritePrescription: _onWritePrescription,
              )).toList(),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Helper Widget: Stat Card (Unchanged)
// -----------------------------------------------------------------------------
class _PatientStatCard extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final Color textColor;


  const _PatientStatCard({
    required this.count,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return _isLoadingStat(context)
        ? Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    )
        : Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLoadingStat(BuildContext context) {
    try {
      // detect shimmer trigger by placeholder “...”
      return count == "...";
    } catch (_) {
      return false;
    }
  }
}

// -----------------------------------------------------------------------------
// 🔹 --- MODIFIED WIDGET: Patient List Card ---
// Converted to StatefulWidget to handle expand/collapse
// -----------------------------------------------------------------------------
class _PatientListCard extends StatefulWidget {
  final Map<String, dynamic> patient;
  final Function(Map<String, dynamic>)? onWritePrescription;

  const _PatientListCard({
    required this.patient,
    this.onWritePrescription,
  });

  @override
  State<_PatientListCard> createState() => _PatientListCardState();
}

class _PatientListCardState extends State<_PatientListCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Top Row: Name, Phone, Icon
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient['name'],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            widget.patient['phone'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  // 👈 Changed icon
                  _isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),

            // 🔹 --- NEW: Conditional Expanded Section ---
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // 🔹 Bottom Row: Details (Gender, Age, Status)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1: Gender
                  Expanded(
                    child: _buildInfoColumn(
                      "Gender",
                      widget.patient['gender'],
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  // Column 2: Age
                  Expanded(
                    child: _buildInfoColumn(
                      "Age",
                      widget.patient['age'],
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  // Column 3: Status
                  Expanded(
                    child: _buildStatusColumn("Status", widget.patient['status']),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🔹 "Write Prescription" Button (only for active patients)
              if (widget.patient['status'] == 'active')
                ElevatedButton.icon(
                  onPressed: () {
                    // Instead of Navigator.push, use a bottom nav callback
                    // Example: call a function from parent to switch page and pass patient
                    if (widget.onWritePrescription != null) {
                      widget.onWritePrescription!(widget.patient);
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    "Write Prescription",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A3B0),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }

  // 🔹 --- MODIFIED HELPER ---
  // Helper for info columns (now with an icon)
  Widget _buildInfoColumn(String title, String value, {required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 18.0), // Indent value under icon
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // 🔹 --- UNCHANGED HELPER ---
  // Helper for the status column
  Widget _buildStatusColumn(String title, String status) {
    final bool isActive = status == 'active';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6), // Adjusted spacing to match
        _StatusTag(
          status: status,
          color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
          backgroundColor:
          isActive ? Colors.green.shade50 : Colors.grey.shade200,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Status Tag (Unchanged)
// -----------------------------------------------------------------------------
class _StatusTag extends StatelessWidget {
  final String status;
  final Color color;
  final Color backgroundColor;

  const _StatusTag({
    required this.status,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// 🔹 Shimmer Placeholder for Patient Cards
// -----------------------------------------------------------------------------
class _ShimmerPatientCard extends StatelessWidget {
  const _ShimmerPatientCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + text shimmer row
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 100,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 60,
                        color: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 20,
                  width: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Expanded info section shimmer
            Container(
              height: 10,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }
}
