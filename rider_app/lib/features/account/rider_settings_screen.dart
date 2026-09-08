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
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w400,
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

  void _showChangeEmailBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final user = FirebaseAuth.instance.currentUser;
    final currentEmail = user?.email ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return _RiderChangeEmailModal(
          currentEmail: currentEmail,
          isDark: isDark,
          purpleColor: purpleColor,
          cardBg: cardBg,
          primaryTextColor: primaryTextColor,
          mutedTextColor: mutedTextColor,
          fieldBg: fieldBg,
          fieldBorder: fieldBorder,
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
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (_) {}
                      ref.read(sessionProvider.notifier).signOut();
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
                        ref.read(sessionProvider.notifier).signOut();
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
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
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

                        // Row 2: Change Email Address
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showChangeEmailBottomSheet(context),
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
                                      Icons.alternate_email,
                                      color: purpleColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Change Email Address',
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

                        // Row 3: Reset Password
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

enum _RiderEmailStep {
  verifyCurrentEmail,
  enterNewEmail,
  verifyNewEmail,
  success,
}

class _RiderChangeEmailModal extends StatefulWidget {
  final String currentEmail;
  final bool isDark;
  final Color purpleColor;
  final Color cardBg;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final Color fieldBg;
  final Color fieldBorder;

  const _RiderChangeEmailModal({
    required this.currentEmail,
    required this.isDark,
    required this.purpleColor,
    required this.cardBg,
    required this.primaryTextColor,
    required this.mutedTextColor,
    required this.fieldBg,
    required this.fieldBorder,
  });

  @override
  State<_RiderChangeEmailModal> createState() => _RiderChangeEmailModalState();
}

class _RiderChangeEmailModalState extends State<_RiderChangeEmailModal> {
  _RiderEmailStep _currentStep = _RiderEmailStep.verifyCurrentEmail;

  final TextEditingController _currentOtpController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _newOtpController = TextEditingController();

  String _generatedCurrentOtp = '';
  String _generatedNewOtp = '';
  String _newEmail = '';

  bool _isLoading = false;
  String? _errorMessage;

  int _currentOtpCountdown = 30;
  Timer? _currentOtpTimer;
  bool _canResendCurrentOtp = false;

  int _newOtpCountdown = 30;
  Timer? _newOtpTimer;
  bool _canResendNewOtp = false;

  @override
  void initState() {
    super.initState();
    _initiateCurrentEmailOtp();
  }

  @override
  void dispose() {
    _currentOtpTimer?.cancel();
    _newOtpTimer?.cancel();
    _currentOtpController.dispose();
    _newEmailController.dispose();
    _newOtpController.dispose();
    super.dispose();
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  void _startCurrentOtpTimer() {
    _currentOtpTimer?.cancel();
    setState(() {
      _currentOtpCountdown = 30;
      _canResendCurrentOtp = false;
    });
    _currentOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_currentOtpCountdown <= 1) {
        timer.cancel();
        setState(() {
          _currentOtpCountdown = 0;
          _canResendCurrentOtp = true;
        });
      } else {
        setState(() {
          _currentOtpCountdown--;
        });
      }
    });
  }

  void _startNewOtpTimer() {
    _newOtpTimer?.cancel();
    setState(() {
      _newOtpCountdown = 30;
      _canResendNewOtp = false;
    });
    _newOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_newOtpCountdown <= 1) {
        timer.cancel();
        setState(() {
          _newOtpCountdown = 0;
          _canResendNewOtp = true;
        });
      } else {
        setState(() {
          _newOtpCountdown--;
        });
      }
    });
  }

  Future<void> _initiateCurrentEmailOtp() async {
    if (widget.currentEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Unable to identify current rider email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _generatedCurrentOtp = _generateOtp();
    debugPrint('Current Rider Email OTP: $_generatedCurrentOtp');

    try {
      final sent = await EmailService.sendOtpEmail(widget.currentEmail, _generatedCurrentOtp);
      if (!sent) {
        debugPrint('Resend sandbox notice: verification code is $_generatedCurrentOtp');
      }
      _startCurrentOtpTimer();
    } catch (e) {
      debugPrint('Error sending OTP to current rider email: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyCurrentOtp() async {
    final code = _currentOtpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code.';
      });
      return;
    }

    if (code != _generatedCurrentOtp) {
      setState(() {
        _errorMessage = 'Invalid verification code. Please check your email or resend code.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _currentStep = _RiderEmailStep.enterNewEmail;
    });
  }

  Future<void> _sendNewEmailOtp() async {
    final newEmail = _newEmailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (newEmail.isEmpty || !emailRegex.hasMatch(newEmail)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    if (newEmail == widget.currentEmail.toLowerCase()) {
      setState(() {
        _errorMessage = 'New email cannot be the same as your current email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _newEmail = newEmail;
    });

    try {
      // Check if new email is already registered in riders collection
      final existingDocs = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: _newEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (existingDocs.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'This email address is already registered to another rider account. Please use a different email.';
          });
        }
        return;
      }

      _generatedNewOtp = _generateOtp();
      debugPrint('New Rider Email OTP: $_generatedNewOtp');

      final sent = await EmailService.sendOtpEmail(_newEmail, _generatedNewOtp);
      if (!sent) {
        debugPrint('Resend sandbox notice: verification code is $_generatedNewOtp');
      }
      _startNewOtpTimer();
      if (mounted) {
        setState(() {
          _currentStep = _RiderEmailStep.verifyNewEmail;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to verify email address. Please check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyNewOtpAndCommit() async {
    final code = _newOtpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code.';
      });
      return;
    }

    if (code != _generatedNewOtp) {
      setState(() {
        _errorMessage = 'Invalid verification code. Please check your new email or resend code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.verifyBeforeUpdateEmail(_newEmail);
        } catch (authError) {
          debugPrint('Note on verifyBeforeUpdateEmail: $authError');
        }

        // Update in Firestore riders collection
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(user.uid)
            .set({
          'email': _newEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() {
          _currentStep = _RiderEmailStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
        setState(() {
          _errorMessage = 'Failed to update email address. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag Handle
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[700] : const Color(0xFFDCDCE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: AppTypography.font(12),
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── STEP 1: VERIFY CURRENT EMAIL ─────────────────────────────────
            if (_currentStep == _RiderEmailStep.verifyCurrentEmail) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.mail, size: 30, color: widget.purpleColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Verify Current Email',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: widget.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to ${_maskEmail(widget.currentEmail)} to verify your rider account.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: widget.mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // OTP Input
              _buildOtpTextField(
                controller: _currentOtpController,
                fieldBg: widget.fieldBg,
                fieldBorder: widget.fieldBorder,
                textColor: widget.primaryTextColor,
              ),
              const SizedBox(height: 16),

              // Resend Countdown
              _buildResendRow(
                canResend: _canResendCurrentOtp,
                countdown: _currentOtpCountdown,
                onResend: _initiateCurrentEmailOtp,
                purpleColor: widget.purpleColor,
                mutedTextColor: widget.mutedTextColor,
              ),
              const SizedBox(height: 24),

              _buildActionButton(
                label: 'Verify Current Email',
                isLoading: _isLoading,
                onTap: _verifyCurrentOtp,
                purpleColor: widget.purpleColor,
              ),
            ]

            // ── STEP 2: ENTER NEW EMAIL ──────────────────────────────────────
            else if (_currentStep == _RiderEmailStep.enterNewEmail) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.mailCheck, size: 30, color: widget.purpleColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter New Email',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: widget.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter the new email address you want to link to your MartFood Rider account.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: widget.mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: widget.fieldBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: widget.primaryTextColor,
                    fontSize: AppTypography.font(14),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(LucideIcons.mail, color: widget.purpleColor, size: 20),
                    hintText: 'Enter new email address',
                    hintStyle: TextStyle(
                      color: widget.mutedTextColor,
                      fontSize: AppTypography.font(14),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildActionButton(
                label: 'Send Verification Code',
                isLoading: _isLoading,
                onTap: _sendNewEmailOtp,
                purpleColor: widget.purpleColor,
              ),
            ]

            // ── STEP 3: VERIFY NEW EMAIL ─────────────────────────────────────
            else if (_currentStep == _RiderEmailStep.verifyNewEmail) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.keyRound, size: 30, color: widget.purpleColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Verify New Email',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: widget.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit confirmation code to $_newEmail. Enter it below to complete the change.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: widget.mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // OTP Input
              _buildOtpTextField(
                controller: _newOtpController,
                fieldBg: widget.fieldBg,
                fieldBorder: widget.fieldBorder,
                textColor: widget.primaryTextColor,
              ),
              const SizedBox(height: 16),

              // Resend Countdown
              _buildResendRow(
                canResend: _canResendNewOtp,
                countdown: _newOtpCountdown,
                onResend: _sendNewEmailOtp,
                purpleColor: widget.purpleColor,
                mutedTextColor: widget.mutedTextColor,
              ),
              const SizedBox(height: 24),

              _buildActionButton(
                label: 'Confirm & Update Email',
                isLoading: _isLoading,
                onTap: _verifyNewOtpAndCommit,
                purpleColor: widget.purpleColor,
              ),
            ]

            // ── STEP 4: SUCCESS ──────────────────────────────────────────────
            else if (_currentStep == _RiderEmailStep.success) ...[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.circleCheck, size: 38, color: Colors.green),
              ),
              const SizedBox(height: 18),
              Text(
                'Email Address Updated!',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: widget.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your MartFood Rider account email has been successfully changed to $_newEmail.',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: widget.mutedTextColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              _buildActionButton(
                label: 'Done',
                isLoading: false,
                onTap: () => Navigator.pop(context, true),
                purpleColor: widget.purpleColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtpTextField({
    required TextEditingController controller,
    required Color fieldBg,
    required Color fieldBorder,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fieldBorder, width: 1.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: AppTypography.font(24),
          fontWeight: FontWeight.w800,
          letterSpacing: 10,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••••',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: AppTypography.font(24),
            letterSpacing: 10,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildResendRow({
    required bool canResend,
    required int countdown,
    required VoidCallback onResend,
    required Color purpleColor,
    required Color mutedTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (canResend) ...[
          TextButton(
            onPressed: onResend,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resend Code',
              style: TextStyle(
                fontSize: AppTypography.font(13),
                fontWeight: FontWeight.bold,
                color: purpleColor,
              ),
            ),
          ),
        ] else ...[
          Text(
            'Resend code in 00:${countdown.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: AppTypography.font(13),
              color: mutedTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
    required Color purpleColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: purpleColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.font(15),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

