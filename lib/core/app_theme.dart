import 'package:flutter/material.dart';

// =============================================================================
// MediSlot v2 — App Theme
// Single source of truth for all colors, typography, and component styles.
// =============================================================================

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Brand Colors
  // ---------------------------------------------------------------------------
  static const Color primaryStart = Color(0xFF2193b0); // gradient start (teal-blue)
  static const Color primaryEnd = Color(0xFF6dd5ed);   // gradient end (sky blue)
  static const Color primary = Color(0xFF2193b0);      // solid primary
  static const Color primaryLight = Color(0xFFE3F4F9); // light tint for backgrounds

  static const Color accent = Color(0xFF00C897);       // green accent (success actions)
  static const Color accentLight = Color(0xFFE6FAF5);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);

  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);

  static const Color info = Color(0xFF1976D2);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ---------------------------------------------------------------------------
  // Neutrals
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4F8);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF5C6D80);
  static const Color textHint = Color(0xFF9EAEBE);
  static const Color divider = Color(0xFFE8EDF2);

  // ---------------------------------------------------------------------------
  // Payment Status Colors
  // ---------------------------------------------------------------------------
  static const Color paymentPaid = Color(0xFF00C897);
  static const Color paymentPending = Color(0xFFFF9800);
  static const Color paymentFailed = Color(0xFFE53935);
  static const Color paymentCash = Color(0xFF7B61FF);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00C897), Color(0xFF00E5B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------------------
  // Shadows
  // ---------------------------------------------------------------------------
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF2193b0).withValues(alpha: 0.08),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Border Radius
  // ---------------------------------------------------------------------------
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusMd);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusMd);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusSm);
  static BorderRadius get chipRadius => BorderRadius.circular(radiusFull);

  // ---------------------------------------------------------------------------
  // Input Decoration
  // ---------------------------------------------------------------------------
  static InputDecoration inputDecoration({
    required String hint,
    String? label,
    IconData? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textSecondary, size: 20)
          : null,
      suffixIcon: suffix,
      hintStyle: const TextStyle(color: textHint, fontSize: 14),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      filled: true,
      fillColor: surfaceVariant,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: error, width: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Button Styles
  // ---------------------------------------------------------------------------
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        elevation: 0,
        textStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );

  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );

  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: error,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        elevation: 0,
      );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: accent,
          surface: surface,
          error: error,
        ),
        scaffoldBackgroundColor: background,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: cardRadius),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryButtonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: outlinedButtonStyle,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: primaryLight,
          labelStyle: const TextStyle(color: primary, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: chipRadius),
        ),
        dividerTheme: const DividerThemeData(
          color: divider,
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          backgroundColor: textPrimary,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      );
}

// =============================================================================
// Reusable UI Helpers
// =============================================================================

/// A gradient app bar that matches the MediSlot brand header style.
class MediSlotAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final double height;

  const MediSlotAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = false,
    this.height = 110,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppTheme.radiusXl),
            bottomRight: Radius.circular(AppTheme.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                if (showBack)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Payment status badge widget used across multiple screens.
class PaymentStatusBadge extends StatelessWidget {
  final String status;

  const PaymentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  (Color, String, IconData) _resolve(String s) {
    switch (s) {
      case 'paid':
        return (AppTheme.paymentPaid, 'Paid', Icons.check_circle_outline);
      case 'cash_confirmed':
        return (AppTheme.paymentPaid, 'Cash Confirmed', Icons.check_circle_outline);
      case 'waived':
        return (AppTheme.paymentPaid, 'Waived', Icons.volunteer_activism);
      case 'cash_pending':
        return (AppTheme.paymentCash, 'Cash Pending', Icons.payments_outlined);
      case 'processing':
        return (AppTheme.paymentPending, 'Processing', Icons.hourglass_empty);
      case 'failed':
        return (AppTheme.paymentFailed, 'Failed', Icons.error_outline);
      default:
        return (AppTheme.paymentPending, 'Pending', Icons.pending_outlined);
    }
  }
}
