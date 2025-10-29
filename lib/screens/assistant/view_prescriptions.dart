import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/assistant/write_prescription_assistant.dart';

// -----------------------------------------------------------------------------
// Prescriptions Screen for Assistant
// -----------------------------------------------------------------------------
class AssistantPrescriptionsScreen extends StatefulWidget {
  const AssistantPrescriptionsScreen({super.key});

  @override
  State<AssistantPrescriptionsScreen> createState() =>
      _AssistantPrescriptionsScreenState();
}

class _AssistantPrescriptionsScreenState
    extends State<AssistantPrescriptionsScreen> {
  // --- UI Colors from Theme ---
  static const Color primaryColor = Color(0xFF00AEEF); // Main blue
  static const Color accentColor = Color(0xFF4CAF50); // Green
  static const Color backgroundColor = Color(0xFFF8F9FA); // Off-white
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  // --- End Theme Colors ---

  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;
  String? _error;
  int _totalIssued = 0;
  int _thisWeek = 0;

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions();
  }

  // --- All backend logic is unchanged ---
  Future<void> _fetchPrescriptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current assistant's user ID from auth
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch assistant_id from assistants table
      final assistantData = await _supabase
          .from('assistants')
          .select('assistant_id, assigned_doctor_id')
          .eq('user_id', userId)
          .single();

      final assignedDoctorId = assistantData['assigned_doctor_id'];

      if (assignedDoctorId == null) {
        throw Exception('No doctor assigned to this assistant');
      }

      // Fetch prescriptions with related data for the assigned doctor
      final prescriptionsData = await _supabase
          .from('prescriptions')
          .select('''
            prescription_id,
            date,
            diagnosis,
            symptoms,
            additional_notes,
            follow_up_date,
            created_at,
            appointment_id,
            patients (
              patient_id,
              name
            ),
            appointments(
              visit_status
            )
          ''')
          .eq('doctor_id', assignedDoctorId)
          .order('date', ascending: false);

      // Fetch medicines for each prescription
      List<Map<String, dynamic>> prescriptionsWithMedicines = [];

      for (var prescription in prescriptionsData) {
        final medicines = await _supabase
            .from('prescription_medicines')
            .select('name, dosage, frequency, duration, instructions')
            .eq('prescription_id', prescription['prescription_id']);

        // Fetch visit_status directly from appointments table
        String status = 'Unknown';
        if (prescription['appointments'] != null &&
            prescription['appointments']['visit_status'] != null) {
          status = prescription['appointments']['visit_status'];
        }

        // Format date
        final prescriptionDate = DateTime.parse(prescription['date']);
        final now = DateTime.now();
        final difference = now.difference(prescriptionDate).inDays;

        String dateLabel;
        if (difference == 0) {
          dateLabel = 'Today';
        } else if (difference == 1) {
          dateLabel = 'Yesterday';
        } else if (difference < 7) {
          dateLabel = '$difference days ago';
        } else {
          dateLabel =
          '${prescriptionDate.day}/${prescriptionDate.month}/${prescriptionDate.year}';
        }

        // Format medicines list
        List<String> medicinesList = medicines.map<String>((med) {
          String medString = med['name'];
          if (med['dosage'] != null && med['dosage'].toString().isNotEmpty) {
            medString += ' ${med['dosage']}';
          }
          return medString;
        }).toList();

        prescriptionsWithMedicines.add({
          'prescription_id': prescription['prescription_id'],
          'name': '${prescription['patients']['name']}',
          'date': dateLabel,
          'status': status,
          'diagnosis': prescription['diagnosis'] ?? 'Not specified',
          'medicines': medicinesList,
          'raw_date': prescriptionDate,
        });
      }

      // Calculate stats
      _totalIssued = prescriptionsWithMedicines.length;
      _thisWeek = prescriptionsWithMedicines.where((rx) {
        final diff =
            DateTime.now().difference(rx['raw_date'] as DateTime).inDays;
        return diff <= 7;
      }).length;

      setState(() {
        _prescriptions = prescriptionsWithMedicines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  // --- End of backend logic ---

  // Navigate to write prescription screen
  void _navigateToWritePrescription() async {
    // Navigate to the write prescription screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssistantWritePrescriptionScreen(
          patient: {}, // Empty patient data - user will select from dropdown
        ),
      ),
    );

    // Refresh the list if a prescription was saved
    if (result == true) {
      _fetchPrescriptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- UI ENHANCEMENT: Added Scaffold and standard AppBar ---
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
              child: const Icon(Icons.description_outlined,
                  color: primaryColor, size: 30),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prescriptions',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'View all prescriptions',
                    style: TextStyle(
                      color: lightTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // 🔥 Updated: Add button now navigates to write prescription screen
            InkWell(
              onTap: _navigateToWritePrescription,
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
      body: RefreshIndicator(
        onRefresh: _fetchPrescriptions,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Loading/Error/Content States
              if (_isLoading)
                Column(
                  children:
                  List.generate(4, (index) => _ShimmerPrescriptionCard()),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading prescriptions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: lightTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(fontSize: 14, color: lightTextColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchPrescriptions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                  // 🔹 Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: _PrescriptionStatCard(
                          count: _totalIssued.toString(),
                          label: "Total Issued",
                          icon: Icons.article_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PrescriptionStatCard(
                          count: _thisWeek.toString(),
                          label: "This Week",
                          icon: Icons.calendar_today_outlined,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Prescription List
                  if (_prescriptions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.description_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No prescriptions yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: lightTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Prescriptions will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: lightTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _prescriptions
                          .map((rx) => _PrescriptionListCard(
                        rx: rx,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        lightTextColor: lightTextColor,
                        accentColor: accentColor,
                      ))
                          .toList(),
                    ),
                ],

              const SizedBox(height: 80), // Extra space for nav bar
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Stat Card
// -----------------------------------------------------------------------------
class _PrescriptionStatCard extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;
  final MaterialColor color;

  const _PrescriptionStatCard({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Prescription List Card
// -----------------------------------------------------------------------------
class _PrescriptionListCard extends StatelessWidget {
  final Map<String, dynamic> rx;
  final Color primaryColor;
  final Color textColor;
  final Color lightTextColor;
  final Color accentColor;

  const _PrescriptionListCard({
    required this.rx,
    required this.primaryColor,
    required this.textColor,
    required this.lightTextColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // 🔹 Top Row: Patient, Date, Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rx['name'],
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: lightTextColor),
                        const SizedBox(width: 4),
                        Text(
                          rx['date'],
                          style: TextStyle(
                            fontSize: 14,
                            color: lightTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusTag(
                status: rx['status'],
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 🔹 Diagnosis
          _buildDetailSection(
            "Diagnosis",
            Text(
              rx['diagnosis'],
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
            ),
            lightTextColor,
          ),
          const SizedBox(height: 16),
          // 🔹 Medicines
          _buildDetailSection(
            "Medicines",
            (rx['medicines'] as List).isEmpty
                ? Text(
              'No medicines prescribed',
              style: TextStyle(
                fontSize: 14,
                color: lightTextColor,
                fontStyle: FontStyle.italic,
              ),
            )
                : Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: (rx['medicines'] as List<String>)
                  .map((med) => _MedicineChip(
                label: med,
                textColor: textColor,
                lightTextColor: lightTextColor,
              ))
                  .toList(),
            ),
            lightTextColor,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // 🔹 Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.download_outlined,
                  label: "Download",
                  textColor: textColor,
                  lightTextColor: lightTextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_outlined,
                  label: "Share",
                  textColor: textColor,
                  lightTextColor: lightTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
      String title, Widget content, Color lightTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: lightTextColor,
          ),
        ),
        const SizedBox(height: 6),
        content,
      ],
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
        required String label,
        required Color textColor,
        required Color lightTextColor}) {
    return OutlinedButton.icon(
      onPressed: () {
        // TODO: Implement action
      },
      icon: Icon(icon, size: 20, color: lightTextColor),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: lightTextColor,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Medicine Chip
// -----------------------------------------------------------------------------
class _MedicineChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color lightTextColor;

  const _MedicineChip(
      {required this.label,
        required this.textColor,
        required this.lightTextColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined, size: 16, color: lightTextColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widget: Status Tag
// -----------------------------------------------------------------------------
class _StatusTag extends StatelessWidget {
  final String status;
  final Color primaryColor;
  final Color accentColor;

  const _StatusTag(
      {required this.status,
        required this.primaryColor,
        required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final bool isActive = status == 'active';
    final Color color = isActive ? primaryColor : accentColor;
    final Color bgColor =
    isActive ? primaryColor.withOpacity(0.1) : accentColor.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
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
// Shimmer Loading Placeholder for Prescription Card
// -----------------------------------------------------------------------------
class _ShimmerPrescriptionCard extends StatelessWidget {
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
                        width: 120,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        color: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 20,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 12,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  height: 26,
                  width: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 10),
                Container(
                  height: 26,
                  width: 60,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}