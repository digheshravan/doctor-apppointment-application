// =============================================================================
// MediSlot v2 — Payment Model
// =============================================================================

class PaymentModel {
  final String paymentId;
  final String billId;
  final String patientId;
  final double amount;
  final String method; // upi | card | cash
  final String status; // pending | paid | failed | cash_pending | cash_confirmed
  final String? transactionRef; // mock ref for UPI/card
  final String? confirmedBy;   // assistant/doctor user_id for cash confirmation
  final DateTime? paidAt;
  final DateTime createdAt;

  const PaymentModel({
    required this.paymentId,
    required this.billId,
    required this.patientId,
    required this.amount,
    required this.method,
    this.status = 'pending',
    this.transactionRef,
    this.confirmedBy,
    this.paidAt,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      paymentId: map['payment_id'] as String,
      billId: map['bill_id'] as String,
      patientId: map['patient_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String,
      status: map['status'] as String? ?? 'pending',
      transactionRef: map['transaction_ref'] as String?,
      confirmedBy: map['confirmed_by'] as String?,
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'payment_id': paymentId,
        'bill_id': billId,
        'patient_id': patientId,
        'amount': amount,
        'method': method,
        'status': status,
        'transaction_ref': transactionRef,
        'confirmed_by': confirmedBy,
        'paid_at': paidAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  bool get isSuccessful =>
      status == 'paid' || status == 'cash_confirmed';
}
