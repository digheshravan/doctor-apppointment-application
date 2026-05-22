import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';

// =============================================================================
// MediSlot v2 — Prescription Preview Screen
// Read-only formatted preview of the prescription before saving.
// Shown when doctor taps "Preview" in WritePrescriptionScreen.
// =============================================================================

class PrescriptionPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> doctorInfo;
  final Map<String, dynamic> patientInfo;
  final String diagnosis;
  final String symptoms;
  final List<Map<String, String>> medicines;
  final String? recommendedTests;
  final String? additionalNotes;
  final String? followUpDate;
  final VoidCallback onConfirmSave;

  const PrescriptionPreviewScreen({
    super.key,
    required this.doctorInfo,
    required this.patientInfo,
    required this.diagnosis,
    required this.symptoms,
    required this.medicines,
    this.recommendedTests,
    this.additionalNotes,
    this.followUpDate,
    required this.onConfirmSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: MediSlotAppBar(
        title: 'Prescription Preview',
        subtitle: 'Review before saving',
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Doctor Header Card
            _buildDoctorHeader(),
            const SizedBox(height: 16),

            // Patient Info
            _buildSection(
              title: 'Patient Information',
              icon: Icons.person_outline_rounded,
              child: _buildPatientInfo(),
            ),
            const SizedBox(height: 12),

            // Diagnosis
            _buildSection(
              title: 'Diagnosis & Symptoms',
              icon: Icons.assignment_outlined,
              child: _buildDiagnosis(),
            ),
            const SizedBox(height: 12),

            // Medicines
            if (medicines.isNotEmpty) ...[
              _buildSection(
                title: 'Medicines (${medicines.length})',
                icon: Icons.medication_outlined,
                child: _buildMedicines(),
              ),
              const SizedBox(height: 12),
            ],

            // Recommended Tests
            if (recommendedTests != null && recommendedTests!.isNotEmpty) ...[
              _buildSection(
                title: 'Recommended Tests',
                icon: Icons.science_outlined,
                child: _buildText(recommendedTests!),
              ),
              const SizedBox(height: 12),
            ],

            // Additional Notes
            if (additionalNotes != null && additionalNotes!.isNotEmpty) ...[
              _buildSection(
                title: 'Additional Notes',
                icon: Icons.notes_outlined,
                child: _buildText(additionalNotes!),
              ),
              const SizedBox(height: 12),
            ],

            // Follow-up
            if (followUpDate != null && followUpDate!.isNotEmpty) ...[
              _buildFollowUpCard(),
              const SizedBox(height: 12),
            ],

            // Watermark
            const SizedBox(height: 8),
            _buildWatermark(),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: AppTheme.outlinedButtonStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirmSave();
                    },
                    icon: const Icon(Icons.save_outlined,
                        color: Colors.white, size: 18),
                    label: const Text('Save Prescription',
                        style: TextStyle(color: Colors.white)),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorHeader() {
    final photoUrl = doctorInfo['photo_url'] as String?;
    final name = doctorInfo['name'] ?? 'Doctor';
    final specialization = doctorInfo['specialization'] ?? '';
    final qualification = doctorInfo['qualification'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            backgroundImage:
                photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                if (specialization.isNotEmpty)
                  Text(
                    '$qualification • $specialization',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'MediSlot',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title,
      required IconData icon,
      required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Row(
      children: [
        Expanded(
          child: _infoCol('Name',
              patientInfo['name']?.toString() ?? '-'),
        ),
        Expanded(
          child: _infoCol(
              'Age', '${patientInfo['age'] ?? '-'} yrs'),
        ),
        Expanded(
          child:
              _infoCol('Gender', patientInfo['gender']?.toString() ?? '-'),
        ),
      ],
    );
  }

  Widget _buildDiagnosis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diagnosis.isNotEmpty) ...[
          _infoCol('Diagnosis', diagnosis),
          const SizedBox(height: 10),
        ],
        if (symptoms.isNotEmpty) _infoCol('Symptoms', symptoms),
      ],
    );
  }

  Widget _buildMedicines() {
    return Column(
      children: medicines
          .map((med) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.medication,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${med['dosage']} • ${med['frequency']} • ${med['duration']}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (med['instructions'] != null &&
                              med['instructions']!.isNotEmpty)
                            Text(
                              med['instructions']!,
                              style: const TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
    );
  }

  Widget _buildFollowUpCard() {
    String formatted = followUpDate!;
    try {
      formatted =
          DateFormat('dd MMMM yyyy').format(DateTime.parse(followUpDate!));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_outlined, color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Follow-up Date',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
              Text(formatted,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWatermark() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_outlined,
            size: 12, color: AppTheme.textHint),
        const SizedBox(width: 4),
        const Text(
          'Preview only — PDF will be generated after payment',
          style: TextStyle(
              fontSize: 11, color: AppTheme.textHint),
        ),
      ],
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}
