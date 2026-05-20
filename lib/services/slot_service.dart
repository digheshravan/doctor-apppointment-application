import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

// =============================================================================
// MediSlot v2 — Slot Service
// Clinic-wise slot management and schedule template operations.
// =============================================================================

class SlotService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Fetch available slots for a doctor (optionally filtered by clinic)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAvailableSlots({
    required String doctorId,
    String? clinicId,
    String? date,
  }) async {
    try {
      var query = _db
          .from(AppConstants.tableAppointmentSlots)
          .select()
          .eq('doctor_id', doctorId)
          .eq('status', 'open');

      if (clinicId != null) {
        query = query.eq('clinic_id', clinicId);
      }
      if (date != null) {
        query = query.eq('slot_date', date);
      }

      final response = await query.order('slot_date').order('start_time');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ SlotService.getAvailableSlots error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch all slots for a doctor on a specific date (all statuses)
  // Used by doctor/assistant management screens
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllSlotsForDate({
    required String doctorId,
    required String date,
    String? clinicId,
  }) async {
    try {
      var query = _db
          .from(AppConstants.tableAppointmentSlots)
          .select('''
            slot_id, slot_date, start_time, end_time,
            slot_limit, booked_count, status, clinic_id,
            clinics(clinic_id, name)
          ''')
          .eq('doctor_id', doctorId)
          .eq('slot_date', date);

      if (clinicId != null) {
        query = query.eq('clinic_id', clinicId);
      }

      final response = await query.order('start_time');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ SlotService.getAllSlotsForDate error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Create a single slot
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> createSlot({
    required String doctorId,
    required String slotDate,
    required String startTime,
    required String endTime,
    required int slotLimit,
    String? clinicId,
  }) async {
    try {
      final response = await _db
          .from(AppConstants.tableAppointmentSlots)
          .insert({
            'doctor_id': doctorId,
            'slot_date': slotDate,
            'start_time': startTime,
            'end_time': endTime,
            'slot_limit': slotLimit,
            'booked_count': 0,
            'status': 'open',
            'clinic_id': clinicId,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ SlotService.createSlot error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch all schedule templates for a doctor
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getScheduleTemplates(
      String doctorId) async {
    try {
      final response = await _db
          .from(AppConstants.tableScheduleTemplates)
          .select('''
            template_id, day_of_week, start_time, end_time,
            slot_duration_minutes, slot_limit, is_active, clinic_id,
            clinics(name)
          ''')
          .eq('doctor_id', doctorId)
          .eq('is_active', true)
          .order('day_of_week');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ SlotService.getScheduleTemplates error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Create a weekly schedule template
  // ---------------------------------------------------------------------------
  Future<bool> createTemplate({
    required String doctorId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required int slotDurationMinutes,
    required int slotLimit,
    String? clinicId,
  }) async {
    try {
      await _db.from(AppConstants.tableScheduleTemplates).insert({
        'doctor_id': doctorId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'slot_duration_minutes': slotDurationMinutes,
        'slot_limit': slotLimit,
        'is_active': true,
        'clinic_id': clinicId,
      });
      return true;
    } catch (e) {
      print('❌ SlotService.createTemplate error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Generate slots for a specific date from matching templates
  // Returns number of slots created.
  // ---------------------------------------------------------------------------
  Future<int> generateSlotsFromTemplates({
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final dayOfWeek = date.weekday - 1; // Mon=0, Sun=6
      final dateStr = date.toIso8601String().split('T').first;

      final templates = await _db
          .from(AppConstants.tableScheduleTemplates)
          .select()
          .eq('doctor_id', doctorId)
          .eq('day_of_week', dayOfWeek)
          .eq('is_active', true);

      if (templates.isEmpty) return 0;

      int created = 0;
      for (final template in templates as List) {
        final startParts =
            (template['start_time'] as String).split(':');
        final endParts = (template['end_time'] as String).split(':');
        final duration =
            template['slot_duration_minutes'] as int? ?? 15;

        var current = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );
        final end = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        while (current.isBefore(end)) {
          final slotEnd = current.add(Duration(minutes: duration));
          if (slotEnd.isAfter(end)) break;

          final startStr =
              '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}:00';
          final endStr =
              '${slotEnd.hour.toString().padLeft(2, '0')}:${slotEnd.minute.toString().padLeft(2, '0')}:00';

          // Avoid duplicate slots
          final existing = await _db
              .from(AppConstants.tableAppointmentSlots)
              .select('slot_id')
              .eq('doctor_id', doctorId)
              .eq('slot_date', dateStr)
              .eq('start_time', startStr)
              .maybeSingle();

          if (existing == null) {
            await _db.from(AppConstants.tableAppointmentSlots).insert({
              'doctor_id': doctorId,
              'slot_date': dateStr,
              'start_time': startStr,
              'end_time': endStr,
              'slot_limit': template['slot_limit'] ?? 1,
              'booked_count': 0,
              'status': 'open',
              'clinic_id': template['clinic_id'],
            });
            created++;
          }
          current = slotEnd;
        }
      }

      return created;
    } catch (e) {
      print('❌ SlotService.generateSlotsFromTemplates error: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a template (soft-delete via is_active = false)
  // ---------------------------------------------------------------------------
  Future<bool> deactivateTemplate(String templateId) async {
    try {
      await _db
          .from(AppConstants.tableScheduleTemplates)
          .update({'is_active': false})
          .eq('template_id', templateId);
      return true;
    } catch (e) {
      print('❌ SlotService.deactivateTemplate error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Get all clinics assigned to a doctor (for clinic-wise filtering)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getDoctorClinics(
      String doctorId) async {
    try {
      final response = await _db
          .from('doctor_clinics')
          .select('clinic_id, clinics(clinic_id, name, address)')
          .eq('doctor_id', doctorId);

      return List<Map<String, dynamic>>.from(
          (response as List).map((e) => e['clinics'] as Map<String, dynamic>));
    } catch (e) {
      print('❌ SlotService.getDoctorClinics error: $e');
      return [];
    }
  }
}
