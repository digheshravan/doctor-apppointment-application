import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/queue_token_model.dart';

// =============================================================================
// MediSlot v2 — Queue Service
// Manages patient queue tokens: create, advance states, and stream live updates.
// =============================================================================

class QueueService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Create a queue token on patient check-in
  // Auto-assigns the next token number for the doctor today.
  // ---------------------------------------------------------------------------
  Future<QueueTokenModel?> createToken({
    required String appointmentId,
    required String doctorId,
    String? clinicId,
  }) async {
    try {
      // Get today's highest token number for this doctor
      final today = DateTime.now().toIso8601String().split('T').first;
      final existing = await _db
          .from(AppConstants.tableQueueTokens)
          .select('token_number')
          .eq('doctor_id', doctorId)
          .gte('created_at', '${today}T00:00:00')
          .order('token_number', ascending: false)
          .limit(1);

      int nextToken = 1;
      if (existing.isNotEmpty) {
        nextToken = ((existing.first['token_number'] as int?) ?? 0) + 1;
      }

      final response = await _db
          .from(AppConstants.tableQueueTokens)
          .insert({
            'appointment_id': appointmentId,
            'doctor_id': doctorId,
            'clinic_id': clinicId,
            'token_number': nextToken,
            'state': AppConstants.queueWaiting,
            'checked_in_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return QueueTokenModel.fromMap(response);
    } catch (e) {
      print('❌ QueueService.createToken error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Get a token by appointment ID
  // ---------------------------------------------------------------------------
  Future<QueueTokenModel?> getTokenForAppointment(
      String appointmentId) async {
    try {
      final response = await _db
          .from(AppConstants.tableQueueTokens)
          .select()
          .eq('appointment_id', appointmentId)
          .maybeSingle();

      if (response == null) return null;
      return QueueTokenModel.fromMap(response);
    } catch (e) {
      print('❌ QueueService.getTokenForAppointment error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Advance a token: waiting → active → completed
  // ---------------------------------------------------------------------------
  Future<bool> advanceToken(String tokenId) async {
    try {
      final current = await _db
          .from(AppConstants.tableQueueTokens)
          .select('state')
          .eq('token_id', tokenId)
          .single();

      final currentState = current['state'] as String;
      String nextState;
      Map<String, dynamic> updateData = {};

      switch (currentState) {
        case 'waiting':
          nextState = AppConstants.queueActive;
          break;
        case 'active':
          nextState = AppConstants.queueCompleted;
          updateData['completed_at'] = DateTime.now().toIso8601String();
          break;
        default:
          return false; // already completed or missed
      }

      await _db
          .from(AppConstants.tableQueueTokens)
          .update({'state': nextState, ...updateData})
          .eq('token_id', tokenId);

      return true;
    } catch (e) {
      print('❌ QueueService.advanceToken error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Mark a token as missed (patient didn't show up when called)
  // ---------------------------------------------------------------------------
  Future<bool> markMissed(String tokenId) async {
    try {
      await _db
          .from(AppConstants.tableQueueTokens)
          .update({'state': AppConstants.queueMissed})
          .eq('token_id', tokenId);
      return true;
    } catch (e) {
      print('❌ QueueService.markMissed error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch today's queue for a doctor (all tokens, ordered by number)
  // ---------------------------------------------------------------------------
  Future<List<QueueTokenModel>> getTodayQueue(String doctorId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _db
          .from(AppConstants.tableQueueTokens)
          .select('''
            *,
            appointments(
              appointment_id,
              patients(name, age, gender)
            )
          ''')
          .eq('doctor_id', doctorId)
          .gte('created_at', '${today}T00:00:00')
          .order('token_number');

      return (response as List)
          .map((e) => QueueTokenModel.fromMap(e))
          .toList();
    } catch (e) {
      print('❌ QueueService.getTodayQueue error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Supabase Realtime stream — live queue board for a doctor
  // Usage: QueueService().queueStream(doctorId).listen((tokens) { ... })
  // ---------------------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> queueStream(String doctorId) {
    return _db
        .from(AppConstants.tableQueueTokens)
        .stream(primaryKey: ['token_id'])
        .eq('doctor_id', doctorId)
        .order('token_number');
  }

  // ---------------------------------------------------------------------------
  // Get current active token number for display
  // ---------------------------------------------------------------------------
  Future<int?> getCurrentActiveToken(String doctorId) async {
    try {
      final response = await _db
          .from(AppConstants.tableQueueTokens)
          .select('token_number')
          .eq('doctor_id', doctorId)
          .eq('state', AppConstants.queueActive)
          .maybeSingle();

      return response?['token_number'] as int?;
    } catch (e) {
      return null;
    }
  }
}
