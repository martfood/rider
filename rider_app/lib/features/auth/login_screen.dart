import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/services/account_status_service.dart';
import '../../providers/session_provider.dart';
import '../home/home_screen.dart';
import 'auth_error_handler.dart';
import 'email_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? suspensionReason;
  final String? suspendedUntil;

  const LoginScreen({
    super.key,
    this.suspensionReason,
    this.suspendedUntil,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.suspensionReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AccountStatusService.showSuspensionSheet(
            context,
            reason: widget.suspensionReason!,
            suspendedUntil: widget.suspendedUntil,
          );
        }
      });
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AuthErrorHandler.showError(context, 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 5));

      final user = userCredential.user;
      if (user != null) {
        final docSnap = await FirebaseFirestore.instance
            .collection('riders')
            .doc(user.uid)
            .get();

        if (docSnap.exists) {
          if (AccountStatusService.isSuspended(docSnap.data())) {
            final info = AccountStatusService.parseSuspension(docSnap.data());
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              AccountStatusService.showSuspensionSheet(
                context,
                reason: info.reason,
                suspendedUntil: info.suspendedUntil,
              );
            }
            return;
          }
        } else {
          // Document does not exist in riders collection -> prompt rider profile activation
          if (mounted) {
            _showActivateRiderProfileBottomSheet(user);
          }
          return;
        }
      }

      if (mounted) {
        HomeScreen.resetVerificationPrompt();
        ref.read(sessionProvider.notifier).signIn();
        resetAllRiderProviders(ref);
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showActivateRiderProfileBottomSheet(User user) async {
    String existingName = '';
    String existingPhone = '';
    String existingPhotoUrl = '';

    try {
      final custDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      if (custDoc.exists && custDoc.data() != null) {
        final d = custDoc.data()!;
        existingName = (d['fullName'] ?? '').toString();
        existingPhone = (d['phoneNumber'] ?? d['phone'] ?? '').toString();
        existingPhotoUrl = (d['profilePic'] ?? d['photoUrl'] ?? '').toString();
      } else {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(user.uid)
            .get();
        if (vendorDoc.exists && vendorDoc.data() != null) {
          final d = vendorDoc.data()!;
          existingName = (d['fullName'] ?? '').toString();
          existingPhone = (d['phone'] ?? '').toString();
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;

    String selectedVehicle = 'Bicycle';
    bool isActivating = false;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      elevation: 0,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Responsive.maxContainer(
                context: ctx,
                maxWidth: 450,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.bike,
                            color: purpleColor,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Activate Rider Account',
                        style: TextStyle(
                          fontSize: AppTypography.font(20),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We found your MartFood account (${user.email}). Would you like to activate a Rider profile with this account to start delivering and earning?',
                        style: TextStyle(
                          fontSize: AppTypography.font(14),
                          color: mutedTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Primary Delivery Vehicle',
                          style: TextStyle(
                            fontSize: AppTypography.font(13),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedVehicle,
                            isExpanded: true,
                            dropdownColor: sheetBg,
                            icon: Icon(Icons.keyboard_arrow_down, color: primaryTextColor),
                            items: const [
                              DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                              DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
                              DropdownMenuItem(value: 'E-bike', child: Text('E-bike')),
                            ],
                            onChanged: isActivating
                                ? null
                                : (v) {
                                    if (v != null) {
                                      setSheetState(() => selectedVehicle = v);
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isActivating
                            ? null
                            : () async {
                                setSheetState(() => isActivating = true);
                                try {
                                  final fullName = existingName.isNotEmpty
                                      ? existingName
                                      : (user.displayName ?? user.email!.split('@').first);
                                  await FirebaseFirestore.instance
                                      .collection('riders')
                                      .doc(user.uid)
                                      .set({
                                    'uid': user.uid,
                                    'email': user.email ?? '',
                                    'fullName': fullName,
                                    'username': user.email!.split('@').first,
                                    'phone': existingPhone,
                                    'vehicleType': selectedVehicle,
                                    'photoUrl': existingPhotoUrl,
                                    'walletBalance': 0.0,
                                    'verificationStatus': 'unverified',
                                    'rejectionReason': '',
                                    'completedOrders': 0,
                                    'status': 'offline',
                                    'isOnline': false,
                                    'currentLocation': const GeoPoint(6.5244, 3.3792),
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    HomeScreen.resetVerificationPrompt();
                                    ref.read(sessionProvider.notifier).signIn();
                                    resetAllRiderProviders(ref);
                                    context.go('/home');
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setSheetState(() => isActivating = false);
                                  }
                                  if (mounted) {
                                    AuthErrorHandler.showError(context, e);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isActivating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Activate Rider Profile',
                                style: TextStyle(
                                  fontSize: AppTypography.font(15),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isActivating
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await FirebaseAuth.instance.signOut();
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordBottomSheet() {
    final emailController = TextEditingController(text: _emailController.text);
    bool dialogLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Drag Handle ──────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(22),
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your email address and we will send you a 6-digit OTP code to reset your password.',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
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
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppTypography.font(14)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty) {
                                AuthErrorHandler.showError(context, 'Please enter your email address');
                                return;
                              }

                              setDialogState(() {
                                dialogLoading = true;
                              });

                              final otpCode = (100000 + Random().nextInt(900000)).toString();

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

                                final sent = await EmailService.sendPasswordResetOtp(email, otpCode);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (sent) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Verification code sent to $email'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    AuthErrorHandler.showError(context, 'Failed to send email. Please try again.');
                                  }
                                  context.push('/auth/forgot-password-otp', extra: {
                                    'email': email,
                                    'otp': otpCode,
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
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
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Send Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── 1. Header ───────────────────────────────────────────
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: AppTypography.font(32),
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to continue delivering with MartFood.',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 2. Field 1: Email / Phone Number ────────────────────
                  Text(
                    'Email / Phone Number',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor, fontSize: AppTypography.font(14)),
                      decoration: InputDecoration(
                        hintText: 'Enter email or phone number',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppTypography.font(14)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 3. Field 2: Password ────────────────────────────────
                  Text(
                    'Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setObscureState) {
                      return _PasswordTextField(
                        controller: _passwordController,
                        fieldBg: fieldBg,
                        fieldBorder: fieldBorder,
                        textColor: textColor,
                        purpleColor: purpleColor,
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── 4. Forgot Password (Left-aligned) ───────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _showForgotPasswordBottomSheet,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password ?',
                        style: TextStyle(
                          color: purpleColor,
                          fontSize: AppTypography.font(14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── 5. Login Button ─────────────────────────────────────
                  _isLoading
                      ? Center(child: CircularProgressIndicator(color: purpleColor))
                      : SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Login',
                              style: TextStyle(
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),

                  // ── 6. Don't have an account ? Sign Up ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account ? ",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: AppTypography.font(14),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/auth/register'),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: purpleColor,
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for password field with toggleable eye icon
class _PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final Color fieldBg;
  final Color fieldBorder;
  final Color textColor;
  final Color purpleColor;

  const _PasswordTextField({
    required this.controller,
    required this.fieldBg,
    required this.fieldBorder,
    required this.textColor,
    required this.purpleColor,
  });

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.fieldBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: widget.fieldBorder, width: 1.0),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        style: TextStyle(color: widget.textColor, fontSize: AppTypography.font(14)),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppTypography.font(14)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: widget.purpleColor,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          ),
        ),
      ),
    );
  }
}
