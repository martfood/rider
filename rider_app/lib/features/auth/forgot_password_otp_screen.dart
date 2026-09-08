import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'auth_error_handler.dart';
import 'email_service.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _code = '';
  late String _currentOtp;
  bool _isLoading = false;
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.otp;
    _startTimer();
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

    final newOtp = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _currentOtp = newOtp;
      _isLoading = true;
      _code = '';
      _codeController.clear();
    });
    _focusNode.requestFocus();

    try {
      final normEmail = widget.email.trim().toLowerCase();
      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(normEmail)
          .set({
        'otp': newOtp,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: 30)),
        ),
      }).timeout(const Duration(seconds: 5));

      final sent = await EmailService.sendPasswordResetOtp(widget.email, newOtp);

      _startTimer();

      if (mounted) {
        if (sent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New verification code sent to ${widget.email}'),
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
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _verifyOtp() {
    if (_isLoading) return;

    final enteredOtp = _codeController.text.trim();
    if (enteredOtp.length < 6) {
      AuthErrorHandler.showError(context, 'Please enter the complete 6-digit code');
      return;
    }

    if (_timerSeconds <= 0) {
      AuthErrorHandler.showError(
        context,
        'The recovery code has expired. Please request a new code.',
      );
      return;
    }

    if (enteredOtp == _currentOtp) {
      context.push('/auth/reset-forgotten-password', extra: {
        'email': widget.email,
        'otp': enteredOtp,
      });
    } else {
      AuthErrorHandler.showError(context, 'Invalid code. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : Colors.white;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

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
                  const SizedBox(height: 8),

                  Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: AppTypography.font(32),
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Enter the code sent to recover your account.',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 36),

                  Text(
                    'Code',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Seamless 6-Digit Inputs with continuous backspace ────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _focusNode.requestFocus(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) {
                              final isFilled = index < _code.length;
                              final isCurrent = _focusNode.hasFocus &&
                                  (index == _code.length || (index == 5 && _code.length == 6));
                              final digit = isFilled ? _code[index] : '';

                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: fieldBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCurrent
                                        ? purpleColor
                                        : (isFilled ? purpleColor.withValues(alpha: 0.5) : fieldBorder),
                                    width: isCurrent ? 2 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    digit.isNotEmpty ? digit : '•',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(18),
                                      fontWeight: FontWeight.bold,
                                      color: digit.isNotEmpty
                                          ? textColor
                                          : (isDark ? Colors.grey[500] : Colors.grey[400]),
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
                              LengthLimitingTextInputFormatter(6),
                            ],
                            enabled: !_isLoading,
                            onChanged: (val) {
                              setState(() {
                                _code = val;
                              });
                              if (val.length == 6) {
                                _verifyOtp();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

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
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 24),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive code? ",
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            color: subtextColor,
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
                              color: _timerSeconds > 0 ? subtextColor : purpleColor,
                            ),
                          ),
                        ),
                      ],
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
