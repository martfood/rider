import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../providers/rider_profile_provider.dart';

/// Redesigned ID & Document Verification screen for MartFood Riders.
/// Strictly adheres to the Minimal & Flat design rules with zero elevation,
/// centralized color tokens, crisp hierarchy, and responsive layout.
class IdDocumentsScreen extends ConsumerStatefulWidget {
  const IdDocumentsScreen({super.key});

  @override
  ConsumerState<IdDocumentsScreen> createState() => _IdDocumentsScreenState();
}

class _IdDocumentsScreenState extends ConsumerState<IdDocumentsScreen> {
  final _ninController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _picker = ImagePicker();

  File? _ninFile;
  File? _vehiclePhotoFile;
  bool _isLoading = false;
  bool _hasInitialized = false;

  // Inline error states
  String? _ninError;
  String? _ninFileError;
  String? _plateError;
  String? _vehiclePhotoError;

  @override
  void initState() {
    super.initState();
    _ninController.addListener(_onFormInputChanged);
    _plateNumberController.addListener(_onFormInputChanged);
  }

  void _onFormInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('riders').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          if (data['ninNumber'] != null && _ninController.text.isEmpty) {
            _ninController.text = data['ninNumber'].toString();
          }
          if (data['vehiclePlateNumber'] != null &&
              _plateNumberController.text.isEmpty) {
            _plateNumberController.text = data['vehiclePlateNumber'].toString();
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ninController.removeListener(_onFormInputChanged);
    _plateNumberController.removeListener(_onFormInputChanged);
    _ninController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickNinFile() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _ninFile = File(picked.path);
          _ninFileError = null;
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar('Gallery permission error: ${e.message ?? e.code}', isError: true);
    } catch (_) {
      if (!mounted) return;
      _showFeedbackSnackBar('Could not select image from gallery.', isError: true);
    }
  }

  Future<void> _pickVehiclePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _vehiclePhotoFile = File(picked.path);
          _vehiclePhotoError = null;
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar('Gallery permission error: ${e.message ?? e.code}', isError: true);
    } catch (_) {
      if (!mounted) return;
      _showFeedbackSnackBar('Could not select image from gallery.', isError: true);
    }
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    // Reset errors
    setState(() {
      _ninError = null;
      _ninFileError = null;
      _plateError = null;
      _vehiclePhotoError = null;
    });

    final profile = ref.read(riderProfileProvider);
    final isMotorcycle = profile.vehicleLabel.toLowerCase().contains('motorcycle') ||
        profile.vehicleLabel.toLowerCase().contains('bike');

    final nin = _ninController.text.trim();
    final plate = _plateNumberController.text.trim();
    bool hasError = false;

    // Strict 11-digit NIN Validation
    if (nin.isEmpty) {
      _ninError = 'NIN number is required.';
      hasError = true;
    } else if (nin.length != 11 || !RegExp(r'^\d{11}$').hasMatch(nin)) {
      _ninError = 'NIN must be exactly 11 numbers.';
      hasError = true;
    }

    // NIN Document Image Validation
    if (_ninFile == null) {
      _ninFileError = 'Please upload your NIN document / slip photo.';
      hasError = true;
    }

    // Vehicle Plate Number Validation
    if (isMotorcycle && plate.isEmpty) {
      _plateError = 'Vehicle plate number is required for Motorcycles.';
      hasError = true;
    }

    // Vehicle Photo Validation
    if (_vehiclePhotoFile == null) {
      _vehiclePhotoError = 'Please upload a photo of your delivery vehicle.';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      _showFeedbackSnackBar(
        _ninError ??
            _ninFileError ??
            _plateError ??
            _vehiclePhotoError ??
            'Please complete all required fields correctly.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('User is not authenticated.');
      }

      // 1. Upload NIN Document image
      final ninStorageRef = FirebaseStorage.instance
          .ref()
          .child('riders')
          .child(uid)
          .child('nin_document_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ninStorageRef.putFile(_ninFile!);
      final ninUrl = await ninStorageRef.getDownloadURL();

      // 2. Upload Vehicle Photo
      final vehicleStorageRef = FirebaseStorage.instance
          .ref()
          .child('riders')
          .child(uid)
          .child('vehicle_photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await vehicleStorageRef.putFile(_vehiclePhotoFile!);
      final vehicleUrl = await vehicleStorageRef.getDownloadURL();

      // 3. Update Firestore Document
      await FirebaseFirestore.instance.collection('riders').doc(uid).update({
        'ninNumber': nin,
        'ninFileUrl': ninUrl,
        'vehiclePlateNumber': plate,
        'vehiclePhotoUrl': vehicleUrl,
        'verificationStatus': 'pending',
        'rejectionReason': '',
        'documentsSubmittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showFeedbackSnackBar('Documents submitted successfully! Under admin review.');
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar('Failed to submit documents: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(riderProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : const Color(0xFFE9EAF0);

    final isMotorcycle = profile.vehicleLabel.toLowerCase().contains('motorcycle') ||
        profile.vehicleLabel.toLowerCase().contains('bike');

    final status = profile.verificationStatus.toLowerCase();
    final isVerified = status == 'verified';
    final isUnderReview = status == 'pending';
    final isRejected = status == 'rejected';

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
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE9EAF0),
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
          'ID & Verification',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. STATUS HERO CARD ──────────────────────────────────
                  if (isVerified)
                    _buildVerifiedCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      mutedTextColor: mutedTextColor,
                      purpleColor: purpleColor,
                      profile: profile,
                    )
                  else if (isUnderReview)
                    _buildPendingReviewCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      mutedTextColor: mutedTextColor,
                      purpleColor: purpleColor,
                      profile: profile,
                    )
                  else ...[
                    // Rejection Banner if previously rejected
                    if (isRejected)
                      _buildRejectionBanner(
                        rejectionReason: profile.rejectionReason,
                      ),

                    // ── 2. VERIFICATION FORM CARD ────────────────────────────
                    Builder(
                      builder: (context) {
                        final nin = _ninController.text.trim();
                        final plate = _plateNumberController.text.trim();
                        final hasPhotos = _ninFile != null && _vehiclePhotoFile != null;
                        final isNinIncomplete = nin.isNotEmpty && nin.length < 11;
                        final shouldShowNin11Warning =
                            (hasPhotos && isNinIncomplete) || (_ninError != null);

                        final isFormValid = nin.length == 11 &&
                            _ninFile != null &&
                            _vehiclePhotoFile != null &&
                            (!isMotorcycle || plate.isNotEmpty);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section: National Identity Number
                                  Text(
                                    'National Identification Number (NIN)',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(13.5),
                                      fontWeight: FontWeight.w700,
                                      color: shouldShowNin11Warning
                                          ? const Color(0xFFDC2626)
                                          : primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: fieldBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: shouldShowNin11Warning
                                            ? const Color(0xFFDC2626)
                                            : fieldBorder,
                                        width: shouldShowNin11Warning ? 1.2 : 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _ninController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          if (_ninError != null) _ninError = null;
                                        });
                                      },
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: AppTypography.font(14),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter your 11-digit NIN',
                                        hintStyle: TextStyle(
                                          color: mutedTextColor,
                                          fontSize: AppTypography.font(14),
                                        ),
                                        prefixIcon: Icon(
                                          LucideIcons.idCard,
                                          size: 18,
                                          color: shouldShowNin11Warning
                                              ? const Color(0xFFDC2626)
                                              : purpleColor,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (shouldShowNin11Warning) ...[
                                    const SizedBox(height: 6),
                                    _buildInlineErrorMessage(
                                      _ninError ?? 'NIN number must be 11 numbers',
                                    ),
                                  ],
                                  const SizedBox(height: 20),

                                  // Section: NIN Document Photo Upload
                                  Text(
                                    'NIN Document / Slip Photo',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(13.5),
                                      fontWeight: FontWeight.w700,
                                      color: _ninFileError != null
                                          ? const Color(0xFFDC2626)
                                          : primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildImageUploadDropzone(
                                    file: _ninFile,
                                    placeholderText: 'Tap to upload clear photo of your NIN slip or card',
                                    icon: LucideIcons.fileText,
                                    onTap: _pickNinFile,
                                    onRemove: () => setState(() => _ninFile = null),
                                    fieldBg: fieldBg,
                                    borderColor: _ninFileError != null
                                        ? const Color(0xFFDC2626)
                                        : fieldBorder,
                                    purpleColor: purpleColor,
                                    primaryTextColor: primaryTextColor,
                                    mutedTextColor: mutedTextColor,
                                  ),
                                  if (_ninFileError != null) ...[
                                    const SizedBox(height: 6),
                                    _buildInlineErrorMessage(_ninFileError!),
                                  ],
                                  const SizedBox(height: 20),

                                  // Section: Vehicle Plate Number (Conditional)
                                  if (isMotorcycle) ...[
                                    Text(
                                      'Vehicle Plate Number',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(13.5),
                                        fontWeight: FontWeight.w700,
                                        color: _plateError != null
                                            ? const Color(0xFFDC2626)
                                            : primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: fieldBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _plateError != null
                                              ? const Color(0xFFDC2626)
                                              : fieldBorder,
                                          width: _plateError != null ? 1.2 : 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _plateNumberController,
                                        textCapitalization: TextCapitalization.characters,
                                        onChanged: (val) {
                                          if (_plateError != null) {
                                            setState(() => _plateError = null);
                                          }
                                        },
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontSize: AppTypography.font(14),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. ABC-123XY',
                                          hintStyle: TextStyle(
                                            color: mutedTextColor,
                                            fontSize: AppTypography.font(14),
                                          ),
                                          prefixIcon: Icon(
                                            LucideIcons.bike,
                                            size: 18,
                                            color: _plateError != null
                                                ? const Color(0xFFDC2626)
                                                : purpleColor,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_plateError != null) ...[
                                      const SizedBox(height: 6),
                                      _buildInlineErrorMessage(_plateError!),
                                    ],
                                    const SizedBox(height: 20),
                                  ],

                                  // Section: Vehicle Photo Upload
                                  Text(
                                    'Delivery Vehicle Photo',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(13.5),
                                      fontWeight: FontWeight.w700,
                                      color: _vehiclePhotoError != null
                                          ? const Color(0xFFDC2626)
                                          : primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildImageUploadDropzone(
                                    file: _vehiclePhotoFile,
                                    placeholderText: isMotorcycle
                                        ? 'Tap to upload photo of your motorcycle with plate visible'
                                        : 'Tap to upload photo of your bicycle/delivery gear',
                                    icon: LucideIcons.camera,
                                    onTap: _pickVehiclePhoto,
                                    onRemove: () => setState(() => _vehiclePhotoFile = null),
                                    fieldBg: fieldBg,
                                    borderColor: _vehiclePhotoError != null
                                        ? const Color(0xFFDC2626)
                                        : fieldBorder,
                                    purpleColor: purpleColor,
                                    primaryTextColor: primaryTextColor,
                                    mutedTextColor: mutedTextColor,
                                  ),
                                  if (_vehiclePhotoError != null) ...[
                                    const SizedBox(height: 6),
                                    _buildInlineErrorMessage(_vehiclePhotoError!),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── 3. SUBMIT ACTION BUTTON ──────────────────────────────
                            _isLoading
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: CircularProgressIndicator(color: purpleColor),
                                    ),
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: isFormValid ? _submit : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: purpleColor,
                                        disabledBackgroundColor: isDark
                                            ? const Color(0xFF2A2B36)
                                            : const Color(0xFFE5E7EB),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: isDark
                                            ? Colors.white38
                                            : const Color(0xFF9CA3AF),
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isRejected
                                                ? LucideIcons.rotateCcw
                                                : LucideIcons.send,
                                            size: 18,
                                            color: isFormValid
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white38
                                                    : const Color(0xFF9CA3AF)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isRejected
                                                ? 'Re-Submit for Review'
                                                : 'Submit for Review',
                                            style: TextStyle(
                                              fontSize: AppTypography.font(15),
                                              fontWeight: FontWeight.w700,
                                              color: isFormValid
                                                  ? Colors.white
                                                  : (isDark
                                                      ? Colors.white38
                                                      : const Color(0xFF9CA3AF)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  Widget _buildInlineErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 13,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: const Color(0xFFDC2626),
                fontSize: AppTypography.font(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionBanner({required String rejectionReason}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.alertCircle,
              color: Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Not Approved',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.titleMedium),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rejectionReason.isNotEmpty
                      ? rejectionReason
                      : 'Your documents could not be verified. Please ensure photos are crisp and legible before re-submitting.',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFDC2626).withValues(alpha: 0.90),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedCard({
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required RiderProfile profile,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Icon Badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              size: 36,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 16),

          // Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'VERIFIED RIDER',
              style: TextStyle(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w800,
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Verification Complete',
            style: TextStyle(
              fontSize: AppTypography.font(20),
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your identity credentials and vehicle records have been verified by the MartFood administration team. You are authorized to accept and deliver customer orders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.font(13.5),
              color: mutedTextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Overview Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: purpleColor.withValues(alpha: 0.14), width: 1),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Rider Name',
                  value: profile.displayName,
                  primaryTextColor: primaryTextColor,
                  mutedTextColor: mutedTextColor,
                ),
                const Divider(height: 16, thickness: 0.5),
                _buildDetailRow(
                  label: 'Vehicle Classification',
                  value: profile.vehicleLabel,
                  primaryTextColor: primaryTextColor,
                  mutedTextColor: mutedTextColor,
                ),
                const Divider(height: 16, thickness: 0.5),
                _buildDetailRow(
                  label: 'Compliance Status',
                  value: 'Active & Verified',
                  primaryTextColor: const Color(0xFF16A34A),
                  mutedTextColor: mutedTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewCard({
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
    required RiderProfile profile,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Icon Badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.clock,
              size: 36,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 16),

          // Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'UNDER ADMIN REVIEW',
              style: TextStyle(
                color: const Color(0xFFD97706),
                fontWeight: FontWeight.w800,
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Verification In Progress',
            style: TextStyle(
              fontSize: AppTypography.font(20),
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your identity documents and vehicle information have been submitted and are currently in the review queue. Reviews typically complete within 24 to 48 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.font(13.5),
              color: mutedTextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Verification Timeline Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: purpleColor.withValues(alpha: 0.14), width: 1),
            ),
            child: Column(
              children: [
                _buildTimelineStep(
                  title: 'Documents Submitted',
                  subtitle: 'NIN and vehicle details received',
                  isCompleted: true,
                  purpleColor: purpleColor,
                  primaryTextColor: primaryTextColor,
                  mutedTextColor: mutedTextColor,
                ),
                const SizedBox(height: 14),
                _buildTimelineStep(
                  title: 'Admin Background Audit',
                  subtitle: 'Document legibility and identity check in progress',
                  isCompleted: false,
                  purpleColor: purpleColor,
                  primaryTextColor: primaryTextColor,
                  mutedTextColor: mutedTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required Color purpleColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? const Color(0xFF16A34A) : purpleColor.withValues(alpha: 0.20),
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.more_horiz,
            size: 14,
            color: isCompleted ? Colors.white : purpleColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  fontWeight: FontWeight.w500,
                  color: mutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
            color: mutedTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
            color: primaryTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadDropzone({
    required File? file,
    required String placeholderText,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required Color fieldBg,
    required Color borderColor,
    required Color purpleColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    if (file != null) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.file(
                file,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.check, color: Color(0xFF22C55E), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Ready to upload',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTypography.font(AppFontSizes.caption),
                        fontWeight: FontWeight.w600,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: purpleColor, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  placeholderText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(12.5),
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
