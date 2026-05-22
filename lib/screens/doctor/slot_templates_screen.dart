import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/slot_service.dart';
import '../../auth/auth_service.dart';

// =============================================================================
// MediSlot v2 — Slot Templates Screen (Doctor)
// Weekly schedule builder: create recurring slot templates.
// Doctor sets day, time range, slot duration, limit, and clinic.
// Assistant can then generate actual slots from templates for any date.
// =============================================================================

class SlotTemplatesScreen extends StatefulWidget {
  const SlotTemplatesScreen({super.key});

  @override
  State<SlotTemplatesScreen> createState() => _SlotTemplatesScreenState();
}

class _SlotTemplatesScreenState extends State<SlotTemplatesScreen> {
  final SlotService _slotService = SlotService();
  final AuthService _auth = AuthService();

  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _clinics = [];
  bool _isLoading = true;
  String? _doctorId;

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _doctorId = await _auth.getCurrentDoctorId();
    if (_doctorId != null) {
      _templates = await _slotService.getScheduleTemplates(_doctorId!);
      _clinics = await _slotService.getDoctorClinics(_doctorId!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddDialog() {
    int selectedDay = 0;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 13, minute: 0);
    int slotDuration = 15;
    int slotLimit = 1;
    String? selectedClinicId = _clinics.isNotEmpty ? _clinics.first['clinic_id'] as String? : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXl)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Add Schedule Template',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 20),

                // Day picker
                const Text('Day of Week',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final selected = selectedDay == i;
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedDay = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          _days[i].substring(0, 3),
                          style: TextStyle(
                            color: selected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Time range
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        label: 'Start Time',
                        time: startTime,
                        onPick: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: startTime);
                          if (t != null) setSheet(() => startTime = t);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePicker(
                        label: 'End Time',
                        time: endTime,
                        onPick: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: endTime);
                          if (t != null) setSheet(() => endTime = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Duration + Limit
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        label: 'Slot Duration (min)',
                        value: slotDuration,
                        min: 5,
                        max: 60,
                        step: 5,
                        onChanged: (v) => setSheet(() => slotDuration = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        label: 'Slot Limit',
                        value: slotLimit,
                        min: 1,
                        max: 10,
                        step: 1,
                        onChanged: (v) => setSheet(() => slotLimit = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Clinic picker
                if (_clinics.isNotEmpty) ...[
                  const Text('Clinic',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: DropdownButton<String>(
                      value: selectedClinicId,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      hint: const Text('Select clinic'),
                      items: _clinics
                          .map((c) => DropdownMenuItem<String>(
                                value: c['clinic_id'] as String,
                                child: Text(c['name'] as String? ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheet(() => selectedClinicId = v),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final start =
                          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                      final end =
                          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                      if (_doctorId == null) return;
                      final ok = await _slotService.createTemplate(
                        doctorId: _doctorId!,
                        dayOfWeek: selectedDay,
                        startTime: start,
                        endTime: end,
                        slotDurationMinutes: slotDuration,
                        slotLimit: slotLimit,
                        clinicId: selectedClinicId,
                      );

                      if (!mounted) return;
                      Navigator.pop(ctx);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Template saved!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        await _load();
                      }
                    },
                    style: AppTheme.primaryButtonStyle.copyWith(
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    child: const Text('Save Template',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: MediSlotAppBar(
        title: 'Schedule Templates',
        subtitle: 'Weekly recurring schedule',
        showBack: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Template',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: _templates.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _templates.length,
                      itemBuilder: (_, i) => _buildTemplateCard(_templates[i]),
                    ),
            ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> t) {
    final day = _days[(t['day_of_week'] as int?) ?? 0];
    final start = t['start_time']?.toString().substring(0, 5) ?? '--:--';
    final end = t['end_time']?.toString().substring(0, 5) ?? '--:--';
    final duration = t['slot_duration_minutes'] ?? 15;
    final limit = t['slot_limit'] ?? 1;
    final clinicName = t['clinics']?['name'] ?? 'No Clinic';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(day.substring(0, 3),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ],
          ),
        ),
        title: Text('$start – $end',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(
            '$duration min • $limit per slot • $clinicName',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          tooltip: 'Remove Template',
          onPressed: () async {
            final ok = await _slotService
                .deactivateTemplate(t['template_id'] as String);
            if (ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template removed')));
              await _load();
            }
          },
        ),
      ),
    );
  }

  Widget _timePicker(
      {required String label,
      required TimeOfDay time,
      required VoidCallback onPick}) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  time.format(context),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  if (value > min) onChanged(value - step);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.remove,
                      size: 16, color: AppTheme.primary),
                ),
              ),
              Text('$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              GestureDetector(
                onTap: () {
                  if (value < max) onChanged(value + step);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.add,
                      size: 16, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No Templates Yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Tap + to create your weekly schedule.',
                style: TextStyle(
                    color: AppTheme.textHint, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}
