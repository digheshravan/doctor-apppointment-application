import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/review_model.dart';

// =============================================================================
// MediSlot v2 — Review Service
// Submit, fetch, and aggregate doctor reviews.
// One review per completed + paid appointment (enforced by DB unique constraint).
// =============================================================================

class ReviewService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Submit a review for a completed, paid appointment
  // Returns the created ReviewModel or null on failure (e.g., duplicate).
  // ---------------------------------------------------------------------------
  Future<ReviewModel?> submitReview({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _db
          .from(AppConstants.tableDoctorReviews)
          .insert({
            'appointment_id': appointmentId,
            'doctor_id': doctorId,
            'patient_id': patientId,
            'rating': rating,
            'comment': comment,
          })
          .select()
          .single();

      return ReviewModel.fromMap(response);
    } on PostgrestException catch (e) {
      // Duplicate review — unique constraint violation
      if (e.code == '23505') {
        print('ℹ️ ReviewService: Review already exists for this appointment.');
      } else {
        print('❌ ReviewService.submitReview error: $e');
      }
      return null;
    } catch (e) {
      print('❌ ReviewService.submitReview error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Check if a review already exists for a given appointment
  // ---------------------------------------------------------------------------
  Future<bool> hasReview(String appointmentId) async {
    try {
      final response = await _db
          .from(AppConstants.tableDoctorReviews)
          .select('review_id')
          .eq('appointment_id', appointmentId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch all reviews for a doctor (with patient name)
  // ---------------------------------------------------------------------------
  Future<List<ReviewModel>> getReviewsForDoctor(String doctorId) async {
    try {
      final response = await _db
          .from(AppConstants.tableDoctorReviews)
          .select('*, patients(name)')
          .eq('doctor_id', doctorId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => ReviewModel.fromMap(e))
          .toList();
    } catch (e) {
      print('❌ ReviewService.getReviewsForDoctor error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Get average rating for a doctor (returns 0.0 if no reviews)
  // ---------------------------------------------------------------------------
  Future<double> getAverageRating(String doctorId) async {
    try {
      final response = await _db
          .from(AppConstants.tableDoctorReviews)
          .select('rating')
          .eq('doctor_id', doctorId);

      final list = response as List;
      if (list.isEmpty) return 0.0;

      final total = list.fold<int>(
          0, (sum, row) => sum + (row['rating'] as int? ?? 0));
      return total / list.length;
    } catch (e) {
      return 0.0;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch review counts and avg for admin dashboard
  // Returns a list of {doctor_id, avg_rating, count}
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getDoctorRatingSummary() async {
    try {
      final response = await _db
          .from(AppConstants.tableDoctorReviews)
          .select('doctor_id, rating, doctors(profiles(name))');

      final Map<String, List<int>> grouped = {};
      for (final row in response as List) {
        final doctorId = row['doctor_id'] as String;
        grouped.putIfAbsent(doctorId, () => []);
        grouped[doctorId]!.add(row['rating'] as int);
      }

      return grouped.entries.map((entry) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        return {
          'doctor_id': entry.key,
          'avg_rating': double.parse(avg.toStringAsFixed(1)),
          'count': entry.value.length,
        };
      }).toList()
        ..sort((a, b) =>
            (b['avg_rating'] as double).compareTo(a['avg_rating'] as double));
    } catch (e) {
      print('❌ ReviewService.getDoctorRatingSummary error: $e');
      return [];
    }
  }
}
