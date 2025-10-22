import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

// -----------------------------------------------------------------------------
// Data Models
// -----------------------------------------------------------------------------
enum AppointmentStatus { Confirmed, Pending, Rejected, Cancelled }

class Appointment {
  final String name;
  final String time;
  final String type;
  final AppointmentStatus status;
  final String appointmentId;

  Appointment({
    required this.name,
    required this.time,
    required this.type,
    required this.status,
    required this.appointmentId,
  });
}

enum SlotType { Available, Emergency }

class AvailableSlot {
  final String time;
  final SlotType type;
  AvailableSlot({required this.time, required this.type});
}

// -----------------------------------------------------------------------------
// Appointments Screen Widget
// -----------------------------------------------------------------------------
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookedAppointments = [];
  bool _isLoading = true;
  late TabController _tabController;

  Future<void> _fetchAppointmentsForDate(DateTime date) async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 750));

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String? doctorId = await _authService.getCurrentDoctorId();
    doctorId ??= await _authService.getAssignedDoctorIdForAssistant();

    if (doctorId == null) {
      debugPrint("⚠️ No doctor or assigned doctor found.");
      setState(() => _isLoading = false);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final response = await Supabase.instance.client
        .from('appointments')
        .select('appointment_id, status, reason, appointment_time, patients!inner(name)')
        .eq('doctor_id', doctorId)
        .eq('appointment_date', dateStr)
        .inFilter('status', ['pending', 'confirmed', 'accepted', 'rejected', 'cancelled']);

    if (response is List) {
      setState(() {
        _bookedAppointments = response.map<Map<String, dynamic>>((row) {
          final patient = row['patients'] ?? {};
          return {
            'id': row['appointment_id'],
            'name': patient['name'] ?? 'Unknown',
            'time': row['appointment_time'] ?? 'N/A',
            'reason': row['reason'] ?? 'No reason provided',
            'status': row['status'] ?? 'pending',
          };
        }).toList();
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAppointmentsForDate(_selectedDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appointments',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24)),
            Text('Manage your schedule',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            AppointmentControls(
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
                _fetchAppointmentsForDate(date);
              },
            ),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  BookedAppointmentsTab(
                    appointments: _bookedAppointments,
                    isLoading: _isLoading,
                    onRefresh: () => _fetchAppointmentsForDate(_selectedDate),
                  ),
                  AvailableSlotsTab(
                    selectedDate: _selectedDate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(5),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF0D47A1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              )
            ]),
        labelColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelColor: Colors.black54,
        tabs: const [
          Tab(text: 'Booked'),
          Tab(text: 'Available Slots'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Stateful Widget for Date Picker Controls
// -----------------------------------------------------------------------------
class AppointmentControls extends StatefulWidget {
  final ValueChanged<DateTime> onDateChanged;
  const AppointmentControls({super.key, required this.onDateChanged});

  @override
  State<AppointmentControls> createState() => _AppointmentControlsState();
}

class _AppointmentControlsState extends State<AppointmentControls> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      widget.onDateChanged(_selectedDate);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay == today) {
      return 'Today';
    } else if (selectedDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_today_outlined,
                size: 20, color: Colors.black87),
            label: Text(_formatDate(_selectedDate),
                style: const TextStyle(fontSize: 16, color: Colors.black87)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF50D1AA),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tab Content Widgets
// -----------------------------------------------------------------------------
class BookedAppointmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> appointments;
  final bool isLoading;
  final Future<void> Function()? onRefresh;

  const BookedAppointmentsTab({
    super.key,
    required this.appointments,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (context, index) => const _ShimmerAppointmentCard(),
        ),
      );
    }

    if (appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 250),
            Center(child: Text("No appointments found for this date.")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: Colors.blue,
      backgroundColor: Colors.white,
      child: ListView.builder(
        controller: ScrollController(),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointmentData = appointments[index];

          final appointment = Appointment(
            name: appointmentData['name'] ?? 'Unknown Patient',
            time: appointmentData['time'] ?? 'No Time',
            type: appointmentData['reason'] ?? 'Consultation',
            appointmentId: appointmentData['id'],
            status: _getAppointmentStatus(appointmentData['status']),
          );

          return AppointmentCard(
            appointment: appointment,
            onStatusUpdated: onRefresh,
          );
        },
      ),
    );
  }

  AppointmentStatus _getAppointmentStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'rejected':
        return AppointmentStatus.Rejected;
      case 'confirmed':
      case 'accepted':
        return AppointmentStatus.Confirmed;
      case 'cancelled':
        return AppointmentStatus.Cancelled;
      default:
        return AppointmentStatus.Pending;
    }
  }
}

