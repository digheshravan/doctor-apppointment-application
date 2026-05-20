// =============================================================================
// MediSlot v2 — Doctor Review Model
// =============================================================================

class ReviewModel {
  final String reviewId;
  final String appointmentId;
  final String doctorId;
  final String patientId;
  final int rating; // 1–5
  final String? comment;
  final DateTime createdAt;

  // Optionally joined
  final String? patientName;

  const ReviewModel({
    required this.reviewId,
    required this.appointmentId,
    required this.doctorId,
    required this.patientId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.patientName,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      reviewId: map['review_id'] as String,
      appointmentId: map['appointment_id'] as String,
      doctorId: map['doctor_id'] as String,
      patientId: map['patient_id'] as String,
      rating: map['rating'] as int,
      comment: map['comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      patientName: map['patients'] != null
          ? (map['patients'] as Map)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'appointment_id': appointmentId,
        'doctor_id': doctorId,
        'patient_id': patientId,
        'rating': rating,
        'comment': comment,
      };
}
