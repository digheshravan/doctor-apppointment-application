import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:intl/intl.dart';
import 'package:medi_slot/screens/assistant/checkin_screen.dart';
import 'package:medi_slot/screens/assistant/manage_appointments.dart';
import 'package:medi_slot/screens/assistant/profile_screen.dart';
import 'package:medi_slot/screens/assistant/upload_slots_page.dart';
import 'package:medi_slot/screens/assistant/view_prescriptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medi_slot/screens/login_screen.dart';
import 'package:medi_slot/auth/auth_service.dart';

class AssistantDashboardScreen extends StatefulWidget {
  const AssistantDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AssistantDashboardScreen> createState() =>
      _AssistantDashboardScreenState();
}

class _AssistantDashboardScreenState extends State<AssistantDashboardScreen> {
  // --- UI Colors from UploadSlotsPage Theme ---
  static const Color primaryColor = Color(0xFF00AEEF); // Main blue
  static const Color accentColor = Color(0xFF4CAF50); // Green
  static const Color backgroundColor = Color(0xFFF8F9FA); // Off-white
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);
  static const Color inactiveTabColor = Color(0xFFF0F4F8);
  // --- End Theme Colors ---

  List<Map<String, dynamic>> _pendingAppointments = [];
  bool _isLoadingAppointments = true;
  String? assistantName;
  String? assistantId;
  String? doctorId;
  bool isLoadingName = true;
  bool isLoadingDoctorId = true;
  bool isLoading = true;
  int _page = 0;
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;
  int todaysAppointments = 0;
  int pendingApprovals = 0;
  int totalPatients = 0;

  // --- UI Flow State ---
  bool _isViewingPending = false; // Toggles between Overview and Pending

  @override
  void initState() {
    super.initState();
    _loadAssistantData();
    _loadDashboardStats();
    _initializeAssistantDashboard();
    _fetchPendingAppointments();
  }

  Future<void> _fetchPendingAppointments() async {
    setState(() => _isLoadingAppointments = true);

    try {
      final response = await _supabase
          .from('appointments')
          .select('*, patients(name)')
          .eq('status', 'pending')
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true);

      if (mounted) {
        setState(() {
          _pendingAppointments = List<Map<String, dynamic>>.from(response);
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending appointments: $e');
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _updateAppointmentStatus(
      String appointmentId, String newStatus) async {
    try {
      // Logic for updating slot status (e.g., in 'accepted' case)
      if (newStatus == 'accepted') {
        // 1. Get appointment details (slot_id)
        final appointmentData = await _supabase
            .from('appointments')
            .select('slot_id')
            .eq('appointment_id', appointmentId)
            .maybeSingle();
        final slotId = appointmentData?['slot_id'];

        // 2. Update the slot
        if (slotId != null) {
          final slotData = await _supabase
              .from('appointment_slots')
              .select('booked_count, slot_limit')
              .eq('slot_id', slotId)
              .maybeSingle();

          if (slotData != null) {
            int bookedCount = slotData['booked_count'] ?? 0;
            int slotLimit = slotData['slot_limit'] ?? 1;
            bookedCount = (bookedCount + 1).clamp(0, slotLimit);
            await _supabase.from('appointment_slots').update({
              'booked_count': bookedCount,
              'status': 'closed', // block others from booking
            }).eq('slot_id', slotId);
          }
        }
      } else if (newStatus == 'rejected') {
        // Logic for 'rejected' status (e.g., reopen the slot)
        final appointmentData = await _supabase
            .from('appointments')
            .select('slot_id')
            .eq('appointment_id', appointmentId)
            .maybeSingle();
        final slotId = appointmentData?['slot_id'];

        if (slotId != null) {
          await _supabase.from('appointment_slots').update({
            'booked_count': 0,
            'status': 'open', // free slot for others
          }).eq('slot_id', slotId);
        }
      }

      // 3. Update appointment status (moved to after slot logic)
      final response = await _supabase
          .from('appointments')
          .update({'status': newStatus})
          .eq('appointment_id', appointmentId);

      // 4. Handle response and refresh
      if (response == null) { // Check for successful update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment marked as $newStatus')),
        );
        _fetchPendingAppointments(); // Refresh list
        _loadDashboardStats(); // Update dashboard counts
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating appointment')),
        );
      }
    } catch (e) {
      debugPrint('Error updating appointment status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }

  Future<void> _loadAssistantData() async {
    final name = await AuthService().getCurrentAssistantName();

    // Get the current user's ID
    final userId = _supabase.auth.currentUser?.id;

    if (userId != null) {
      try {
        // Fetch assistant record to get assistant_id and doctor_id
        final assistantData = await _supabase
            .from('assistants')
            .select('assistant_id, assigned_doctor_id')
            .eq('user_id', userId)
            .maybeSingle();

        if (mounted) {
          setState(() {
            assistantName = name ?? 'Assistant';
            assistantId = assistantData?['assistant_id'];
            doctorId = assistantData?['assigned_doctor_id'];
            isLoadingName = false;
            isLoadingDoctorId = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching assistant data: $e");
        if (mounted) {
          setState(() {
            assistantName = name ?? 'Assistant';
            isLoadingName = false;
            isLoadingDoctorId = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          assistantName = name ?? 'Assistant';
          isLoadingName = false;
          isLoadingDoctorId = false;
        });
      }
    }
  }

  // 🔹 Load all assistant-related data and stats
  Future<void> _initializeAssistantDashboard() async {
    try {
      // Fetch assistant name directly via AuthService (uses linked profile)
      final name = await _authService.getCurrentAssistantName();

      // Get assistant ID and assigned doctor ID using AuthService methods
      final aId = await _authService.getCurrentAssistantId();
      final dId = await _authService.getAssignedDoctorIdForAssistant();

      // If no assigned doctor, show message later
      if (aId == null || dId == null) {
        if (mounted) {
          setState(() {
            assistantName = name ?? "Assistant";
            isLoading = false;
          });
        }
        return;
      }

      // Fetch dashboard stats
      final t = await _authService.getTodaysAppointmentsCountForAssistant();
      final p = await _authService.getPendingApprovalsCountForAssistant();
      final tot = await _authService.getTotalPatientsCountForAssistant();

      if (mounted) {
        setState(() {
          assistantName = name ?? "Assistant";
          assistantId = aId;
          doctorId = dId;
          todaysAppointments = t;
          pendingApprovals = p;
          totalPatients = tot;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error loading assistant dashboard: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadDashboardStats() async {
    final authService = AuthService();

    final t = await authService.getTodaysAppointmentsCountForAssistant();
    final p = await authService.getPendingApprovalsCountForAssistant();
    final tot = await authService.getTotalPatientsCountForAssistant();

    if (mounted) {
      setState(() {
        todaysAppointments = t;
        pendingApprovals = p;
        totalPatients = tot;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching doctor_id
    if (isLoadingDoctorId) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle case where doctorId is still null after loading
    final String effectiveDoctorId = doctorId ?? "";

    return Scaffold(
      backgroundColor: backgroundColor, // Use new theme color
      body: IndexedStack(
        index: _page,
        children: [
          _buildDashboardPage(),
          const CheckInScreen(),
          const ManageAppointmentsPage(),
          // Ensure doctorId is not null, pass empty string as fallback
          UploadSlotsPage(
            doctorId: effectiveDoctorId,
            assistantId: assistantId,
          ),
          const AssistantPrescriptionsScreen(),
          const AssistantProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        color: backgroundColor, // Use new theme color
        child: CurvedNavigationBar(
          backgroundColor: backgroundColor, // Use new theme color
          buttonBackgroundColor: Colors.blue.shade700,
          color: Colors.white,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 400),
          height: 60.0,
          index: _page,
          items: const <Widget>[
            Icon(Icons.home_filled, size: 30, color: Colors.black54),
            Icon(Icons.checklist, size: 30, color: Colors.black54),
            Icon(Icons.calendar_month_outlined,
                size: 30, color: Colors.black54),
            Icon(Icons.access_time_outlined, size: 30, color: Colors.black54),
            Icon(Icons.description_outlined, size: 30, color: Colors.black54),
            Icon(Icons.person_outline, size: 30, color: Colors.black54),
          ],
          onTap: (index) {
            setState(() {
              _page = index;
            });
          },
        ),
      ),
    );
  }

  // --- NEW UI FLOW WIDGETS ---

  /// Builds the main dashboard page (Page 0)
  Widget _buildDashboardPage() {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildDashboardAppBar(),
      body: Column(
        children: [
          _buildActionTabs(),
          Expanded(
            child: _isViewingPending ? _buildPendingList() : _buildOverview(),
          ),
        ],
      ),
    );
  }

  /// New AppBar that replaces the SliverAppBar but keeps the gradient
  PreferredSizeWidget _buildDashboardAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(130.0), // Old expandedHeight
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back, ${assistantName ?? '...'}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Here's what's happening today",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Toggle buttons like in UploadSlotsPage
  Widget _buildActionTabs() {
    // Apply consistent styling based on selection
    final overviewButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: !_isViewingPending ? accentColor : inactiveTabColor,
      foregroundColor: !_isViewingPending ? Colors.white : textColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: _isViewingPending ? 0 : 2, // Only elevate the active tab
    );
    final pendingButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: _isViewingPending ? accentColor : inactiveTabColor,
      foregroundColor: _isViewingPending ? Colors.white : textColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: _isViewingPending ? 2 : 0, // Only elevate the active tab
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.dashboard_rounded,
                  color: !_isViewingPending ? Colors.white : textColor),
              label: const Text('Overview'),
              onPressed: () {
                if (_isViewingPending) {
                  // Only change state if needed
                  setState(() => _isViewingPending = false);
                }
              },
              style: overviewButtonStyle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.list_alt_rounded,
                  color: _isViewingPending ? Colors.white : textColor),
              label: Text('Pending ($pendingApprovals)'), // Show count
              onPressed: () {
                if (!_isViewingPending) {
                  // Only change state if needed
                  setState(() {
                    _isViewingPending = true;
                  });
                }
              },
              style: pendingButtonStyle,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the Stats and Quick Actions
  Widget _buildOverview() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _buildStatCard(
          title: "Today's Appointments",
          value: "$todaysAppointments",
          icon: Icons.calendar_today_outlined,
          iconColor: Colors.blue.shade700,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          title: "Pending Approvals",
          value: "$pendingApprovals",
          icon: Icons.access_time_filled,
          iconColor: Colors.orange.shade700,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          title: "Total Patients",
          value: "$totalPatients",
          icon: Icons.group_outlined,
          iconColor: Colors.green.shade700,
        ),
        const SizedBox(height: 24),
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          title: "Add New Slot",
          subtitle: "Create availability",
          icon: Icons.add,
          isPrimary: true,
          onTap: () {
            setState(() {
              _page = 3; // Navigate to Upload Slots page
            });
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          title: "View Appointments",
          subtitle: "Manage schedule",
          icon: Icons.calendar_month_outlined,
          onTap: () {
            setState(() {
              _page = 2; // Navigate to Appointments page
            });
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          title: "Write Prescription",
          subtitle: "Assist doctor",
          icon: Icons.edit_note_rounded,
          onTap: () {
            setState(() {
              _page = 4; // Navigate to Prescriptions page
            });
          },
        ),
      ],
    );
  }

  /// Shows the list of pending appointments
  Widget _buildPendingList() {
    return Column(
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Pending Appointments",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _page = 2; // Navigate to ManageAppointmentsPage
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "View All",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.blue.shade700,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchPendingAppointments,
            color: primaryColor,
            child: _isLoadingAppointments
                ? const Center(child: CircularProgressIndicator())
                : _pendingAppointments.isEmpty
                ? ListView(
              // Allows pull-to-refresh even when empty
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                    height:
                    MediaQuery.of(context).size.height * 0.2),
                const Center(
                    child: Text("No pending appointments found.")),
              ],
            )
                : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _pendingAppointments.length,
              itemBuilder: (context, index) {
                final appointment = _pendingAppointments[index];
                final patient = appointment['patients'] ?? {};
                return _buildAppointmentCard(
                  name: patient['name'] ?? 'Unknown',
                  date: appointment['appointment_date'] != null
                      ? DateFormat('dd/MM/yyyy').format(
                      DateTime.parse(
                          appointment['appointment_date']))
                      : '-',
                  time: appointment['appointment_time'] != null
                      ? DateFormat('h:mm a').format(
                      DateFormat('HH:mm:ss')
                          .parse(appointment['appointment_time']))
                      : '-',
                  onAccept: () => _updateAppointmentStatus(
                      appointment['appointment_id'], 'accepted'),
                  onReject: () => _updateAppointmentStatus(
                      appointment['appointment_id'], 'rejected'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- END NEW UI FLOW WIDGETS ---

  // --- Original Helper Widgets (Unchanged) ---

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0xFF00A3A3).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
              isPrimary ? Colors.white : Colors.grey.withOpacity(0.1),
              child: Icon(
                icon,
                size: 22,
                color:
                isPrimary ? const Color(0xFF00A3A3) : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isPrimary ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard({
    required String name,
    required String date,
    required String time,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.person_outline, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "pending",
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 16),
              Icon(Icons.access_time_outlined,
                  size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(time, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Reject"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Accept"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}