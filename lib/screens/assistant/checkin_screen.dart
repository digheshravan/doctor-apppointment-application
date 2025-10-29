import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

// --- Main Screen Widget ---
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  // UI Colors
  static const Color primaryColor = Color(0xFF00AEEF);
  static const Color primaryVariant = Color(0xFF00B0F0);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF757575);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = false;
  String _currentFilter = 'Total';
  int _totalCount = 0;
  int _inactiveCount = 0;
  int _activeCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAppointmentCounts();
    _fetchAppointments('Total');
  }

  Future<void> _fetchAppointments(String type) async {
    setState(() {
      _isLoading = true;
      _currentFilter = type;
    });

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Updated query to fetch all needed patient and appointment details
    PostgrestFilterBuilder query = supabase
        .from('appointments')
        .select('''
          appointment_id,
          appointment_date,
          appointment_time,
          visit_status,
          reason,
          patients(patient_id, name, gender, age)
        ''')
        .eq('status', 'accepted');

    if (type == 'Inactive') {
      query = query.eq('appointment_date', todayStr).eq('visit_status', 'inactive');
    } else if (type == 'Active') {
      query = query.eq('appointment_date', todayStr).eq('visit_status', 'active');
    }

    final response = await query.order('appointment_time', ascending: true);

    if (mounted) {
      setState(() {
        _appointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    }
    await _fetchAppointmentCounts();
  }

  Future<void> _fetchAppointmentCounts() async {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final totalRes = await supabase
        .from('appointments')
        .select('appointment_id')
        .eq('status', 'accepted');

    final inactiveRes = await supabase
        .from('appointments')
        .select('appointment_id')
        .eq('appointment_date', todayStr)
        .eq('status', 'accepted')
        .eq('visit_status', 'inactive');

    final activeRes = await supabase
        .from('appointments')
        .select('appointment_id')
        .eq('appointment_date', todayStr)
        .eq('status', 'accepted')
        .eq('visit_status', 'active');

    if (mounted) {
      setState(() {
        _totalCount = totalRes.length;
        _inactiveCount = inactiveRes.length;
        _activeCount = activeRes.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String todayDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
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
              child: const Icon(Icons.checklist, color: primaryColor, size: 30),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reception Desk',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  "Today's Appointments - $todayDate",
                  style: const TextStyle(
                    color: lightTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          const SizedBox(height: 12),
          _buildStatsRow(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
            child: Text(
              "$_currentFilter Patients",
              style: const TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _isLoading
              ? Column(
            children: List.generate(5, (index) => const _ShimmerPatientCard()),
          )
              : Column(
            children: _appointments.isEmpty
                ? [_buildEmptyState()]
                : _appointments.map((a) {
              final patient = a['patients'] ?? <String, dynamic>{};

              // Format time from HH:MM:SS to HH:MM AM/PM
              String formattedTime = '-';
              if (a['appointment_time'] != null) {
                try {
                  final timeStr = a['appointment_time'];
                  final timeParts = timeStr.split(':');
                  final hour = int.parse(timeParts[0]);
                  final minute = timeParts[1];
                  final period = hour >= 12 ? 'PM' : 'AM';
                  final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                  formattedTime = '$hour12:$minute $period';
                } catch (e) {
                  formattedTime = a['appointment_time'];
                }
              }

              // Format date
              String formattedDate = '-';
              if (a['appointment_date'] != null) {
                try {
                  final date = DateTime.parse(a['appointment_date']);
                  formattedDate = DateFormat('dd/MM/yyyy').format(date);
                } catch (e) {
                  formattedDate = a['appointment_date'];
                }
              }

              final patientData = {
                'appointment_id': a['appointment_id'],
                'name': patient['name'] ?? 'Unknown',
                'gender': patient['gender'] ?? 'N/A',
                'age': patient['age']?.toString() ?? '-',
                'status': a['visit_status'] ?? 'inactive',
                'appointment_date': formattedDate,
                'appointment_time': formattedTime,
                'reason': a['reason'] ?? 'Not specified',
              };

              return _PatientListCard(
                patient: patientData,
                onWritePrescription: (p) {
                  // TODO: Implement navigation to prescription screen
                  print("Write prescription for: ${p['name']}");
                },
                onRefresh: () {
                  _fetchAppointments(_currentFilter);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          _totalCount.toString(),
          'Total',
          Icons.list_alt_rounded,
          _CheckInScreenState.primaryColor,
              () => _fetchAppointments('Total'),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          _inactiveCount.toString(),
          'Inactive',
          Icons.hourglass_empty_rounded,
          Colors.orange.shade700,
              () => _fetchAppointments('Inactive'),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          _activeCount.toString(),
          'Active',
          Icons.how_to_reg_rounded,
          _CheckInScreenState.accentColor,
              () => _fetchAppointments('Active'),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String count, String label, IconData icon, Color color, VoidCallback onTap) {
    final bool isSelected = (label == _currentFilter);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: _CheckInScreenState.lightTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count,
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 70,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'There are no "$_currentFilter" patients found for today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Patient List Card Widget ---
class _PatientListCard extends StatefulWidget {
  final Map<String, dynamic> patient;
  final Function(Map<String, dynamic>)? onWritePrescription;
  final VoidCallback? onRefresh;

  const _PatientListCard({
    required this.patient,
    this.onWritePrescription,
    this.onRefresh,
  });

  @override
  State<_PatientListCard> createState() => _PatientListCardState();
}

class _PatientListCardState extends State<_PatientListCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Status
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient['name'],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            widget.patient['appointment_time'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusTag(
                  status: widget.patient['status'],
                  color: widget.patient['status'] == 'active'
                      ? Colors.green.shade800
                      : Colors.grey.shade700,
                  backgroundColor: widget.patient['status'] == 'active'
                      ? Colors.green.shade50
                      : Colors.grey.shade200,
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),

            // Expanded Details Section
            if (_isExpanded) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Patient Details Grid
              Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      'Age',
                      widget.patient['age'],
                      icon: Icons.cake_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      'Gender',
                      widget.patient['gender'],
                      icon: Icons.wc_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      'Date',
                      widget.patient['appointment_date'],
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Reason Section
              _buildInfoColumn(
                'Reason',
                widget.patient['reason'],
                icon: Icons.medical_information_outlined,
              ),

              const SizedBox(height: 20),

              // Action Buttons
              if (widget.patient['status'] == 'active')
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onWritePrescription != null) {
                      widget.onWritePrescription!(widget.patient);
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded,
                      color: Colors.white, size: 20),
                  label: const Text(
                    "Write Prescription",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A3B0),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                )
              else if (widget.patient['status'] == 'inactive')
                ElevatedButton.icon(
                  onPressed: () async {
                    final supabase = Supabase.instance.client;
                    final appointmentId = widget.patient['appointment_id'];

                    try {
                      await supabase
                          .from('appointments')
                          .update({'visit_status': 'active'})
                          .eq('appointment_id', appointmentId);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Patient marked as arrived!')),
                        );

                        // Refresh the list
                        if (widget.onRefresh != null) {
                          widget.onRefresh!();
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 20),
                  label: const Text(
                    "Arrived",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value, {required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 18.0),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Status Tag Widget ---
class _StatusTag extends StatelessWidget {
  final String status;
  final Color color;
  final Color backgroundColor;

  const _StatusTag({
    required this.status,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// --- Shimmer Loading Card ---
class _ShimmerPatientCard extends StatelessWidget {
  const _ShimmerPatientCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 100,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 60,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
            Container(
              height: 20,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}