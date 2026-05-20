// =============================================================================
// MediSlot v2 — Queue Token Model
// =============================================================================

class QueueTokenModel {
  final String tokenId;
  final String appointmentId;
  final String doctorId;
  final String? clinicId;
  final int tokenNumber;
  final String state; // waiting | active | completed | missed
  final DateTime? checkedInAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  const QueueTokenModel({
    required this.tokenId,
    required this.appointmentId,
    required this.doctorId,
    this.clinicId,
    required this.tokenNumber,
    this.state = 'waiting',
    this.checkedInAt,
    this.completedAt,
    required this.createdAt,
  });

  factory QueueTokenModel.fromMap(Map<String, dynamic> map) {
    return QueueTokenModel(
      tokenId: map['token_id'] as String,
      appointmentId: map['appointment_id'] as String,
      doctorId: map['doctor_id'] as String,
      clinicId: map['clinic_id'] as String?,
      tokenNumber: map['token_number'] as int,
      state: map['state'] as String? ?? 'waiting',
      checkedInAt: map['checked_in_at'] != null
          ? DateTime.parse(map['checked_in_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'token_id': tokenId,
        'appointment_id': appointmentId,
        'doctor_id': doctorId,
        'clinic_id': clinicId,
        'token_number': tokenNumber,
        'state': state,
        'checked_in_at': checkedInAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  bool get isWaiting => state == 'waiting';
  bool get isActive => state == 'active';
  bool get isCompleted => state == 'completed';
  bool get isMissed => state == 'missed';

  QueueTokenModel copyWith({
    String? state,
    DateTime? checkedInAt,
    DateTime? completedAt,
  }) =>
      QueueTokenModel(
        tokenId: tokenId,
        appointmentId: appointmentId,
        doctorId: doctorId,
        clinicId: clinicId,
        tokenNumber: tokenNumber,
        state: state ?? this.state,
        checkedInAt: checkedInAt ?? this.checkedInAt,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
      );
}
