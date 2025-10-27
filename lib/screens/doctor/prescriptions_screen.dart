import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// Prescriptions Screen
// -----------------------------------------------------------------------------
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
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

  Future<void> _fetchPrescriptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current doctor's ID from auth
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch doctor_id from doctors table
      final doctorData = await _supabase
          .from('doctors')
          .select('doctor_id')
          .eq('user_id', userId)
          .single();

      final doctorId = doctorData['doctor_id'];

      // Fetch prescriptions with related data
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
          .eq('doctor_id', doctorId)
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
          dateLabel = '${prescriptionDate.day}/${prescriptionDate.month}/${prescriptionDate.year}';
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
        final diff = DateTime.now().difference(rx['raw_date'] as DateTime).inDays;
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchPrescriptions,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Header with Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Prescriptions",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Manage digital prescriptions",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    // TODO: Navigate to add new prescription screen
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade700,
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 🔹 Loading/Error/Content States
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading prescriptions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPrescriptions,
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
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Prescriptions you create will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: _prescriptions
                        .map((rx) => _PrescriptionListCard(rx: rx))
                        .toList(),
                  ),
              ],

            const SizedBox(height: 80), // Extra space for nav bar
          ],
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

  const _PrescriptionListCard({required this.rx});

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
                      rx['name'],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          rx['date'],
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
              _StatusTag(status: rx['status']),
            ],
          ),
          const SizedBox(height: 16),
          // 🔹 Diagnosis
          _buildDetailSection(
            "Diagnosis",
            Text(
              rx['diagnosis'],
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
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
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            )
                : Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: (rx['medicines'] as List<String>)
                  .map((med) => _MedicineChip(label: med))
                  .toList(),
            ),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_outlined,
                  label: "Share",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper for "Diagnosis" and "Medicines" sections
  Widget _buildDetailSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        content,
      ],
    );
  }

  // Helper for "Download" and "Share" buttons
  Widget _buildActionButton({required IconData icon, required String label}) {
    return OutlinedButton.icon(
      onPressed: () {
        // TODO: Implement action
      },
      icon: Icon(icon, size: 20, color: Colors.grey.shade700),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.grey.shade700,
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
  const _MedicineChip({required this.label});

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
          Icon(Icons.medication_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
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
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isActive = status == 'Active';
    final Color color = isActive ? Colors.blue.shade800 : Colors.green.shade800;
    final Color bgColor = isActive ? Colors.blue.shade50 : Colors.green.shade50;

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