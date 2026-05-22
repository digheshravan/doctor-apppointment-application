import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/billing_service.dart';
import '../../auth/auth_service.dart';

// =============================================================================
// MediSlot v2 — Confirm Cash Payment Screen (Assistant)
// Shows all bills with status 'cash_pending' for the assigned doctor.
// Assistant taps "Confirm" to mark payment as cash_confirmed.
// =============================================================================

class ConfirmPaymentScreen extends StatefulWidget {
  const ConfirmPaymentScreen({super.key});

  @override
  State<ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<ConfirmPaymentScreen> {
  final BillingService _billing = BillingService();
  final AuthService _auth = AuthService();

  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _doctorId = await _auth.getAssignedDoctorIdForAssistant();
    if (_doctorId != null) {
      _bills = await _billing.getBillsByDoctorAndStatus(
        doctorId: _doctorId!,
        status: AppConstants.payCashPending,
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _confirm(Map<String, dynamic> bill) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: const Text('Confirm Cash Payment?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Patient: ${bill['patients']?['name'] ?? 'Unknown'}\n'
          'Amount: ₹${(bill['amount'] as num).toStringAsFixed(0)}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.primaryButtonStyle,
            child: const Text('Confirm',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _billing.confirmCashPayment(
      billId: bill['bill_id'] as String,
      confirmedByUserId: userId,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Cash payment confirmed!'),
        backgroundColor: Colors.green,
      ));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to confirm. Try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: MediSlotAppBar(
        title: 'Confirm Cash Payments',
        subtitle: 'Pending cash confirmations',
        showBack: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: _bills.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bills.length,
                      itemBuilder: (_, i) => _buildBillCard(_bills[i]),
                    ),
            ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final patientName = bill['patients']?['name'] ?? 'Unknown';
    final amount = (bill['amount'] as num).toDouble();
    final appt = bill['appointments'];
    final date = appt?['appointment_date'] ?? '-';
    final time = appt?['appointment_time'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('$date • $time',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.paymentCash.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        'Cash Pending',
                        style: TextStyle(
                            color: AppTheme.paymentCash,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirm(bill),
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                label: const Text('Mark as Paid',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No Pending Cash Payments',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text(
              'All cash payments have been confirmed.',
              style: TextStyle(color: AppTheme.textHint, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}
