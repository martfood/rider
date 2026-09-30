import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../core/theme/theme_manager.dart';
import '../../providers/session_provider.dart';
import '../auth/auth_error_handler.dart';
import '../auth/email_service.dart';

/// Settings screen for riders matching the Customer App Settings UI, features, and bottom sheets.
class RiderSettingsScreen extends ConsumerStatefulWidget {
  const RiderSettingsScreen({super.key});

  @override
  ConsumerState<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends ConsumerState<RiderSettingsScreen> {
  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {});
    ThemeManager.themeModeNotifier.value = mode;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final modeStr = mode == ThemeMode.dark
            ? 'dark'
            : (mode == ThemeMode.light ? 'light' : 'system');
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(user.uid)
            .set({'themeMode': modeStr}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating rider theme setting in Firestore: $e');
      }
    }
  }

  void _showAppearanceBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final optionBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8FC);
    final optionBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      elevation: 0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final currentMode = ThemeManager.themeModeNotifier.value;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildOptionTile({
              required String title,
              required IconData icon,
              required ThemeMode mode,
            }) {
              final isSelected = currentMode == mode;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      _setThemeMode(mode);
                      Navigator.pop(sheetContext);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? purpleColor.withValues(alpha: 0.12)
                            : optionBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? purpleColor : optionBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? purpleColor
                                  : (isDark
                                      ? Colors.grey[800]
                                      : const Color(0xFFEFEFF4)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? Colors.white : purpleColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: AppTypography.font(15),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? purpleColor : primaryTextColor,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: purpleColor,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : const Color(0xFFDCDCE0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Icon(
                    Icons.palette_outlined,
                    size: 64,
                    color: purpleColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Appearance Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(22),
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose your preferred theme appearance for MartFood.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w500,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  buildOptionTile(
                    title: 'Light Mode',
                    icon: Icons.light_mode_outlined,
                    mode: ThemeMode.light,
                  ),
                  buildOptionTile(
                    title: 'Dark Mode',
                    icon: Icons.dark_mode_outlined,
                    mode: ThemeMode.dark,
                  ),
                  buildOptionTile(
                    title: 'System Default',
                    icon: Icons.settings_suggest_outlined,
                    mode: ThemeMode.system,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordBottomSheet(String initialEmail) {
    final emailController = TextEditingController(text: initialEmail);
    bool dialogLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(20),
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your email address and we will send you a 6-digit OTP code to reset your password.',
                    style: TextStyle(
                      fontSize: AppTypography.font(13),
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: AppTypography.font(13),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: fieldBorder, width: 1.0),
                    ),
                    child: TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor, fontSize: AppTypography.font(14)),
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontSize: AppTypography.font(14),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  dialogLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: purpleColor,
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty) {
                                AuthErrorHandler.showError(
                                  context,
                                  'Please enter your email address',
                                );
                                return;
                              }

                              setDialogState(() {
                                dialogLoading = true;
                              });

                              final otpCode =
                                  (100000 + Random().nextInt(900000)).toString();

                              try {
                                final normEmail = email.trim().toLowerCase();
                                final riderQuery = await FirebaseFirestore.instance
                                    .collection('riders')
                                    .where('email', isEqualTo: normEmail)
                                    .get()
                                    .timeout(const Duration(seconds: 5));

                                if (riderQuery.docs.isEmpty) {
                                  throw 'No rider account is registered with this email address.';
                                }

                                await FirebaseFirestore.instance
                                    .collection('password_resets')
                                    .doc(normEmail)
                                    .set({
                                  'otp': otpCode,
                                  'expiresAt': Timestamp.fromDate(
                                    DateTime.now().add(const Duration(minutes: 15)),
                                  ),
                                }).timeout(const Duration(seconds: 5));

                                final sent = await EmailService.sendPasswordResetOtp(
                                  email,
                                  otpCode,
                                );

                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  if (sent) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Verification code sent to $email',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    AuthErrorHandler.showError(
                                      context,
                                      'Failed to send email. Please try again.',
                                    );
                                  }
                                  context.push('/auth/forgot-password-otp', extra: {
                                    'email': email,
                                    'otp': otpCode,
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  AuthErrorHandler.showError(context, e);
                                }
                              } finally {
                                setDialogState(() {
                                  dialogLoading = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Send Code',
                              style: TextStyle(
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.logOut,
                color: purpleColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign Out',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(20),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to sign out of your rider account?',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(14),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFF3F4F7),
                      foregroundColor: primaryTextColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppTypography.font(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      Navigator.pop(sheetContext);
                      await appSignOut(ref);
                      if (mounted) {
                        router.go('/get-started');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppTypography.font(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: dialogBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Account',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete your account? This action cannot be undone and all your rider records will be permanently removed.',
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(14),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFF3F4F7),
                        foregroundColor: primaryTextColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.font(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        Navigator.pop(dialogContext);
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('riders')
                                .doc(user.uid)
                                .delete();
                            await user.delete();
                          } catch (e) {
                            debugPrint('Error deleting rider account: $e');
                          }
                        }
                        await appSignOut(ref);
                        if (mounted) {
                          router.go('/get-started');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.font(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : Colors.white;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final dividerColor = isDark ? AppTheme.darkBorder : const Color(0xFFF5EEFF);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.grey[800]! : const Color(0xFFE9EAF0),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                children: [
                  // ── Grouped Settings Card (Appearance Mode, Reset Password, Sign out) ──
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      children: [
                        // Row 1: Appearance Mode
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showAppearanceBottomSheet(context),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: purpleColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.palette_outlined,
                                      color: purpleColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Appearance Mode',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(15),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: purpleColor,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 64,
                          endIndent: 16,
                        ),

                        // Row 2: Reset Password
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final user = FirebaseAuth.instance.currentUser;
                              _showForgotPasswordBottomSheet(user?.email ?? '');
                            },
                            borderRadius: BorderRadius.zero,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: purpleColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.key,
                                      color: purpleColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Reset Password',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(15),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: purpleColor,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 64,
                          endIndent: 16,
                        ),

                        // Row 3: Sign out
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showLogoutBottomSheet(context),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: purpleColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.logout,
                                      color: purpleColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Sign out',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(15),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: purpleColor,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Standalone Bottom Action Row: Delete account ─────────────
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDeleteAccountDialog(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Delete account',
                                style: TextStyle(
                                  fontSize: AppTypography.font(15),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: purpleColor,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
