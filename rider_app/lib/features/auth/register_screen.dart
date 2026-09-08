import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'auth_error_handler.dart';
import 'email_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _vehicleType = 'Bicycle';
  final String _selectedCountryCode = '+234';
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveGoogleAccount(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_google_name', user.displayName ?? 'Google User');
    await prefs.setString('last_google_email', user.email ?? '');
    await prefs.setString('last_google_photo', user.photoURL ?? '');
    await prefs.setBool('has_previous_google_login', true);
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      AuthErrorHandler.showError(context, 'Unable to open gallery. (${e.code})');
    } catch (e) {
      if (!mounted) return;
      AuthErrorHandler.showError(context, 'Unable to open gallery. Please try again.');
    }
  }

  void _signUp() {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_agreeToTerms) {
      AuthErrorHandler.showError(
        context,
        'Please accept the Terms of Use and Privacy Policy to continue.',
      );
      return;
    }

    if (fullName.isEmpty ||
        username.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      AuthErrorHandler.showError(context, 'Please fill all required fields');
      return;
    }

    if (password.length < 6) {
      AuthErrorHandler.showError(context, 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      AuthErrorHandler.showError(context, 'Passwords do not match');
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final sanitizedPhone = cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone;
    if (sanitizedPhone.length < 10 || sanitizedPhone.length > 11) {
      AuthErrorHandler.showError(context, 'Enter a valid 10-digit phone number');
      return;
    }

    final phoneRegex = RegExp(r'^[789]\d{9}$');
    if (_selectedCountryCode == '+234' && !phoneRegex.hasMatch(sanitizedPhone)) {
      AuthErrorHandler.showError(
        context,
        'Please enter a valid Nigerian phone number (e.g. 8031234567).',
      );
      return;
    }

    final fullPhoneNumber = '$_selectedCountryCode$sanitizedPhone';

    setState(() {
      _isLoading = true;
    });

    final otpCode = (Random().nextInt(9000) + 1000).toString();
    debugPrint('[Rider Registration] Generated OTP for $email: $otpCode');

    // Attempt to send email in background
    EmailService.sendOtpEmail(email, otpCode);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      context.push('/auth/otp', extra: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'username': username,
        'phone': fullPhoneNumber,
        'vehicleType': _vehicleType,
        'photoPath': _imageFile?.path,
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '45361321160-9ofs6jkpgbk539bjl5bdro0fnknhavtl.apps.googleusercontent.com',
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _saveGoogleAccount(user);
        final docRef = FirebaseFirestore.instance.collection('riders').doc(user.uid);
        final docSnap = await docRef.get();

        if (!docSnap.exists) {
          await docRef.set({
            'uid': user.uid,
            'email': user.email ?? '',
            'fullName': user.displayName ?? '',
            'username': (user.email ?? '').split('@').first,
            'phone': user.phoneNumber ?? '',
            'vehicleType': 'Bicycle',
            'photoUrl': user.photoURL ?? '',
            'walletBalance': 0.0,
            'verificationStatus': 'unverified',
            'rejectionReason': '',
            'completedOrders': 0,
            'status': 'offline',
            'isOnline': false,
            'currentLocation': const GeoPoint(6.5244, 3.3792),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          context.go('/home');
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
                  const SizedBox(height: 16),

                  // ── 1. Header ───────────────────────────────────────────
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: AppTypography.font(32),
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join MartFood delivery network and start earning.',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Optional Profile Picture Picker ─────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                            child: _imageFile == null
                                ? Icon(Icons.camera_alt_outlined, size: 28, color: Colors.grey[600])
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: purpleColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 2. Field 1: Full Name ───────────────────────────────
                  Text(
                    'Full Name',
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
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: textColor, fontSize: AppTypography.font(14)),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppTypography.font(14)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 3. Field 2: Username ────────────────────────────────
                  Text(
                    'Username',
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
                      controller: _usernameController,
                      style: TextStyle(color: textColor, fontSize: AppTypography.font(14)),
                      decoration: InputDecoration(
                        hintText: 'Enter your username',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppTypography.font(14)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 4. Field 3: Phone Number ────────────────────────────
                  Text(
                    'Phone Number',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedCountryCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTypography.font(14),
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ],
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: isDark ? AppTheme.darkBorder : Colors.grey[300],
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: textColor, fontSize: AppTypography.font(14)),
                            decoration: InputDecoration(
                              hintText: 'Enter phone number',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppTypography.font(14)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 5. Field 4: Vehicle Type ────────────────────────────
                  Text(
                    'Vehicle Type',
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _vehicleType,
                        isExpanded: true,
                        dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                        style: TextStyle(color: textColor, fontSize: AppTypography.font(14)),
                        icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        items: const [
                          DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                          DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _vehicleType = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 6. Field 5: Email Address ───────────────────────────
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
                      controller: _emailController,
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
                  const SizedBox(height: 20),

                  // ── 7. Field 6: Password ────────────────────────────────
                  Text(
                    'Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SignupPasswordTextField(
                    controller: _passwordController,
                    hintText: 'Create password',
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    textColor: textColor,
                    purpleColor: purpleColor,
                  ),
                  const SizedBox(height: 20),

                  // ── 8. Field 7: Confirm Password ────────────────────────
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SignupPasswordTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm password',
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    textColor: textColor,
                    purpleColor: purpleColor,
                  ),
                  const SizedBox(height: 16),

                  // ── 9. Terms & Conditions Row ───────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _agreeToTerms,
                          activeColor: purpleColor,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to MartFood ',
                            style: TextStyle(
                              fontSize: AppTypography.font(12.5),
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: 'Terms of Use',
                                style: TextStyle(
                                  color: purpleColor,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: purpleColor,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push('/account/legal/terms-of-use');
                                  },
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: purpleColor,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: purpleColor,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push('/account/legal/privacy-policy');
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── 10. Sign Up Action Button ───────────────────────────
                  _isLoading
                      ? Center(child: CircularProgressIndicator(color: purpleColor))
                      : SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _agreeToTerms ? _signUp : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              disabledBackgroundColor: purpleColor.withValues(alpha: 0.4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),

                  // ── 11. Already have an account? Login ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: AppTypography.font(14),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/auth/login'),
                        child: Text(
                          'Login',
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

                  if (defaultTargetPlatform != TargetPlatform.iOS) ...[
                    // ── 12. Or Divider ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark ? AppTheme.darkBorder : Colors.grey[300],
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Or',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: AppTypography.font(14),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark ? AppTheme.darkBorder : Colors.grey[300],
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── 13. Social Sign Up Button ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _signUpWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? AppTheme.darkBorder : AppTheme.lightPurpleBorder,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://pngimg.com/uploads/google/google_PNG19635.png',
                              height: 22,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.g_mobiledata,
                                size: 24,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Sign up with Google',
                              style: TextStyle(
                                color: textColor,
                                fontSize: AppTypography.font(15),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

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
class _SignupPasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fieldBg;
  final Color fieldBorder;
  final Color textColor;
  final Color purpleColor;

  const _SignupPasswordTextField({
    required this.controller,
    required this.hintText,
    required this.fieldBg,
    required this.fieldBorder,
    required this.textColor,
    required this.purpleColor,
  });

  @override
  State<_SignupPasswordTextField> createState() => _SignupPasswordTextFieldState();
}

class _SignupPasswordTextFieldState extends State<_SignupPasswordTextField> {
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
          hintText: widget.hintText,
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