class AvailableSlotsTab extends StatefulWidget {
  final DateTime selectedDate;
  const AvailableSlotsTab({super.key, required this.selectedDate});

  @override
  State<AvailableSlotsTab> createState() => _AvailableSlotsTabState();
}

class _AvailableSlotsTabState extends State<AvailableSlotsTab> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _slots = [];

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String? doctorId = await _authService.getCurrentDoctorId();
    doctorId ??= await _authService.getAssignedDoctorIdForAssistant();

    if (doctorId == null) {
      debugPrint("⚠️ No doctor or assistant found.");
      setState(() => _isLoading = false);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    final response = await Supabase.instance.client
        .from('appointment_slots')
        .select('slot_id, slot_time, status, slot_limit, booked_count')
        .eq('doctor_id', doctorId)
        .eq('slot_date', dateStr)
        .order('slot_time', ascending: true);

    if (response is List) {
      setState(() {
        _slots = response
            .map<Map<String, dynamic>>((slot) => {
          'id': slot['slot_id'],
          'time': slot['slot_time'] ?? 'N/A',
          'status': slot['status'] ?? 'open',
          'limit': slot['slot_limit'] ?? 1,
          'booked': slot['booked_count'] ?? 0,
        })
            .toList();
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (context, index) => const _ShimmerAppointmentCard(),
        ),
      );
    }

    if (_slots.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchSlots,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 250),
            Center(child: Text("No slots available for this date.")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSlots,
      child: ListView.builder(
        itemCount: _slots.length,
        itemBuilder: (context, index) {
          final slot = _slots[index];
          final slotTime = slot['time'];
          final status = slot['status'];
          final booked = slot['booked'];
          final limit = slot['limit'];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: status == 'open'
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Icon(
                  Icons.access_time,
                  color: status == 'open'
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
              title: Text(
                DateFormat('hh:mm a')
                    .format(DateFormat('HH:mm:ss').parse(slotTime)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Status: ${status.toUpperCase()} | Booked: $booked/$limit",
                style: TextStyle(
                  color: status == 'open'
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  await Supabase.instance.client
                      .from('appointment_slots')
                      .delete()
                      .eq('slot_id', slot['id']);
                  _fetchSlots();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Card & Helper Widgets
// -----------------------------------------------------------------------------

class _ShimmerAppointmentCard extends StatelessWidget {
  const _ShimmerAppointmentCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 16, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 14, color: Colors.white),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                    width: 100,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20))),
                const SizedBox(width: 8),
                Container(
                    width: 80,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentCard extends StatefulWidget {
  final Appointment appointment;
  final VoidCallback? onStatusUpdated;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onStatusUpdated,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _isUpdating = false;

  Future<void> _updateAppointmentStatus(String newStatus) async {
    try {
      setState(() => _isUpdating = true);

      final supabase = Supabase.instance.client;

      await supabase
          .from('appointments')
          .update({'status': newStatus}).eq(
          'appointment_id', widget.appointment.appointmentId);

      if (newStatus == 'rejected') {
        final appointmentDetails = await supabase
            .from('appointments')
            .select('doctor_id, appointment_date, appointment_time')
            .eq('appointment_id', widget.appointment.appointmentId)
            .maybeSingle();

        if (appointmentDetails != null) {
          final doctorId = appointmentDetails['doctor_id'];
          final date = appointmentDetails['appointment_date'];
          final time = appointmentDetails['appointment_time'];

          await supabase.from('appointment_slots').update({
            'status': 'open',
            'booked_count': 0,
          }).eq('doctor_id', doctorId).eq('slot_date', date).eq(
              'slot_time', time);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Appointment ${newStatus == 'accepted' ? 'approved' : newStatus}')),
        );
      }
      widget.onStatusUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating appointment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showCancelConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Appointment'),
          content:
          const Text('Are you sure you want to cancel this appointment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _cancelAppointment();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelAppointment() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canceling appointment...')),
        );
      }

      await Supabase.instance.client
          .from('appointments')
          .update({'status': 'cancelled'}).eq(
          'appointment_id', widget.appointment.appointmentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onStatusUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel appointment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPending = widget.appointment.status == AppointmentStatus.Pending;
    bool isAccepted = widget.appointment.status == AppointmentStatus.Confirmed;

    return Card(
      elevation: 2.0,
      shadowColor: Colors.blue.shade50.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                    backgroundColor: Color(0xFFE0F7FA),
                    child: Icon(Icons.person, color: Color(0xFF00ACC1))),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.appointment.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(widget.appointment.time,
                        style:
                        const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                const Spacer(),
                if (isAccepted)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (String value) async {
                      if (value == 'cancel') {
                        await _showCancelConfirmationDialog();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Cancel Appointment',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  const Icon(Icons.more_vert, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatusChip(
                  label: widget.appointment.type,
                  isStatus: false,
                  status: widget.appointment.status,
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: _getStatusLabel(widget.appointment.status),
                  isStatus: true,
                  status: widget.appointment.status,
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () => _updateAppointmentStatus('accepted'),
                      icon: _isUpdating
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () => _updateAppointmentStatus('rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.Confirmed:
        return 'Accepted';
      case AppointmentStatus.Pending:
        return 'Pending';
      case AppointmentStatus.Rejected:
        return 'Rejected';
      case AppointmentStatus.Cancelled:
        return 'Cancelled';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isStatus;
  final AppointmentStatus? status;
  const _StatusChip(
      {required this.label, this.isStatus = false, this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    if (isStatus) {
      switch (status) {
        case AppointmentStatus.Confirmed:
          backgroundColor = const Color(0xFFE0F2F1);
          textColor = const Color(0xFF00796B);
          break;
        case AppointmentStatus.Pending:
          backgroundColor = const Color(0xFFFFF3E0);
          textColor = const Color(0xFFF57C00);
          break;
        case AppointmentStatus.Rejected:
          backgroundColor = const Color(0xFFFFEBEE);
          textColor = const Color(0xFFD32F2F);
          break;
        case AppointmentStatus.Cancelled:
          backgroundColor = const Color(0xFFEEEEEE);
          textColor = const Color(0xFF757575);
          break;
        default:
          backgroundColor = Colors.grey.shade200;
          textColor = Colors.grey.shade800;
      }
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.w500, fontSize: 12)),
    );
  }
}

class SlotCard extends StatelessWidget {
  final AvailableSlot slot;
  const SlotCard({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shadowColor: Colors.green.shade50.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE8F5E9),
              child: Icon(Icons.access_time, color: Colors.green.shade700),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.time,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 5),
                _SlotStatusChip(type: slot.type),
              ],
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade700),
              label: Text(
                'Delete',
                style: TextStyle(color: Colors.red.shade800),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SlotStatusChip extends StatelessWidget {
  final SlotType type;
  const _SlotStatusChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = type == SlotType.Available;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAvailable ? 'Available' : 'Emergency',
        style: TextStyle(
          color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}