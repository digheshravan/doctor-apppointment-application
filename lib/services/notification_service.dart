import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';

// =============================================================================
// MediSlot v2 — Notification Service
// In-app notifications via Supabase Realtime.
// Push/SMS/WhatsApp deferred to v3.
// =============================================================================

class NotificationService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Insert a notification for a user
  // ---------------------------------------------------------------------------
  Future<void> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? referenceId,
  }) async {
    try {
      await _db.from(AppConstants.tableNotifications).insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'reference_id': referenceId,
        'is_read': false,
      });
    } catch (e) {
      print('❌ NotificationService.send error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch all notifications for the current user (ordered newest first)
  // ---------------------------------------------------------------------------
  Future<List<NotificationModel>> fetchForCurrentUser() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _db
          .from(AppConstants.tableNotifications)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((e) => NotificationModel.fromMap(e))
          .toList();
    } catch (e) {
      print('❌ NotificationService.fetchForCurrentUser error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Count unread notifications for the current user
  // ---------------------------------------------------------------------------
  Future<int> unreadCount() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _db
          .from(AppConstants.tableNotifications)
          .select('notification_id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('❌ NotificationService.unreadCount error: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Mark a single notification as read
  // ---------------------------------------------------------------------------
  Future<void> markRead(String notificationId) async {
    try {
      await _db
          .from(AppConstants.tableNotifications)
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } catch (e) {
      print('❌ NotificationService.markRead error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Mark all notifications as read for current user
  // ---------------------------------------------------------------------------
  Future<void> markAllRead() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;

      await _db
          .from(AppConstants.tableNotifications)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('❌ NotificationService.markAllRead error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Supabase Realtime stream for current user's notifications
  // Usage: NotificationService().stream().listen((notifs) { ... })
  // ---------------------------------------------------------------------------
  Stream<List<NotificationModel>> stream() {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _db
        .from(AppConstants.tableNotifications)
        .stream(primaryKey: ['notification_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) =>
            rows.map((e) => NotificationModel.fromMap(e)).toList());
  }

  // ---------------------------------------------------------------------------
  // Pre-built notification senders (called from other services/screens)
  // ---------------------------------------------------------------------------

  Future<void> notifyAppointmentAccepted({
    required String patientUserId,
    required String appointmentId,
    required String doctorName,
    required String date,
  }) =>
      send(
        userId: patientUserId,
        title: 'Appointment Accepted ✅',
        body: 'Dr. $doctorName has accepted your appointment on $date.',
        type: AppConstants.notifAppointment,
        referenceId: appointmentId,
      );

  Future<void> notifyAppointmentRejected({
    required String patientUserId,
    required String appointmentId,
    required String doctorName,
  }) =>
      send(
        userId: patientUserId,
        title: 'Appointment Rejected',
        body: 'Dr. $doctorName could not accept your appointment. Please try a different slot.',
        type: AppConstants.notifAppointment,
        referenceId: appointmentId,
      );

  Future<void> notifyPaymentPending({
    required String patientUserId,
    required String billId,
    required double amount,
    required String doctorName,
  }) =>
      send(
        userId: patientUserId,
        title: 'Payment Pending 💳',
        body: 'Your consultation bill of ₹${amount.toStringAsFixed(0)} for Dr. $doctorName is awaiting payment.',
        type: AppConstants.notifPayment,
        referenceId: billId,
      );

  Future<void> notifyPaymentConfirmed({
    required String patientUserId,
    required String billId,
    required double amount,
  }) =>
      send(
        userId: patientUserId,
        title: 'Payment Confirmed ✅',
        body: 'Your payment of ₹${amount.toStringAsFixed(0)} has been confirmed.',
        type: AppConstants.notifPayment,
        referenceId: billId,
      );

  Future<void> notifyPrescriptionReady({
    required String patientUserId,
    required String prescriptionId,
    required String doctorName,
  }) =>
      send(
        userId: patientUserId,
        title: 'Prescription Ready 📋',
        body: 'Your prescription from Dr. $doctorName is ready. Download it now.',
        type: AppConstants.notifPrescription,
        referenceId: prescriptionId,
      );

  Future<void> notifyRescheduleUpdate({
    required String patientUserId,
    required String appointmentId,
    required String message,
  }) =>
      send(
        userId: patientUserId,
        title: 'Reschedule Update 🔄',
        body: message,
        type: AppConstants.notifReschedule,
        referenceId: appointmentId,
      );
}
