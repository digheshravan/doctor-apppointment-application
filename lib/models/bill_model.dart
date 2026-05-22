// =============================================================================
// MediSlot v2 — Consultation Bill Model
// =============================================================================

class BillModel {
  final String billId;
  final String appointmentId;
  final String doctorId;
  final String patientId;
  final double amount;
  final String? paymentMethod; // upi | card | cash
  final String paymentStatus;  // pending | processing | paid | failed | cash_pending | cash_confirmed | waived
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillModel({
    required this.billId,
    required this.appointmentId,
    required this.doctorId,
    required this.patientId,
    required this.amount,
    this.paymentMethod,
    this.paymentStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      billId: map['bill_id'] as String,
      appointmentId: map['appointment_id'] as String,
      doctorId: map['doctor_id'] as String,
      patientId: map['patient_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      paymentStatus: map['payment_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'bill_id': billId,
        'appointment_id': appointmentId,
        'doctor_id': doctorId,
        'patient_id': patientId,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isPaid =>
      paymentStatus == 'paid' ||
      paymentStatus == 'cash_confirmed' ||
      paymentStatus == 'waived';

  bool get isCashPending => paymentStatus == 'cash_pending';

  BillModel copyWith({
    String? paymentMethod,
    String? paymentStatus,
    DateTime? updatedAt,
  }) =>
      BillModel(
        billId: billId,
        appointmentId: appointmentId,
        doctorId: doctorId,
        patientId: patientId,
        amount: amount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
