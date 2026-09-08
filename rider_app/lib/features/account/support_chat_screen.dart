import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../providers/rider_profile_provider.dart';

/// Rider Support & Live Chat Hub matching the Customer Support screen design.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  void _createNewTicketSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1E2D);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final inputFill = isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF);

    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    bool isCreating = false;
    String? errorText;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
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
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: purpleColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.headset,
                            color: purpleColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start a Conversation',
                              style: TextStyle(
                                fontSize: AppTypography.font(18),
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              'Enter your topic and details below to chat with an agent.',
                              style: TextStyle(
                                fontSize: AppTypography.font(12),
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (errorText != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF450A0A)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFECACA),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.circleAlert,
                            size: 16,
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: TextStyle(
                                fontSize: AppTypography.font(12),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Topic / Title Input
                  Text(
                    'Topic / Title',
                    style: TextStyle(
                      fontSize: AppTypography.font(13),
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: TextField(
                      controller: subjectController,
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        color: primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Order issue, Payout inquiry, Account update',
                        hintStyle: TextStyle(
                          fontSize: AppTypography.font(13),
                          color: mutedTextColor,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Initial Message Input
                  Text(
                    'Initial Message (Optional)',
                    style: TextStyle(
                      fontSize: AppTypography.font(13),
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: TextField(
                      controller: messageController,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Describe how our team can help you...',
                        hintStyle: TextStyle(
                          fontSize: AppTypography.font(13),
                          color: mutedTextColor,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => ctx.pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF1E1E2D)
                                : const Color(0xFFF3F4F7),
                            foregroundColor: primaryTextColor,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: AppTypography.font(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isCreating
                              ? null
                              : () async {
                                  final subject = subjectController.text.trim();
                                  final initialMessage =
                                      messageController.text.trim();

                                  if (subject.isEmpty) {
                                    setSheetState(() => errorText =
                                        'Please enter a ticket subject.');
                                    return;
                                  }

                                  setSheetState(() {
                                    isCreating = true;
                                    errorText = null;
                                  });

                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    setSheetState(() {
                                      isCreating = false;
                                      errorText =
                                          'Please log in to start a conversation.';
                                    });
                                    return;
                                  }

                                  final profile =
                                      ref.read(riderProfileProvider);
                                  final nowStr =
                                      DateTime.now().toIso8601String();

                                  try {
                                    final docRef = FirebaseFirestore.instance
                                        .collection('support_chats')
                                        .doc();
                                    final initialMessages = [];
                                    if (initialMessage.isNotEmpty) {
                                      initialMessages.add({
                                        'senderId': user.uid,
                                        'senderName':
                                            profile.displayName.isNotEmpty
                                                ? profile.displayName
                                                : 'Rider',
                                        'text': initialMessage,
                                        'createdAt': nowStr,
                                      });
                                    }

                                    await docRef.set({
                                      'id': docRef.id,
                                      'riderId': user.uid,
                                      'riderName':
                                          profile.displayName.isNotEmpty
                                              ? profile.displayName
                                              : 'Rider',
                                      'subject': subject,
                                      'status': 'active',
                                      'createdAt': nowStr,
                                      'lastMessage': initialMessage.isNotEmpty
                                          ? initialMessage
                                          : 'Ticket created: $subject',
                                      'lastMessageAt': nowStr,
                                      'messages': initialMessages,
                                    });

                                    if (ctx.mounted) {
                                      ctx.pop();
                                    }

                                    if (context.mounted) {
                                      context.push(
                                          '/account/help/support/conversation',
                                          extra: {
                                            'id': docRef.id,
                                            'status': 'active',
                                          });
                                    }
                                  } catch (err) {
                                    setSheetState(() {
                                      isCreating = false;
                                      errorText =
                                          'Failed to create ticket: $err';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purpleColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(14),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarStack(bool isDark) {
    final avatarColors = const [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF10B981),
    ];
    return SizedBox(
      width: 72,
      height: 28,
      child: Stack(
        children: List.generate(4, (index) {
          return Positioned(
            left: index * 14.0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColors[index % avatarColors.length],
                border: Border.all(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person,
                size: 14,
                color: Colors.white,
              ),
            ),
          );
        }),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inDays == 0) {
        final hour =
            dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minStr = dt.minute.toString().padLeft(2, '0');
        return '$hour:$minStr $ampm';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final topPadding = MediaQuery.of(context).padding.top;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Top Purple Banner & Floating Card ───────────────────────────
            SizedBox(
              height: topPadding + 390,
              child: Stack(
                children: [
                  // Top Purple Hero Banner
                  Container(
                    width: double.infinity,
                    height: topPadding + 200,
                    padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 0),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkPrimaryPurple : AppTheme.primaryColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circular Back Button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 20),
                            onPressed: () => context.pop(),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'How can we help you today?\nAsk a question or start a conversation.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTypography.font(15),
                            fontWeight: FontWeight.w700,
                            height: 1.40,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating White/Dark Card
                  Positioned(
                    left: 20,
                    right: 20,
                    top: topPadding + 135,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Responsive.maxContainer(
                        context: context,
                        maxWidth: 600,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start a Conversation',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: AppTypography.font(18),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildAvatarStack(isDark),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Get a reply in minutes',
                                    style: TextStyle(
                                      color: mutedTextColor,
                                      fontSize: AppTypography.font(13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _createNewTicketSheet(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppTheme.darkPrimaryPurple : AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Start Conversation',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(15),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Divider(height: 1, color: borderColor),
                              const SizedBox(height: 10),

                              // Help/FAQs navigation row
                              InkWell(
                                onTap: () => context.push('/account/help'),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: purpleColor.withValues(
                                              alpha: 0.10),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            LucideIcons.messageSquareQuote,
                                            color: purpleColor,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Help/FAQs',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(14),
                                            fontWeight: FontWeight.w700,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                      Icon(LucideIcons.chevronRight,
                                          color: mutedTextColor, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Recent / Ongoing Conversations List ─────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: Responsive.maxContainer(
                context: context,
                maxWidth: 600,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Conversations',
                        style: TextStyle(
                          fontSize: AppTypography.font(16),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (user == null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Please log in to view conversations.',
                              style: TextStyle(
                                  color: mutedTextColor,
                                  fontSize: AppTypography.font(13)),
                            ),
                          ),
                        )
                      else
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('support_chats')
                              .where('riderId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return Center(
                                  child: CircularProgressIndicator(
                                      color: purpleColor));
                            }

                            final docs = List<QueryDocumentSnapshot>.from(
                                snapshot.data?.docs ?? []);
                            docs.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>?;
                              final bData = b.data() as Map<String, dynamic>?;
                              final aTime = (aData?['lastMessageAt'] ??
                                      aData?['createdAt'] ??
                                      '')
                                  .toString();
                              final bTime = (bData?['lastMessageAt'] ??
                                      bData?['createdAt'] ??
                                      '')
                                  .toString();
                              return bTime.compareTo(aTime);
                            });

                            if (docs.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: borderColor, width: 1),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color:
                                            purpleColor.withValues(alpha: 0.10),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(LucideIcons.messageSquare,
                                            color: purpleColor, size: 22),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No Active Conversations',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(15),
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start a conversation above whenever you need help.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: AppTypography.font(12),
                                        color: mutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final subject =
                                    (data['subject'] ?? 'Support Request')
                                        .toString();
                                final lastMsg =
                                    (data['lastMessage'] ?? 'No messages yet')
                                        .toString();
                                final lastMsgAt = (data['lastMessageAt'] ??
                                        data['createdAt'] ??
                                        '')
                                    .toString();
                                final status =
                                    (data['status'] ?? 'active').toString();
                                final isResolved = status == 'closed';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: borderColor, width: 1),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          context.push(
                                              '/account/help/support/conversation',
                                              extra: {
                                                'id': doc.id,
                                                'status': status,
                                              });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isResolved
                                                      ? (isDark
                                                          ? const Color(
                                                              0xFF064E3B)
                                                          : const Color(
                                                              0xFFE8F5E9))
                                                      : purpleColor.withValues(
                                                          alpha: 0.10),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    isResolved
                                                        ? LucideIcons
                                                            .circleCheck
                                                        : LucideIcons.headset,
                                                    color: isResolved
                                                        ? (isDark
                                                            ? const Color(
                                                                0xFF6EE7B7)
                                                            : const Color(
                                                                0xFF2E7D32))
                                                        : purpleColor,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            subject,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize:
                                                                  AppTypography
                                                                      .font(14),
                                                              color:
                                                                  primaryTextColor,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          _formatTime(
                                                              lastMsgAt),
                                                          style: TextStyle(
                                                            fontSize:
                                                                AppTypography
                                                                    .font(11),
                                                            color:
                                                                mutedTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      lastMsg,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize:
                                                            AppTypography.font(
                                                                12),
                                                        color: mutedTextColor,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isResolved
                                                            ? (isDark
                                                                ? const Color(
                                                                    0xFF064E3B)
                                                                : const Color(
                                                                    0xFFE8F5E9))
                                                            : (isDark
                                                                ? const Color(
                                                                    0xFF451A03)
                                                                : const Color(
                                                                    0xFFFFF7ED)),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        isResolved
                                                            ? 'Resolved'
                                                            : 'Active',
                                                        style: TextStyle(
                                                          fontSize:
                                                              AppTypography
                                                                  .font(10),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isResolved
                                                              ? (isDark
                                                                  ? const Color(
                                                                      0xFF6EE7B7)
                                                                  : const Color(
                                                                      0xFF2E7D32))
                                                              : (isDark
                                                                  ? const Color(
                                                                      0xFFFDBA74)
                                                                  : const Color(
                                                                      0xFFEA580C)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(LucideIcons.chevronRight,
                                                  color: mutedTextColor,
                                                  size: 16),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
