import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../providers/session_provider.dart';
import '../home/home_screen.dart';
import 'auth_error_handler.dart';
import 'email_service.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> riderData;

  const OtpScreen({
    super.key,
    required this.riderData,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _code = '';
  bool _isLoading = false;
  String? _generatedOtp;

  int _timerSeconds = 30;
  Timer? _timer;

  String get _email => (widget.riderData['email'] as String? ?? '').trim();
  String get _password => widget.riderData['password'] as String? ?? '';
  String get _fullName => widget.riderData['fullName'] as String? ?? '';
  String get _username => widget.riderData['username'] as String? ?? '';
  String get _phone => widget.riderData['phone'] as String? ?? '';
  String get _vehicleType => widget.riderData['vehicleType'] as String? ?? 'Bicycle';
  String? get _photoPath => widget.riderData['photoPath'] as String?;

  @override
  void initState() {
    super.initState();
    _startTimer();
    final initialOtp = widget.riderData['otp'] as String?;
    if (initialOtp != null && initialOtp.isNotEmpty) {
      _generatedOtp = initialOtp;
    } else {
      _generatedOtp = (1000 + Random().nextInt(9000)).toString();
      EmailService.sendOtpEmail(_email, _generatedOtp!);
    }
    debugPrint('[OTP] Active registration OTP for $_email: $_generatedOtp');
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    if (_timerSeconds > 0 || _isLoading) return;

    final newOtp = (1000 + Random().nextInt(9000)).toString();
    setState(() {
      _generatedOtp = newOtp;
      _code = '';
      _codeController.clear();
    });
    _focusNode.requestFocus();

    _startTimer();
    final sent = await EmailService.sendOtpEmail(_email, newOtp);

    if (mounted) {
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code resent to $_email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send email. For testing, enter code: $newOtp'),
            duration: const Duration(seconds: 15),
          ),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    final enteredOtp = _codeController.text.trim();
    if (enteredOtp.length < 4) {
      AuthErrorHandler.showError(context, 'Please enter the 4-digit code');
      return;
    }

    if (_timerSeconds <= 0) {
      AuthErrorHandler.showError(
        context,
        'The verification code has expired. Please request a new code.',
      );
      return;
    }

    if (_generatedOtp != null && enteredOtp != _generatedOtp) {
      AuthErrorHandler.showError(context, 'Invalid OTP code. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_email.isEmpty || _password.isEmpty) {
        throw Exception('Rider registration data is missing.');
      }

      // 1. Create Firebase Auth User or Link Existing MartFood Account
      String? uid;
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _email,
              password: _password,
            )
            .timeout(const Duration(seconds: 15));
        uid = credential.user?.uid;
      } on FirebaseAuthException catch (authEx) {
        if (authEx.code == 'email-already-in-use') {
          try {
            final existingCred = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
                  email: _email,
                  password: _password,
                )
                .timeout(const Duration(seconds: 15));
            final existingUid = existingCred.user?.uid;
            if (existingUid != null) {
              final riderDoc = await FirebaseFirestore.instance
                  .collection('riders')
                  .doc(existingUid)
                  .get();
              final riderData = riderDoc.data();
              final bool hasCompletedProfile = riderDoc.exists &&
                  riderData != null &&
                  riderData.containsKey('fullName') &&
                  riderData['fullName'] != null &&
                  riderData['fullName'].toString().trim().isNotEmpty;
              if (hasCompletedProfile) {
                throw Exception(
                  'A Rider account with this email already exists. Please log in directly.',
                );
              }
              uid = existingUid;
            }
          } on FirebaseAuthException catch (signInEx) {
            if (signInEx.code == 'wrong-password' || signInEx.code == 'invalid-credential') {
              throw Exception(
                'You already have a MartFood account. Enter your MartFood password to activate your Rider profile.',
              );
            }
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      if (uid != null) {
        // 2. Store in Firestore collection 'riders' FIRST with merge (guarantees account is created immediately)
        await FirebaseFirestore.instance.collection('riders').doc(uid).set({
          'uid': uid,
          'email': _email,
          'fullName': _fullName,
          'username': _username.isNotEmpty ? _username : _email.split('@').first,
          'phone': _phone,
          'vehicleType': _vehicleType,
          'photoUrl': '',
          'walletBalance': 0.0,
          'verificationStatus': 'unverified',
          'rejectionReason': '',
          'completedOrders': 0,
          'status': 'offline',
          'isOnline': false,
          'currentLocation': const GeoPoint(6.5244, 3.3792),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));

        // 3. Upload photo asynchronously in background so rider transitions instantly
        if (_photoPath != null && _photoPath!.isNotEmpty) {
          _uploadPhotoInBackground(uid, _photoPath!);
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
        final errText = e.toString().toLowerCase();
        if (errText.contains('martfood account') ||
            errText.contains('activate your rider profile') ||
            errText.contains('wrong-password') ||
            errText.contains('invalid-credential')) {
          _showExistingAccountBottomSheet();
        } else {
          AuthErrorHandler.showError(context, e);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showExistingAccountBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.bike,
                    color: purpleColor,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Existing MartFood Account',
                  style: TextStyle(
                    fontSize: AppTypography.font(20),
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'You already have a MartFood account. Enter your MartFood password to activate your Rider profile.',
                  style: TextStyle(
                    fontSize: AppTypography.font(14),
                    color: subtextColor,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _startForgotPasswordFlow(_email);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Forgot Password? Reset it',
                      style: TextStyle(
                        fontSize: AppTypography.font(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/auth/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                        width: 1.0,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Log in to existing account',
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.pop();
                  },
                  child: Text(
                    'Use a different email to register',
                    style: TextStyle(
                      fontSize: AppTypography.font(13),
                      color: subtextColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startForgotPasswordFlow(String email) async {
    final normEmail = email.trim().toLowerCase();
    if (normEmail.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final otpCode = (Random().nextInt(900000) + 100000).toString();

      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(normEmail)
          .set({
        'otp': otpCode,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
      }).timeout(const Duration(seconds: 5));

      final sent = await EmailService.sendPasswordResetOtp(normEmail, otpCode);
      if (mounted) {
        if (sent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code sent to $normEmail'),
              backgroundColor: Colors.green,
            ),
          );
        }
        context.push('/auth/forgot-password-otp', extra: {
          'email': normEmail,
          'otp': otpCode,
        });
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

  void _uploadPhotoInBackground(String uid, String path) {
    Future.microtask(() async {
      try {
        final file = File(path);
        if (await file.exists()) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('rider_profiles')
              .child('$uid.jpg');
          await storageRef.putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final photoUrl = await storageRef.getDownloadURL();
          await FirebaseFirestore.instance
              .collection('riders')
              .doc(uid)
              .update({'photoUrl': photoUrl});
        }
      } catch (e) {
        debugPrint('Background rider photo upload error: $e');
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify Email',
                    style: TextStyle(
                      fontSize: AppTypography.font(32),
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 4-digit code sent to $_email.',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Seamless 4-Digit Inputs with continuous backspace ────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _focusNode.requestFocus(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) {
                              final isFilled = index < _code.length;
                              final isCurrent = _focusNode.hasFocus &&
                                  (index == _code.length || (index == 3 && _code.length == 4));
                              final digit = isFilled ? _code[index] : '';

                              return Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCurrent
                                        ? purpleColor
                                        : (isFilled ? purpleColor.withValues(alpha: 0.5) : borderColor),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    digit,
                                    style: TextStyle(
                                      fontSize: AppTypography.font(24),
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: _codeController,
                            focusNode: _focusNode,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            enabled: !_isLoading,
                            onChanged: (val) {
                              setState(() {
                                _code = val;
                              });
                              if (val.length == 4) {
                                _verifyOtp();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Dynamic Resend Timer ─────────────────────────────────
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive code? ",
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            color: mutedTextColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: _resendCode,
                          child: Text(
                            _timerSeconds > 0
                                ? 'Resend in 00:${_timerSeconds.toString().padLeft(2, '0')}'
                                : 'Resend Code',
                            style: TextStyle(
                              fontSize: AppTypography.font(14),
                              fontWeight: FontWeight.bold,
                              color: _timerSeconds > 0 ? mutedTextColor : purpleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Action Button ────────────────────────────────────────
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: purpleColor),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
