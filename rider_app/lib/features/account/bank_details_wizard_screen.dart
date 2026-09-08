import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../domain/bank_details.dart';
import '../../providers/rider_app_providers.dart';

/// Bank & Payout Details screen matching the Minimal & Flat design system
/// of e-wallet_screen.dart with one primary card and bottom sheet modal editors.
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
      final uri = Uri.parse('https://api.paystack.co/bank?country=nigeria&perPage=100');
      final request = await client.getUrl(uri);
      request.headers.add('Authorization',
          'Bearer ${utf8.decode(base64Decode('c2tfbGl2ZV8wM2Q2MGM4NmJiYzQ2NTA5ZmQ5NjY5MDRlNDBhZDI0OGMwMTVjNzkw'))}');

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
        onSaved: (bank) async {
          await ref.read(bankDetailsProvider.notifier).save(bank);
          if (mounted) {
            _showFeedback(
              isError: false,
              message: existingBank != null
                  ? 'Bank details updated successfully.'
                  : 'Payout bank account linked successfully.',
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteBank() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

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
                  : (isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final bank = ref.watch(bankDetailsProvider);

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
                  if (bank != null) ...[
                    // ── 1. Bank Detail Hero Card (Matching Wallet Hero Container) ──
                    _buildBankHeroCard(
                      context: context,
                      bank: bank,
                      purpleColor: purpleColor,
                    ),
                    const SizedBox(height: 18),

                    // ── 2. Card Action Row: Edit & Delete ────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openBankFormSheet(existingBank: bank),
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
                    // ── Empty State: No Bank Linked ──────────────────────────
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
                          const SizedBox(height: 24),
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
                                padding: const EdgeInsets.symmetric(vertical: 14),
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
                          text: 'Automated payouts process every Friday at 12:00 PM.',
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                          purpleColor: purpleColor,
                        ),
                        const SizedBox(height: 8),
                        _buildPolicyItem(
                          icon: LucideIcons.shieldCheck,
                          text: 'Account name must match your registered government ID.',
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                          purpleColor: purpleColor,
                        ),
                        const SizedBox(height: 8),
                        _buildPolicyItem(
                          icon: LucideIcons.creditCard,
                          text: 'Only one primary settlement bank account is supported.',
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
          // Decorative Circle Overlay 1 (Top Left)
          Positioned(
            top: -45,
            left: -45,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),

          // Decorative Circle Overlay 2 (Bottom Right)
          Positioned(
            bottom: -55,
            right: -35,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.landmark,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Primary Settlement Account',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: AppTypography.font(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  bank.bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.font(20),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bank.accountNumber,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: AppTypography.font(16),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACCOUNT HOLDER',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
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

/// Bottom Sheet modal for adding or editing payout bank account details.
class _PayoutAccountBottomSheet extends StatefulWidget {
  final BankDetails? existingBank;
  final Map<String, String> banks;
  final Function(BankDetails) onSaved;

  const _PayoutAccountBottomSheet({
    required this.existingBank,
    required this.banks,
    required this.onSaved,
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
  bool _isSaving = false;
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
          'Bearer ${utf8.decode(base64Decode('c2tfbGl2ZV8wM2Q2MGM4NmJiYzQ2NTA5ZmQ5NjY5MDRlNDBhZDI0OGMwMTVjNzkw'))}');

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

  void _submit() async {
    final nuban = _accountNumberController.text.trim();
    final name = _accountNameController.text.trim();

    if (nuban.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit NUBAN account number.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please provide the registered account holder name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final details = BankDetails(
      bankName: _selectedBankName,
      accountName: name,
      accountNumber: nuban,
      bankCode: _selectedBankCode,
    );

    await widget.onSaved(details);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _openBankSelectorModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : AppTheme.lightInputFill,
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
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6),
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
                                : (isDark ? const Color(0xFF27272A) : AppTheme.lightInputFill),
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
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(LucideIcons.check, color: purpleColor, size: 18)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedBankCode = item.key;
                            _selectedBankName = item.value;
                          });
                          Navigator.pop(ctx);
                          if (_accountNumberController.text.trim().length == 10) {
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
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final inputFill = isDark ? const Color(0xFF27272A) : AppTheme.lightInputFill;

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
                    color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.landmark, size: 18, color: purpleColor),
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
                      Icon(LucideIcons.chevronDown, size: 18, color: mutedTextColor),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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

              // ── Submit Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existingBank != null
                              ? 'Update Bank Account'
                              : 'Link Bank Account',
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
