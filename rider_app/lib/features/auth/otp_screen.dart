import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'auth_error_handler.dart';
import 'email_service.dart';

class OtpScreen extends StatefulWidget {
  final Map<String, dynamic> riderData;

  const OtpScreen({
    super.key,
    required this.riderData,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
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
    _generatedOtp = (1000 + Random().nextInt(9000)).toString();
    debugPrint('[OTP] Generated registration OTP for $_email: $_generatedOtp');
    // Dispatch OTP on screen open
    EmailService.sendOtpEmail(_email, _generatedOtp!);
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

      // 1. Create Firebase Auth User
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _email,
            password: _password,
          )
          .timeout(const Duration(seconds: 8));

      final uid = credential.user?.uid;
      if (uid != null) {
        String photoUrl = '';

        // 2. Upload photo if provided
        if (_photoPath != null && _photoPath!.isNotEmpty) {
          final file = File(_photoPath!);
          if (await file.exists()) {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('rider_profiles')
                .child('$uid.jpg');
            await storageRef.putFile(file).timeout(const Duration(seconds: 8));
            photoUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 5));
          }
        }

        // 3. Store in Firestore collection 'riders'
        await FirebaseFirestore.instance.collection('riders').doc(uid).set({
          'uid': uid,
          'email': _email,
          'fullName': _fullName,
          'username': _username.isNotEmpty ? _username : _email.split('@').first,
          'phone': _phone,
          'vehicleType': _vehicleType,
          'photoUrl': photoUrl,
          'walletBalance': 0.0,
          'verificationStatus': 'unverified',
          'rejectionReason': '',
          'completedOrders': 0,
          'status': 'offline',
          'isOnline': false,
          'currentLocation': const GeoPoint(6.5244, 3.3792),
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
      }

      if (mounted) {
        _showSuccessBottomSheet();
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

  void _showSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
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
              const SizedBox(height: 24),
              Icon(
                Icons.verified,
                color: purpleColor,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                'Successful',
                style: TextStyle(
                  color: textColor,
                  fontSize: AppTypography.font(26),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been created successfully.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: AppTypography.font(15),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    context.pop();
                    context.go('/home');
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
                    'Done',
                    style: TextStyle(
                      fontSize: AppTypography.font(16),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
