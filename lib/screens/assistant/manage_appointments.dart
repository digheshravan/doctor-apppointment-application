import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Import for date/time formatting
import 'package:shimmer/shimmer.dart'; // Import for loading shimmer

class ManageAppointmentsPage extends StatefulWidget {
  const ManageAppointmentsPage({super.key});

  @override
  State<ManageAppointmentsPage> createState() => _ManageAppointmentsPageState();
}

class _ManageAppointmentsPageState extends State<ManageAppointmentsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;

  // --- UI Colors from UploadSlotsPage/CheckInScreen Theme ---
  static const Color primaryColor = Color(0xFF00AEEF); // Main blue
  static const Color accentColor = Color(0xFF4CAF50); // Green
  static const Color backgroundColor = Color(0xFFF8F9FA); // Off-white
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  // --- End Theme Colors ---

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  // --- NO CHANGES TO BACKEND LOGIC ---
  Future<void> fetchAppointments() async {
    try {
      final response = await supabase
          .from('appointments')
          .select('''
            appointment_id,
            appointment_date,
            appointment_time,
            status,
            reason,
            patients(name),
            doctors(
              specialization,
              profiles(name)
            )
          ''')
          .order('appointment_date');

      if (mounted) {
        setState(() {
          appointments = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> updateStatus(String appointmentId, String status) async {
    try {
      // 1️⃣ Get appointment details first (including slot_id)
      final appointmentData = await supabase
          .from('appointments')
          .select('slot_id')
          .eq('appointment_id', appointmentId)
          .maybeSingle();

      final slotId = appointmentData?['slot_id'];

      // 2️⃣ Update appointment status
      await supabase
          .from('appointments')
          .update({'status': status})
          .eq('appointment_id', appointmentId);

      // 3️⃣ Update the corresponding slot
      if (slotId != null) {
        final slotData = await supabase
            .from('appointment_slots')
            .select('booked_count, slot_limit')
            .eq('slot_id', slotId)
            .maybeSingle();

        if (slotData != null) {
          int bookedCount = slotData['booked_count'] ?? 0;
          int slotLimit = slotData['slot_limit'] ?? 1;

          if (status == 'accepted') {
            bookedCount = (bookedCount + 1).clamp(0, slotLimit);
            await supabase.from('appointment_slots').update({
              'booked_count': bookedCount,
              'status': 'closed', // block others from booking
            }).eq('slot_id', slotId);
          } else if (status == 'rejected') {
            await supabase.from('appointment_slots').update({
              'booked_count': 0,
              'status': 'open', // free slot for others
            }).eq('slot_id', slotId);
          }
        }
      }

      // 4️⃣ Refresh UI
      fetchAppointments();
    } catch (e) {
      debugPrint("Error updating appointment status: $e");
    }
  }
  // --- END OF BACKEND LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor, // Use new theme color
      appBar: AppBar( // New AppBar style from UploadSlotsPage
        backgroundColor: backgroundColor,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_outlined, // Changed icon
                  color: primaryColor,
                  size: 30),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Appointments', // Changed title
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Manage all appointments', // Changed subtitle
                  style: TextStyle(
                    color: lightTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: isLoading
          ? _buildShimmerList() // Use shimmer list
          : appointments.isEmpty
          ? const Center(child: Text("No appointments found"))
          : ListView.builder(
        padding:
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appt = appointments[index];
          return _buildAppointmentCard(appt);
        },
      ),
    );
  }

  // --- WIDGETS REMOVED ---
  // _buildAppBar() was removed
  // _buildActionTabs() was removed

  /// Builds the shimmer placeholder list
  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      itemCount: 5, // Show 5 placeholder cards
      itemBuilder: (context, index) => const _ShimmerAppointmentCard(),
    );
  }

  /// Builds the new appointment card UI
  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final status = appt['status'];
    final isPending = status == 'pending';

    // Format date and time
    String formattedDate = "Invalid Date";
    String formattedTime = "Invalid Time";

    try {
      formattedDate = DateFormat('MMM dd, yyyy')
          .format(DateTime.parse(appt['appointment_date']));
    } catch (e) {
      debugPrint("Error formatting date: $e");
    }

    try {
      formattedTime = DateFormat('h:mm a')
          .format(DateFormat('HH:mm:ss').parse(appt['appointment_time']));
    } catch (e) {
      debugPrint("Error formatting time: $e");
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white, // Use white
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.1), // Use new theme color
                child: const Icon(Icons.person_outline, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt['patients']['name'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor, // Use new theme color
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const Divider(height: 24.0),
          Row(
            children: [
              _iconText(Icons.calendar_today_outlined, formattedDate),
              const SizedBox(width: 16),
              _iconText(Icons.access_time_outlined, formattedTime),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            _buildActionButtons(appt),
          ],
        ],
      ),
    );
  }

  /// Helper widget for icons with text (Date, Time)
  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: lightTextColor, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: lightTextColor, fontSize: 13),
        ),
      ],
    );
  }

  /// Helper widget for the status chip
  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'pending':
        backgroundColor = const Color(0xFFFEF3C7); // Yellow
        textColor = const Color(0xFF9A3412);
        break;
      case 'confirmed':
      case 'accepted': // Adding 'accepted' as well
        backgroundColor = const Color(0xFFDCFCE7); // Green
        textColor = const Color(0xFF166534);
        break;
      case 'cancelled':
      case 'rejected': // Adding 'rejected' as well
        backgroundColor = const Color(0xFFF1F5F9); // Grey
        textColor = const Color(0xFF334155);
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Helper widget for the Accept/Reject buttons
  Widget _buildActionButtons(Map<String, dynamic> appt) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => updateStatus(appt['appointment_id'], 'accepted'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor, // Use new theme color
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => updateStatus(appt['appointment_id'], 'rejected'),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor, // Use new theme color
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    );
  }
}

/// Shimmer placeholder for the appointment card
class _ShimmerAppointmentCard extends StatelessWidget {
  const _ShimmerAppointmentCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  height: 24,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
              ],
            ),
            const Divider(height: 24.0),
            Row(
              children: [
                Container(
                  height: 14,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 14,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}