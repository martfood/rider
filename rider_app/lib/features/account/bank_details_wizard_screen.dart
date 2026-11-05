import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../domain/bank_details.dart';
import '../../domain/bank_request.dart';
import '../../providers/rider_app_providers.dart';
import '../../providers/rider_profile_provider.dart';

/// Bank & Payout Details screen matching the Minimal & Flat design system
/// with active vs pending review states, administrative approval workflows,
/// and bottom sheet editors.
class BankDetailsWizardScreen extends ConsumerStatefulWidget {
  const BankDetailsWizardScreen({super.key});

  @override
  ConsumerState<BankDetailsWizardScreen> createState() =>
      _BankDetailsWizardScreenState();
}

class _BankDetailsWizardScreenState
    extends ConsumerState<BankDetailsWizardScreen> {
  Map<String, String> _banks = {
    '058': 'Guaranty Trust Bank (GTB)',
    '057': 'Zenith Bank',
    '044': 'Access Bank',
    '033': 'United Bank for Africa (UBA)',
    '011': 'First Bank of Nigeria',
    '50211': 'Kuda Microfinance Bank',
    '999992': 'OPay Digital Services',
    '999991': 'PalmPay',
    '090551': 'Moniepoint MFB',
    '232': 'Sterling Bank',
    '070': 'Fidelity Bank',
    '214': 'First City Monument Bank (FCMB)',
    '221': 'Stanbic IBTC Bank',
    '035': 'Wema Bank / ALAT',
    '076': 'Polaris Bank',
    '082': 'Keystone Bank',
    '101': 'Providus Bank',
    '304': 'Stanbic Mobile',
    '305': 'Paycom (Opay)',
  };

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    final client = HttpClient();
    try {
      final uri =
          Uri.parse('https://api.paystack.co/bank?country=nigeria&perPage=100');
      final request = await client.getUrl(uri);
      request.headers.add('Authorization',
          'Bearer ${utf8.decode(base64Decode('c2tfbGl2ZV85ZmNkM2ZkZWY5NmYzZGZmNzFlOTZhM2Y4ZGNhYTA0OTcyNThlMDNk'))}');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonResponse = json.decode(body);
        if (jsonResponse['status'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          final Map<String, String> fetched = {};
          for (final b in data) {
            final code = b['code'] as String?;
            final name = b['name'] as String?;
            if (code != null && name != null) {
              fetched[code] = name;
            }
          }
          if (fetched.isNotEmpty && mounted) {
            setState(() {
              _banks = fetched;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Paystack fetch banks error: $e');
    } finally {
      client.close();
    }
  }

  void _openBankFormSheet({BankDetails? existingBank}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => _PayoutAccountBottomSheet(
        existingBank: existingBank,
        banks: _banks,
        onProceedToConfirm: (bank) {
          _confirmAndSubmitBankRequest(
            requestedBank: bank,
            currentBank: existingBank,
          );
        },
      ),
    );
  }

  void _confirmAndSubmitBankRequest({
    required BankDetails requestedBank,
    BankDetails? currentBank,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: purpleColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(LucideIcons.shieldCheck,
                              color: purpleColor, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit for Admin Approval',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Settlement Account Verification',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(12),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Requested Details Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF27272A)
                          : AppTheme.lightInputFill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REQUESTED BANK DETAILS',
                          style: TextStyle(
                            color: purpleColor,
                            fontSize: AppTypography.font(11),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          requestedBank.bankName,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(15),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          requestedBank.accountNumber,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          requestedBank.accountName,
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: AppTypography.font(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Informational notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E152A)
                          : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3B1D54)
                            : const Color(0xFFF3E8FF),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info, size: 16, color: purpleColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your requested details will be sent to the administration team for audit. Your active account (if any) remains active until approved.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.purple[200]
                                  : const Color(0xFF581C87),
                              fontSize: AppTypography.font(12),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            side: BorderSide(color: borderColor, width: 1),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(14),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  try {
                                    final profile =
                                        ref.read(riderProfileProvider);
                                    await ref
                                        .read(bankDetailsProvider.notifier)
                                        .submitUpdateRequest(
                                          requestedBank: requestedBank,
                                          currentBank: currentBank,
                                          profile: profile,
                                        );

                                    if (sheetCtx.mounted) {
                                      Navigator.pop(sheetCtx);
                                    }
                                    if (mounted) {
                                      _showFeedback(
                                        isError: false,
                                        message:
                                            'Bank update request submitted for Admin review! Your active account remains in place.',
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => isSubmitting = false);
                                    if (mounted) {
                                      _showFeedback(
                                        isError: true,
                                        message: 'Failed to submit request: $e',
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purpleColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Submit Request',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(14),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPendingRequestModal(BankRequest pendingReq) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final reqDate =
        '${pendingReq.createdAt.day} ${_monthName(pendingReq.createdAt.month)} ${pendingReq.createdAt.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Update Under Review',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(17),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Submitted on $reqDate',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: AppTypography.font(12),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: mutedTextColor, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pending Status Pill
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF332007)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF78350F)
                        : const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.clock,
                        color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status: Pending Admin Review',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                          fontSize: AppTypography.font(12),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Proposed Bank Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : AppTheme.lightInputFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PROPOSED NEW BANK',
                          style: TextStyle(
                            color: purpleColor,
                            fontSize: AppTypography.font(11),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Under Review',
                            style: TextStyle(
                              color: const Color(0xFFD97706),
                              fontSize: AppTypography.font(10),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pendingReq.requestedBank.bankName,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingReq.requestedBank.accountNumber,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(14),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingReq.requestedBank.accountName,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Information notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E152A)
                      : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3B1D54)
                        : const Color(0xFFF3E8FF),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 16, color: purpleColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weekly payouts will continue to be safely deposited into your current active bank account until our team reviews and approves this request.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.purple[200]
                              : const Color(0xFF581C87),
                          fontSize: AppTypography.font(12),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Got It',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBank() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.trash2,
                      color: Color(0xFFE11D48),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Remove Bank Account?',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to remove your payout bank details? You will need to add a bank account to receive weekly payouts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(13),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(bankDetailsProvider.notifier).delete();
                          if (mounted) {
                            _showFeedback(
                              isError: false,
                              message: 'Bank account removed.',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
      ),
    );
  }

  void _showFeedback({required bool isError, required String message}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? const Color(0xFFE11D48)
            : (isDark ? const Color(0xFF1E152A) : const Color(0xFFF3E8FF)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE9D5FF)),
            width: 1,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
              color: isError
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFFE9D5FF)
                      : const Color(0xFF6B21A8)),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFFE9D5FF)
                          : const Color(0xFF6B21A8)),
                  fontWeight: FontWeight.w700,
                  fontSize: AppTypography.font(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (month >= 1 && month <= 12) return m[month - 1];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : Colors.white;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final bank = ref.watch(bankDetailsProvider);
    final pendingReqAsync = ref.watch(riderPendingBankRequestProvider);
    final pendingReq = pendingReqAsync.value;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Payout Account',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── CASE A: Active Pending Bank Request under Review ─────────
                  if (pendingReq != null) ...[
                    // 1. Pending Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF332007)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF78350F)
                              : const Color(0xFFFDE68A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.clock,
                              color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: Pending Admin Review',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF92400E),
                                    fontSize: AppTypography.font(13),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Submitted ${pendingReq.createdAt.day} ${_monthName(pendingReq.createdAt.month)} ${pendingReq.createdAt.year}',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFB45309),
                                    fontSize: AppTypography.font(11),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Active Account vs Proposed New Bank Dual Cards
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Account Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: AppTypography.font(10),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Active',
                                        style: TextStyle(
                                          color: const Color(0xFF059669),
                                          fontSize: AppTypography.font(9),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  bank?.bankName ?? 'No bank linked',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(13),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bank?.accountNumber ?? '—',
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(12),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bank?.accountName ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(11),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Proposed New Bank Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF3B1D54)
                                    : const Color(0xFFE9D5FF),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'PROPOSED',
                                      style: TextStyle(
                                        color: purpleColor,
                                        fontSize: AppTypography.font(10),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Review',
                                        style: TextStyle(
                                          color: const Color(0xFFD97706),
                                          fontSize: AppTypography.font(9),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  pendingReq.requestedBank.bankName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(13),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pendingReq.requestedBank.accountNumber,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(12),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pendingReq.requestedBank.accountName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: AppTypography.font(11),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Security Continuity Notice
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.shieldCheck,
                              color: purpleColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Weekly automated payouts will continue to be deposited into your Active Account until the MartFood administration team approves this update.',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(12),
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Button: View Details
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPendingRequestModal(pendingReq),
                        icon: const Icon(LucideIcons.eye, size: 16),
                        label: Text(
                          'View Pending Request Details',
                          style: TextStyle(
                            fontSize: AppTypography.font(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ] else if (bank != null) ...[
                    // ── CASE B: Active Bank Account with No Pending Requests ───
                    _buildBankHeroCard(
                      context: context,
                      bank: bank,
                      purpleColor: purpleColor,
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _openBankFormSheet(existingBank: bank),
                            icon: const Icon(LucideIcons.pencilLine, size: 16),
                            label: Text(
                              'Edit Account',
                              style: TextStyle(
                                fontSize: AppTypography.font(13),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _confirmDeleteBank,
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: Color(0xFFE11D48),
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: AppTypography.font(13),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            side: const BorderSide(
                              color: Color(0xFFFECDD3),
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ── CASE C: No Bank Account Linked ───────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: purpleColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                LucideIcons.building2,
                                color: purpleColor,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No Payout Account Added',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(17),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Link your Nigerian bank account to receive weekly automated payouts directly to your account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(13),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openBankFormSheet(),
                              icon: const Icon(LucideIcons.plus, size: 17),
                              label: Text(
                                'Add Bank Account Details',
                                style: TextStyle(
                                  fontSize: AppTypography.font(14),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purpleColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // ── Payout Information Notice Card ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              color: purpleColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payout Schedule & Policy',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(14),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildPolicyItem(
                          icon: LucideIcons.calendarCheck,
                          text:
                              'Automated payouts process every Friday at 12:00 PM.',
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                          purpleColor: purpleColor,
                        ),
                        const SizedBox(height: 8),
                        _buildPolicyItem(
                          icon: LucideIcons.shieldCheck,
                          text:
                              'Account updates are verified by admin before taking effect.',
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                          purpleColor: purpleColor,
                        ),
                        const SizedBox(height: 8),
                        _buildPolicyItem(
                          icon: LucideIcons.creditCard,
                          text:
                              'Only one primary settlement bank account is supported.',
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                          purpleColor: purpleColor,
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

  Widget _buildBankHeroCard({
    required BuildContext context,
    required BankDetails bank,
    required Color purpleColor,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: purpleColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: null,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -45,
            left: -45,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -55,
            right: -35,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.shieldCheck,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Active Settlement Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTypography.font(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.landmark,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  bank.bankName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.font(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bank.accountNumber,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.font(20),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACCOUNT HOLDER',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: AppTypography.font(10),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bank.accountName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTypography.font(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.building2,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyItem({
    required IconData icon,
    required String text,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: purpleColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: AppTypography.font(12),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom Sheet modal for entering payout bank account details with Paystack resolution.
class _PayoutAccountBottomSheet extends StatefulWidget {
  final BankDetails? existingBank;
  final Map<String, String> banks;
  final Function(BankDetails) onProceedToConfirm;

  const _PayoutAccountBottomSheet({
    required this.existingBank,
    required this.banks,
    required this.onProceedToConfirm,
  });

  @override
  State<_PayoutAccountBottomSheet> createState() =>
      _PayoutAccountBottomSheetState();
}

class _PayoutAccountBottomSheetState extends State<_PayoutAccountBottomSheet> {
  late String _selectedBankCode;
  late String _selectedBankName;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  bool _isResolving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBankCode = widget.existingBank?.bankCode ??
        (widget.banks.isNotEmpty ? widget.banks.keys.first : '058');
    _selectedBankName = widget.existingBank?.bankName ??
        (widget.banks[_selectedBankCode] ?? 'Guaranty Trust Bank');
    _accountNumberController =
        TextEditingController(text: widget.existingBank?.accountNumber ?? '');
    _accountNameController =
        TextEditingController(text: widget.existingBank?.accountName ?? '');
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _resolveAccountName() async {
    final nuban = _accountNumberController.text.trim();
    if (nuban.length != 10) return;

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    final client = HttpClient();
    String? resolved;

    try {
      final uri = Uri.parse(
          'https://api.paystack.co/bank/resolve?account_number=$nuban&bank_code=$_selectedBankCode');
      final request = await client.getUrl(uri);
      request.headers.add('Authorization',
          'Bearer ${utf8.decode(base64Decode('c2tfbGl2ZV85ZmNkM2ZkZWY5NmYzZGZmNzFlOTZhM2Y4ZGNhYTA0OTcyNThlMDNk'))}');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonResponse = json.decode(body);
        if (jsonResponse['status'] == true) {
          resolved = jsonResponse['data']['account_name'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Paystack resolve error: $e');
    } finally {
      client.close();
    }

    if (!mounted) return;

    setState(() {
      _isResolving = false;
      if (resolved != null && resolved.isNotEmpty) {
        _accountNameController.text = resolved;
        _errorMessage = null;
      } else {
        _errorMessage =
            'Could not auto-verify account name. Please confirm details or enter name manually.';
      }
    });
  }

  void _submit() {
    final nuban = _accountNumberController.text.trim();
    final name = _accountNameController.text.trim();

    if (nuban.length != 10) {
      setState(() => _errorMessage =
          'Please enter a valid 10-digit NUBAN account number.');
      return;
    }
    if (name.isEmpty) {
      setState(() =>
          _errorMessage = 'Please provide the registered account holder name.');
      return;
    }

    final details = BankDetails(
      bankName: _selectedBankName,
      accountName: name,
      accountNumber: nuban,
      bankCode: _selectedBankCode,
    );

    Navigator.pop(context);
    widget.onProceedToConfirm(details);
  }

  void _openBankSelectorModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    String searchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredEntries = widget.banks.entries.where((e) {
            return e.value.toLowerCase().contains(searchFilter.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.70,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Bank',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(17),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                // Search Input
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF27272A)
                        : AppTheme.lightInputFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.search, size: 16, color: mutedTextColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) {
                            setModalState(() => searchFilter = val);
                          },
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(13),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search bank name...',
                            hintStyle: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(13),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredEntries.length,
                    separatorBuilder: (c, i) => Divider(
                      color: isDark
                          ? AppTheme.darkBorder
                          : const Color(0xFFEFF1F6),
                      height: 1,
                    ),
                    itemBuilder: (c, i) {
                      final item = filteredEntries[i];
                      final isSelected = item.key == _selectedBankCode;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? purpleColor.withValues(alpha: 0.15)
                                : (isDark
                                    ? const Color(0xFF27272A)
                                    : AppTheme.lightInputFill),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.landmark,
                              size: 16,
                              color: isSelected ? purpleColor : mutedTextColor,
                            ),
                          ),
                        ),
                        title: Text(
                          item.value,
                          style: TextStyle(
                            color: isSelected ? purpleColor : primaryTextColor,
                            fontSize: AppTypography.font(13),
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(LucideIcons.check,
                                color: purpleColor, size: 18)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedBankCode = item.key;
                            _selectedBankName = item.value;
                          });
                          Navigator.pop(ctx);
                          if (_accountNumberController.text.trim().length ==
                              10) {
                            _resolveAccountName();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final inputFill =
        isDark ? const Color(0xFF27272A) : AppTheme.lightInputFill;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Drag Handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title & Subtitle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingBank != null
                          ? 'Edit Payout Account'
                          : 'Add Payout Account',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: mutedTextColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  'Enter your 10-digit NUBAN and bank details for automated weekly payouts.',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: AppTypography.font(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Inline Error Message Banner ──────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.alertCircle,
                          color: Color(0xFFE11D48),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: const Color(0xFFE11D48),
                              fontSize: AppTypography.font(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── 1. Bank Selector Field ────────────────────────────────────
                Text(
                  'Bank Name',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _openBankSelectorModal,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.landmark,
                            size: 18, color: purpleColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedBankName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.chevronDown,
                            size: 18, color: mutedTextColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── 2. Account Number Field ───────────────────────────────────
                Text(
                  'NUBAN Account Number',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.hash, size: 18, color: purpleColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (val) {
                            if (val.length == 10) {
                              _resolveAccountName();
                            }
                          },
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: '10-digit NUBAN',
                            hintStyle: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(13),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_isResolving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 3. Account Name Field ─────────────────────────────────────
                Text(
                  'Account Holder Name',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: AppTypography.font(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.user, size: 18, color: purpleColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _accountNameController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. JOHN ADENIYI',
                            hintStyle: TextStyle(
                              color: mutedTextColor,
                              fontSize: AppTypography.font(13),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Submit / Continue Button ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      widget.existingBank != null
                          ? 'Review & Submit Update'
                          : 'Review & Link Account',
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        fontWeight: FontWeight.w800,
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
    );
  }
}
