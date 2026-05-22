// =============================================================================
// MediSlot v2 — App Constants
// All shared string keys, enums, and config values.
// =============================================================================

class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------------
  // Supabase Table Names
  // ---------------------------------------------------------------------------
  static const String tableProfiles = 'profiles';
  static const String tableDoctors = 'doctors';
  static const String tablePatients = 'patients';
  static const String tableAssistants = 'assistants';
  static const String tableClinics = 'clinics';
  static const String tableAppointments = 'appointments';
  static const String tableAppointmentSlots = 'appointment_slots';
  static const String tablePrescriptions = 'prescriptions';
  static const String tablePrescriptionMedicines = 'prescription_medicines';
  static const String tableNotifications = 'notifications';
  static const String tableConsultationBills = 'consultation_bills';
  static const String tablePayments = 'payments';
  static const String tableQueueTokens = 'queue_tokens';
  static const String tableScheduleTemplates = 'doctor_schedule_templates';
  static const String tableDoctorReviews = 'doctor_reviews';

  // ---------------------------------------------------------------------------
  // Supabase Storage Buckets
  // ---------------------------------------------------------------------------
  static const String bucketDoctorPhotos = 'doctor-photos';
  static const String bucketPrescriptions = 'prescription-pdfs';
  static const String bucketReports = 'reports';

  // ---------------------------------------------------------------------------
  // User Roles
  // ---------------------------------------------------------------------------
  static const String rolePatient = 'patient';
  static const String roleDoctor = 'doctor';
  static const String roleAssistant = 'assistant';
  static const String roleAdmin = 'admin';

  // ---------------------------------------------------------------------------
  // Appointment Statuses
  // ---------------------------------------------------------------------------
  static const String apptPending = 'pending';
  static const String apptAccepted = 'accepted';
  static const String apptRejected = 'rejected';
  static const String apptCancelled = 'cancelled';
  static const String apptRescheduled = 'rescheduled';

  // ---------------------------------------------------------------------------
  // Visit Statuses
  // ---------------------------------------------------------------------------
  static const String visitInactive = 'inactive';
  static const String visitActive = 'active';
  static const String visitCompleted = 'completed';

  // ---------------------------------------------------------------------------
  // Payment Statuses
  // ---------------------------------------------------------------------------
  static const String payPending = 'pending';
  static const String payProcessing = 'processing';
  static const String payPaid = 'paid';
  static const String payFailed = 'failed';
  static const String payCashPending = 'cash_pending';
  static const String payCashConfirmed = 'cash_confirmed';
  static const String payWaived = 'waived';

  /// Returns true if prescription PDF should be unlocked for this payment status.
  static bool isPrescriptionUnlocked(String? paymentStatus) {
    return paymentStatus == payPaid ||
        paymentStatus == payCashConfirmed ||
        paymentStatus == payWaived;
  }

  // ---------------------------------------------------------------------------
  // Payment Methods
  // ---------------------------------------------------------------------------
  static const String methodUpi = 'upi';
  static const String methodCard = 'card';
  static const String methodCash = 'cash';

  // ---------------------------------------------------------------------------
  // Queue / Token States
  // ---------------------------------------------------------------------------
  static const String queueWaiting = 'waiting';
  static const String queueActive = 'active';
  static const String queueCompleted = 'completed';
  static const String queueMissed = 'missed';

  // ---------------------------------------------------------------------------
  // Notification Types
  // ---------------------------------------------------------------------------
  static const String notifAppointment = 'appointment';
  static const String notifPayment = 'payment';
  static const String notifPrescription = 'prescription';
  static const String notifReminder = 'reminder';
  static const String notifReschedule = 'reschedule';

  // ---------------------------------------------------------------------------
  // SharedPreferences Keys (v2 additions)
  // ---------------------------------------------------------------------------
  static const String prefUnreadNotifCount = 'unread_notif_count';

  // ---------------------------------------------------------------------------
  // Mock Payment Config
  // ---------------------------------------------------------------------------
  /// Duration of the fake payment loading animation.
  static const Duration mockPaymentDelay = Duration(seconds: 2);
}
