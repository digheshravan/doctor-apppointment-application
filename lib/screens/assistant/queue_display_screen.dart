import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/queue_service.dart';
import '../../auth/auth_service.dart';

// =============================================================================
// MediSlot v2 — Live Queue Display Screen (Assistant)
// Real-time queue board using Supabase Realtime stream.
// Shows token number, patient state, and actions to advance/miss tokens.
// =============================================================================

class QueueDisplayScreen extends StatefulWidget {
  const QueueDisplayScreen({super.key});

  @override
  State<QueueDisplayScreen> createState() => _QueueDisplayScreenState();
}

class _QueueDisplayScreenState extends State<QueueDisplayScreen> {
  final QueueService _queue = QueueService();
  final AuthService _auth = AuthService();

  String? _doctorId;
  bool _loadingDoctorId = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorId();
  }

  Future<void> _loadDoctorId() async {
    _doctorId = await _auth.getAssignedDoctorIdForAssistant();
    if (mounted) setState(() => _loadingDoctorId = false);
  }

  Future<void> _advance(String tokenId, String state) async {
    if (state == AppConstants.queueCompleted || state == AppConstants.queueMissed) return;
    await _queue.advanceToken(tokenId);
  }

  Future<void> _markMissed(String tokenId) async {
    await _queue.markMissed(tokenId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: MediSlotAppBar(
        title: 'Live Queue',
        subtitle: 'Today\'s patient queue',
        showBack: true,
      ),
      body: _loadingDoctorId
          ? const Center(child: CircularProgressIndicator())
          : _doctorId == null
              ? const Center(child: Text('No doctor assigned.'))
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _queue.queueStream(_doctorId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tokens = snapshot.data ?? [];
                    // Filter to today's tokens only
                    final today = DateTime.now().toIso8601String().split('T').first;
                    final todayTokens = tokens.where((t) {
                      final createdAt = t['created_at'] as String? ?? '';
                      return createdAt.startsWith(today);
                    }).toList();

                    if (todayTokens.isEmpty) {
                      return _buildEmpty();
                    }

                    // Find current active token
                    final activeToken = todayTokens.where(
                      (t) => t['state'] == AppConstants.queueActive).toList();

                    return Column(
                      children: [
                        // Active token hero card
                        if (activeToken.isNotEmpty)
                          _buildActiveHero(activeToken.first),
                        
                        // Queue stats row
                        _buildStatsRow(todayTokens),

                        // Queue list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: todayTokens.length,
                            itemBuilder: (_, i) =>
                                _buildTokenCard(todayTokens[i]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildActiveHero(Map<String, dynamic> token) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Now Serving',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                'Token #${token['token_number']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _advance(
                token['token_id'] as String, token['state'] as String),
            icon: const Icon(Icons.skip_next, color: AppTheme.primary, size: 18),
            label: const Text('Complete',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> tokens) {
    int waiting = tokens.where((t) => t['state'] == AppConstants.queueWaiting).length;
    int completed = tokens.where((t) => t['state'] == AppConstants.queueCompleted).length;
    int missed = tokens.where((t) => t['state'] == AppConstants.queueMissed).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statChip('Waiting', waiting, Colors.orange),
          const SizedBox(width: 8),
          _statChip('Done', completed, AppTheme.accent),
          const SizedBox(width: 8),
          _statChip('Missed', missed, AppTheme.error),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            Text(label,
                style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(Map<String, dynamic> token) {
    final state = token['state'] as String? ?? 'waiting';
    final tokenNum = token['token_number'] as int? ?? 0;

    final (stateColor, stateLabel, stateIcon) = _resolveState(state);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: state == AppConstants.queueActive
            ? Border.all(color: AppTheme.primary, width: 2)
            : Border.all(color: AppTheme.divider),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: stateColor.withValues(alpha: 0.12),
          child: Text(
            '#$tokenNum',
            style: TextStyle(
                color: stateColor,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
        ),
        title: Text('Token $tokenNum',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Icon(stateIcon, size: 12, color: stateColor),
            const SizedBox(width: 4),
            Text(stateLabel,
                style: TextStyle(
                    color: stateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: state == AppConstants.queueWaiting
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Call Next
                  IconButton(
                    tooltip: 'Call Patient',
                    icon: Icon(Icons.call_outlined,
                        color: AppTheme.primary, size: 22),
                    onPressed: () => _advance(
                        token['token_id'] as String, state),
                  ),
                  // Mark Missed
                  IconButton(
                    tooltip: 'Mark Missed',
                    icon: const Icon(Icons.person_off_outlined,
                        color: AppTheme.error, size: 22),
                    onPressed: () =>
                        _markMissed(token['token_id'] as String),
                  ),
                ],
              )
            : Icon(stateIcon, color: stateColor, size: 22),
      ),
    );
  }

  (Color, String, IconData) _resolveState(String state) {
    switch (state) {
      case 'active':
        return (AppTheme.primary, 'Active', Icons.radio_button_checked);
      case 'completed':
        return (AppTheme.accent, 'Completed', Icons.check_circle_outline);
      case 'missed':
        return (AppTheme.error, 'Missed', Icons.cancel_outlined);
      default:
        return (Colors.orange, 'Waiting', Icons.hourglass_empty_rounded);
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Queue is Empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('No patients have checked in today.',
              style:
                  TextStyle(color: AppTheme.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
