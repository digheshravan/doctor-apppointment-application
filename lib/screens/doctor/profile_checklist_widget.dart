import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';

// =============================================================================
// MediSlot v2 — Doctor Profile Completion Checklist Widget
// Shown as an inline banner on the doctor home screen.
// Tracks: photo, qualification, fee, specialization, clinic, license.
// =============================================================================

class ProfileChecklistBanner extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final VoidCallback onComplete;

  const ProfileChecklistBanner({
    super.key,
    required this.doctorData,
    required this.onComplete,
  });

  @override
  State<ProfileChecklistBanner> createState() => _ProfileChecklistBannerState();
}

class _ProfileChecklistBannerState extends State<ProfileChecklistBanner>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _anim;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _anim.forward() : _anim.reverse();
  }

  // ---------------------------------------------------------------------------
  // Checklist item logic
  // ---------------------------------------------------------------------------
  List<_CheckItem> get _items => [
        _CheckItem(
          label: 'Profile Photo',
          isDone: (widget.doctorData['photo_url'] as String?)?.isNotEmpty == true,
          icon: Icons.camera_alt_outlined,
        ),
        _CheckItem(
          label: 'Qualification',
          isDone:
              (widget.doctorData['qualification'] as String?)?.isNotEmpty == true,
          icon: Icons.school_outlined,
        ),
        _CheckItem(
          label: 'Consultation Fee',
          isDone: (widget.doctorData['consultation_fee'] != null &&
              widget.doctorData['consultation_fee'] != 0),
          icon: Icons.currency_rupee,
        ),
        _CheckItem(
          label: 'Specialization',
          isDone:
              (widget.doctorData['specialization'] as String?)?.isNotEmpty == true,
          icon: Icons.medical_services_outlined,
        ),
        _CheckItem(
          label: 'Clinic Added',
          isDone: widget.doctorData['has_clinic'] == true,
          icon: Icons.local_hospital_outlined,
        ),
        _CheckItem(
          label: 'License Number',
          isDone:
              (widget.doctorData['license_number'] as String?)?.isNotEmpty == true,
          icon: Icons.badge_outlined,
        ),
      ];

  int get _completedCount => _items.where((i) => i.isDone).length;
  double get _progress => _completedCount / _items.length;
  bool get _allComplete => _completedCount == _items.length;

  @override
  Widget build(BuildContext context) {
    if (_allComplete) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A7FA8), Color(0xFF2193b0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Circular progress indicator
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 3.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        Center(
                          child: Text(
                            '$_completedCount/${_items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_items.length - _completedCount} items remaining',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
          // Expandable checklist
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusMd),
                  bottomRight: Radius.circular(AppTheme.radiusMd),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                children: [
                  const Divider(color: Colors.white30, height: 1),
                  const SizedBox(height: 10),
                  ..._items.map((item) => _buildCheckRow(item)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onComplete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Go to Profile',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(_CheckItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isDone
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                  color: Colors.white60,
                  width: item.isDone ? 0 : 1.5),
            ),
            child: item.isDone
                ? Icon(Icons.check,
                    color: AppTheme.primary, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          Icon(item.icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            item.label,
            style: TextStyle(
              color: item.isDone ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight:
                  item.isDone ? FontWeight.w500 : FontWeight.normal,
              decoration:
                  item.isDone ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem {
  final String label;
  final bool isDone;
  final IconData icon;
  const _CheckItem(
      {required this.label, required this.isDone, required this.icon});
}

// =============================================================================
// Standalone photo upload helper — used by profile_screen.dart
// =============================================================================
class DoctorPhotoUploader {
  static Future<String?> pickAndUpload({
    required BuildContext context,
    required String doctorId,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (picked == null) return null;

    try {
      final bytes = await picked.readAsBytes();
      final fileName = 'doctor_${doctorId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'doctors/$fileName';

      await Supabase.instance.client.storage
          .from(AppConstants.bucketDoctorPhotos)
          .uploadBinary(storagePath, bytes,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg', upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from(AppConstants.bucketDoctorPhotos)
          .getPublicUrl(storagePath);

      // Update doctor record
      await Supabase.instance.client
          .from(AppConstants.tableDoctors)
          .update({'photo_url': publicUrl})
          .eq('doctor_id', doctorId);

      return publicUrl;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return null;
    }
  }
}
