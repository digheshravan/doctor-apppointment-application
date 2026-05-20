// =============================================================================
// MediSlot v2 — Prescription Model (extended from v1)
// Adds pdf_url, payment_required, and released_at fields.
// =============================================================================

class PrescriptionModel {
  final String prescriptionId;
  final String doctorId;
  final String patientId;
  final String? appointmentId;
  final String? diagnosis;
  final String? symptoms;
  final String? additionalNotes;
  final String? recommendedTests;
  final String? followUpDate;
  final String date;

  // v2 fields
  final String? pdfUrl;
  final bool paymentRequired;
  final DateTime? releasedAt;

  // Optionally joined medicines
  final List<Map<String, dynamic>> medicines;

  const PrescriptionModel({
    required this.prescriptionId,
    required this.doctorId,
    required this.patientId,
    this.appointmentId,
    this.diagnosis,
    this.symptoms,
    this.additionalNotes,
    this.recommendedTests,
    this.followUpDate,
    required this.date,
    this.pdfUrl,
    this.paymentRequired = true,
    this.releasedAt,
    this.medicines = const [],
  });

  /// Whether the PDF is accessible to the patient.
  bool get isReleased => releasedAt != null && pdfUrl != null;

  factory PrescriptionModel.fromMap(Map<String, dynamic> map,
      {List<Map<String, dynamic>> medicines = const []}) {
    return PrescriptionModel(
      prescriptionId: map['prescription_id'] as String,
      doctorId: map['doctor_id'] as String,
      patientId: map['patient_id'] as String,
      appointmentId: map['appointment_id'] as String?,
      diagnosis: map['diagnosis'] as String?,
      symptoms: map['symptoms'] as String?,
      additionalNotes: map['additional_notes'] as String?,
      recommendedTests: map['recommended_tests'] as String?,
      followUpDate: map['follow_up_date'] as String?,
      date: map['date'] as String,
      pdfUrl: map['pdf_url'] as String?,
      paymentRequired: map['payment_required'] as bool? ?? true,
      releasedAt: map['released_at'] != null
          ? DateTime.parse(map['released_at'] as String)
          : null,
      medicines: medicines,
    );
  }

  Map<String, dynamic> toMap() => {
        'prescription_id': prescriptionId,
        'doctor_id': doctorId,
        'patient_id': patientId,
        'appointment_id': appointmentId,
        'diagnosis': diagnosis,
        'symptoms': symptoms,
        'additional_notes': additionalNotes,
        'recommended_tests': recommendedTests,
        'follow_up_date': followUpDate,
        'date': date,
        'pdf_url': pdfUrl,
        'payment_required': paymentRequired,
        'released_at': releasedAt?.toIso8601String(),
      };

  PrescriptionModel copyWith({
    String? pdfUrl,
    bool? paymentRequired,
    DateTime? releasedAt,
    List<Map<String, dynamic>>? medicines,
  }) =>
      PrescriptionModel(
        prescriptionId: prescriptionId,
        doctorId: doctorId,
        patientId: patientId,
        appointmentId: appointmentId,
        diagnosis: diagnosis,
        symptoms: symptoms,
        additionalNotes: additionalNotes,
        recommendedTests: recommendedTests,
        followUpDate: followUpDate,
        date: date,
        pdfUrl: pdfUrl ?? this.pdfUrl,
        paymentRequired: paymentRequired ?? this.paymentRequired,
        releasedAt: releasedAt ?? this.releasedAt,
        medicines: medicines ?? this.medicines,
      );
}
