import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String _vehicleType = 'Bicycle';
  final String _selectedCountryCode = '+234';
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _isExistingMartFoodAccount = false;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _checkEmailStatus(showSheet: true);
      }
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailStatus({bool showSheet = true}) async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return;
    }

    try {
      // 1. Check if rider account already exists with this email
      final riderSnap = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: email)
          .get();

      if (riderSnap.docs.isNotEmpty) {
        final riderData = riderSnap.docs.first.data();
        final hasName = riderData['fullName'] != null && riderData['fullName'].toString().trim().isNotEmpty;
        if (hasName) {
          if (mounted && showSheet) {
            _showExistingRiderBottomSheet(email);
          }
          return;
        }
      }

      // 2. Check if this email exists on MartFood (as customer)
      final custSnap = await FirebaseFirestore.instance
          .collection('customers')
          .where('email', isEqualTo: email)
          .get();

      if (custSnap.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isExistingMartFoodAccount = true;
          });
          if (showSheet) {
            _showExistingAccountBottomSheet(email: email, isWrongPassword: false);
          }
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isExistingMartFoodAccount = false;
        });
      }
    } catch (_) {}
  }

  void _showExistingAccountBottomSheet({required String email, bool isWrongPassword = false}) {
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
                  isWrongPassword ? 'Incorrect MartFood Password' : 'Existing MartFood Account',
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
                      setState(() {
                        _isExistingMartFoodAccount = true;
                      });
                      _passwordFocusNode.requestFocus();
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
                      'Enter MartFood Password',
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
                      _startForgotPasswordFlow(email);
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
                      'Forgot Password? Reset it',
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/auth/login');
                  },
                  child: Text(
                    'Log in to existing account',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: purpleColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _handleUseDifferentEmail();
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

  void _showExistingRiderBottomSheet(String email) {
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
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.triangleAlert,
                    color: Colors.amber,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Rider Account Already Exists',
                  style: TextStyle(
                    fontSize: AppTypography.font(20),
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'A Rider account is already registered with $email. Please log in directly.',
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
                      context.push('/auth/login');
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
                      'Log in to Rider Account',
                      style: TextStyle(
                        fontSize: AppTypography.font(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _handleUseDifferentEmail();
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

  void _handleUseDifferentEmail() {
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _isExistingMartFoodAccount = false;
    });
    _emailFocusNode.requestFocus();
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

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
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

  Future<void> _signUp() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
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

    if (!_isExistingMartFoodAccount && password.length < 6) {
      AuthErrorHandler.showError(context, 'Password must be at least 6 characters');
      return;
    }

    if (!_isExistingMartFoodAccount && password != confirmPassword) {
      AuthErrorHandler.showError(context, 'Passwords do not match');
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      AuthErrorHandler.showError(
        context,
        'Phone number must be at least 10 digits.',
      );
      return;
    }

    if (cleanPhone.length > 11) {
      AuthErrorHandler.showError(
        context,
        'Phone number cannot exceed 11 digits.',
      );
      return;
    }

    final sanitizedPhone = cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone;
    final phoneRegex = RegExp(r'^[789]\d{9}$');
    if (_selectedCountryCode == '+234' && !phoneRegex.hasMatch(sanitizedPhone)) {
      AuthErrorHandler.showError(
        context,
        'Please enter a valid Nigerian phone number (e.g. 08012345678 or 8012345678).',
      );
      return;
    }

    final fullPhoneNumber = '$_selectedCountryCode$sanitizedPhone';

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Check if rider account already exists
      final riderSnap = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: email)
          .get();

      if (riderSnap.docs.isNotEmpty) {
        final riderData = riderSnap.docs.first.data();
        final hasName = riderData['fullName'] != null && riderData['fullName'].toString().trim().isNotEmpty;
        if (hasName) {
          setState(() {
            _isLoading = false;
          });
          _showExistingRiderBottomSheet(email);
          return;
        }
      }

      // 2. Check if existing MartFood customer account
      bool isExisting = _isExistingMartFoodAccount;
      if (!isExisting) {
        final custSnap = await FirebaseFirestore.instance
            .collection('customers')
            .where('email', isEqualTo: email)
            .get();
        if (custSnap.docs.isNotEmpty) {
          isExisting = true;
          setState(() {
            _isExistingMartFoodAccount = true;
          });
        }
      }

      // If user is existing MartFood account, test their password!
      if (isExisting) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (authEx) {
          setState(() {
            _isLoading = false;
          });
          if (authEx.code == 'wrong-password' || authEx.code == 'invalid-credential') {
            _showExistingAccountBottomSheet(email: email, isWrongPassword: true);
            return;
          }
          rethrow;
        }
      }

      final otpCode = (Random().nextInt(9000) + 1000).toString();
      debugPrint('[Rider Registration] Generated OTP for $email: $otpCode');

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
          'otp': otpCode,
          'isExistingMartFoodAccount': isExisting,
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AuthErrorHandler.showError(context, e);
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
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
                      focusNode: _emailFocusNode,
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

                  // ── Existing MartFood Account Inline Banner ───────────────
                  if (_isExistingMartFoodAccount) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: purpleColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: purpleColor.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.store, size: 18, color: purpleColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Existing MartFood Account Found',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(14),
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You already have a MartFood account. Enter your MartFood password to activate your Rider profile.',
                            style: TextStyle(
                              fontSize: AppTypography.font(13),
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              GestureDetector(
                                onTap: () => context.push('/auth/login'),
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(13),
                                    fontWeight: FontWeight.bold,
                                    color: purpleColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _startForgotPasswordFlow(_emailController.text.trim()),
                                child: Text(
                                  'Forgot password? Reset it',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(13),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _handleUseDifferentEmail,
                                child: Text(
                                  'Use a different email to register',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(13),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── 7. Field 6: Password ────────────────────────────────
                  Text(
                    _isExistingMartFoodAccount ? 'MartFood Password' : 'Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SignupPasswordTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hintText: _isExistingMartFoodAccount ? 'Enter your MartFood password' : 'Create password',
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    textColor: textColor,
                    purpleColor: purpleColor,
                  ),
                  const SizedBox(height: 20),

                  // ── 8. Field 7: Confirm Password ────────────────────────
                  if (!_isExistingMartFoodAccount) ...[
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
                  ],

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
                              _isExistingMartFoodAccount ? 'Activate Rider Profile' : 'Sign Up',
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
  final FocusNode? focusNode;
  final String hintText;
  final Color fieldBg;
  final Color fieldBorder;
  final Color textColor;
  final Color purpleColor;

  const _SignupPasswordTextField({
    required this.controller,
    this.focusNode,
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
        focusNode: widget.focusNode,
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
