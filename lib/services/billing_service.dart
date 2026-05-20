import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/bill_model.dart';

// =============================================================================
// MediSlot v2 — Billing Service
// Handles consultation bill creation, payment status updates, and cash
// confirmation. UPI/card payments use mock success flow.
// =============================================================================

class BillingService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Create a bill after doctor saves prescription
  // ---------------------------------------------------------------------------
  Future<BillModel?> createBill({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required double amount,
  }) async {
    try {
      final response = await _db
          .from(AppConstants.tableConsultationBills)
          .insert({
            'appointment_id': appointmentId,
            'doctor_id': doctorId,
            'patient_id': patientId,
            'amount': amount,
            'payment_status': AppConstants.payPending,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return BillModel.fromMap(response);
    } catch (e) {
      print('❌ BillingService.createBill error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch bill for a given appointment
  // ---------------------------------------------------------------------------
  Future<BillModel?> getBillForAppointment(String appointmentId) async {
    try {
      final response = await _db
          .from(AppConstants.tableConsultationBills)
          .select()
          .eq('appointment_id', appointmentId)
          .maybeSingle();

      if (response == null) return null;
      return BillModel.fromMap(response);
    } catch (e) {
      print('❌ BillingService.getBillForAppointment error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch all bills with a specific payment status for a doctor
  // Used by assistant to list cash_pending bills
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getBillsByDoctorAndStatus({
    required String doctorId,
    required String status,
  }) async {
    try {
      final response = await _db
          .from(AppConstants.tableConsultationBills)
          .select('''
            bill_id, amount, payment_status, payment_method, created_at,
            appointments(appointment_date, appointment_time),
            patients(patient_id, name)
          ''')
          .eq('doctor_id', doctorId)
          .eq('payment_status', status)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ BillingService.getBillsByDoctorAndStatus error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Mock online payment (UPI / Card) — always succeeds after delay
  // Called after patient taps Pay in the payment screen.
  // ---------------------------------------------------------------------------
  Future<bool> mockOnlinePayment({
    required String billId,
    required String patientId,
    required double amount,
    required String method, // 'upi' | 'card'
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(AppConstants.mockPaymentDelay);

      final now = DateTime.now().toIso8601String();
      final mockRef =
          'MOCK-${method.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Insert payment record
      await _db.from(AppConstants.tablePayments).insert({
        'bill_id': billId,
        'patient_id': patientId,
        'amount': amount,
        'method': method,
        'status': AppConstants.payPaid,
        'transaction_ref': mockRef,
        'paid_at': now,
      });

      // 2. Update bill status to paid
      await _db
          .from(AppConstants.tableConsultationBills)
          .update({
            'payment_status': AppConstants.payPaid,
            'payment_method': method,
            'updated_at': now,
          })
          .eq('bill_id', billId);

      return true;
    } catch (e) {
      print('❌ BillingService.mockOnlinePayment error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Initiate cash payment — patient selects "Pay at Clinic"
  // Sets status to cash_pending and records method.
  // ---------------------------------------------------------------------------
  Future<bool> initiateCashPayment({
    required String billId,
    required String patientId,
    required double amount,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Insert payment record
      await _db.from(AppConstants.tablePayments).insert({
        'bill_id': billId,
        'patient_id': patientId,
        'amount': amount,
        'method': AppConstants.methodCash,
        'status': AppConstants.payCashPending,
      });

      // 2. Update bill status
      await _db
          .from(AppConstants.tableConsultationBills)
          .update({
            'payment_status': AppConstants.payCashPending,
            'payment_method': AppConstants.methodCash,
            'updated_at': now,
          })
          .eq('bill_id', billId);

      return true;
    } catch (e) {
      print('❌ BillingService.initiateCashPayment error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Confirm cash payment — called by doctor or assistant at clinic
  // Marks bill as cash_confirmed and records confirming user.
  // ---------------------------------------------------------------------------
  Future<bool> confirmCashPayment({
    required String billId,
    required String confirmedByUserId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Update payment record
      await _db
          .from(AppConstants.tablePayments)
          .update({
            'status': AppConstants.payCashConfirmed,
            'confirmed_by': confirmedByUserId,
            'paid_at': now,
          })
          .eq('bill_id', billId)
          .eq('status', AppConstants.payCashPending);

      // 2. Update bill status
      await _db
          .from(AppConstants.tableConsultationBills)
          .update({
            'payment_status': AppConstants.payCashConfirmed,
            'updated_at': now,
          })
          .eq('bill_id', billId);

      return true;
    } catch (e) {
      print('❌ BillingService.confirmCashPayment error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Waive payment — doctor can waive consultation fee
  // ---------------------------------------------------------------------------
  Future<bool> waivePayment(String billId) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _db
          .from(AppConstants.tableConsultationBills)
          .update({
            'payment_status': AppConstants.payWaived,
            'updated_at': now,
          })
          .eq('bill_id', billId);
      return true;
    } catch (e) {
      print('❌ BillingService.waivePayment error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch all bills for admin overview
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllBillsForAdmin({
    String? statusFilter,
    int limit = 50,
  }) async {
    try {
      var query = _db
          .from(AppConstants.tableConsultationBills)
          .select('''
            bill_id, amount, payment_status, payment_method, created_at,
            doctors(doctor_id, profiles(name)),
            patients(patient_id, name)
          ''');

      if (statusFilter != null) {
        query = query.eq('payment_status', statusFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ BillingService.getAllBillsForAdmin error: $e');
      return [];
    }
  }
}
