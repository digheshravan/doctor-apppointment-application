import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/billing_service.dart';

// =============================================================================
// MediSlot v2 — Consultation Complete Screen
// Shown after doctor saves prescription + bill is auto-created.
// Summarises the visit and prompts patient about payment.
// =============================================================================

class ConsultationCompleteScreen extends StatefulWidget {
  final String billId;
  final String appointmentId;
  final String patientName;
  final double billAmount;
  final String doctorName;

  const ConsultationCompleteScreen({
    super.key,
    required this.billId,
    required this.appointmentId,
    required this.patientName,
    required this.billAmount,
    required this.doctorName,
  });

  @override
  State<ConsultationCompleteScreen> createState() =>
      _ConsultationCompleteScreenState();
}

class _ConsultationCompleteScreenState
    extends State<ConsultationCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isWaiving = false;

  final BillingService _billing = BillingService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _waiveFee() async {
    setState(() => _isWaiving = true);
    final ok = await _billing.waivePayment(widget.billId);
    if (!mounted) return;
    setState(() => _isWaiving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Consultation fee waived ✅'),
        backgroundColor: Colors.green,
      ));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Animated checkmark
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 54),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Consultation Complete!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Prescription saved for ${widget.patientName}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Bill summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    _summaryRow('Patient', widget.patientName),
                    const SizedBox(height: 10),
                    _summaryRow('Consulting Doctor', 'Dr. ${widget.doctorName}'),
                    const SizedBox(height: 10),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Consultation Fee',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(
                          '₹${widget.billAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: AppTheme.warning, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Prescription PDF locked until payment',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Actions
              Text(
                'Patient can pay via the MediSlot app',
                style: TextStyle(
                    color: AppTheme.textHint, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppTheme.primaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isWaiving ? null : _waiveFee,
                  child: _isWaiving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(
                          'Waive Fee (No Charge)',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}
