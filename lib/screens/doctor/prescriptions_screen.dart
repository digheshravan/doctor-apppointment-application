import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Prescriptions Screen
// -----------------------------------------------------------------------------
class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  // Mock data for the prescription list
  final List<Map<String, dynamic>> _dummyPrescriptions = const [
    {
      "name": "Sarah Johnson",
      "date": "Today",
      "status": "Active",
      "diagnosis": "Hypertension, Type 2 Diabetes",
      "medicines": ["Lisinopril 10mg", "Metformin 500mg"],
    },
    {
      "name": "Michael Chen",
      "date": "Yesterday",
      "status": "Active",
      "diagnosis": "Bacterial Infection",
      "medicines": ["Amoxicillin 500mg", "Ibuprofen 400mg"],
    },
    {
      "name": "Emma Wilson",
      "date": "2 days ago",
      "status": "Completed",
      "diagnosis": "Asthma",
      "medicines": ["Albuterol Inhaler"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  // TODO: Handle add new prescription
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

          // 🔹 Stat Cards
          Row(
            children: [
              Expanded(
                child: _PrescriptionStatCard(
                  count: "127",
                  label: "Total Issued",
                  icon: Icons.article_outlined,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PrescriptionStatCard(
                  count: "8",
                  label: "This Week",
                  icon: Icons.link_outlined, // Using link icon from image
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 🔹 Prescription List
          Column(
            children: _dummyPrescriptions
                .map((rx) => _PrescriptionListCard(rx: rx))
                .toList(),
          ),

          const SizedBox(height: 80), // Extra space for nav bar
        ],
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
            Wrap(
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
      onPressed: () {},
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
          Icon(Icons.link, size: 16, color: Colors.grey.shade600),
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