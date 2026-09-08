import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../providers/rider_profile_provider.dart';

/// Redesigned Rider Account screen matching the Customer Profile screen design and layout.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(riderProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final cardBorderColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final dividerColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFF5EEFF);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please log in to view account',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(15),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final fullName = profile.displayName.isNotEmpty ? profile.displayName : 'MartFood Rider';
    final profilePic = profile.avatarUrl;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                children: [
                  // ── Centered Avatar & Full Name ──────────────────────────
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFF3F3F5),
                          backgroundImage: profilePic.isNotEmpty
                              ? NetworkImage(profilePic)
                              : null,
                          child: profilePic.isEmpty
                              ? Icon(
                                  LucideIcons.user,
                                  size: 40,
                                  color: AppTheme.primaryPurpleFor(isDark),
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTypography.font(18),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                            if (profile.verificationStatus == 'verified') ...[
                              const SizedBox(width: 6),
                              const Icon(
                                LucideIcons.badgeCheck,
                                size: 18,
                                color: Color(0xFF10B981),
                              ),
                            ],
                          ],
                        ),
                        if (profile.phone.isNotEmpty || profile.email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.phone.isNotEmpty ? profile.phone : profile.email,
                            style: TextStyle(
                              fontSize: AppTypography.font(12),
                              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // ── Group 1 Card (Profile Details, Ratings, Bank Details) ──
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorderColor, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildProfileRowItem(
                          context: context,
                          icon: Icons.person,
                          title: 'Profile Details',
                          onTap: () => context.push('/account/profile'),
                          isDark: isDark,
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 60,
                          endIndent: 16,
                        ),
                        _buildProfileRowItem(
                          context: context,
                          icon: Icons.star,
                          title: 'Rating & Reviews',
                          onTap: () => context.push('/account/reviews'),
                          isDark: isDark,
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 60,
                          endIndent: 16,
                        ),
                        _buildProfileRowItem(
                          context: context,
                          icon: LucideIcons.fileBadge,
                          title: 'ID & Verification',
                          onTap: () => context.push('/account/id-documents'),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Group 2 Card (Help Center, Support, Settings, Log Out) ──
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorderColor, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildProfileRowItem(
                          context: context,
                          icon: Icons.help,
                          title: 'Help Center & FAQs',
                          onTap: () => context.push('/account/help'),
                          isDark: isDark,
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 60,
                          endIndent: 16,
                        ),
                        _buildProfileRowItem(
                          context: context,
                          icon: LucideIcons.headphones,
                          title: 'Customer Support',
                          onTap: () => context.push('/account/help/support'),
                          isDark: isDark,
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 60,
                          endIndent: 16,
                        ),
                        _buildProfileRowItem(
                          context: context,
                          icon: LucideIcons.scale,
                          title: 'Legal',
                          onTap: () => context.push('/account/legal'),
                          isDark: isDark,
                        ),
                        Divider(
                          height: 1,
                          color: dividerColor,
                          indent: 60,
                          endIndent: 16,
                        ),
                        _buildProfileRowItem(
                          context: context,
                          icon: Icons.settings,
                          title: 'Settings',
                          onTap: () => context.push('/account/settings'),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRowItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? textColor,
    Color? iconColor,
  }) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final purpleAccent = AppTheme.primaryPurpleFor(isDark);
    final pillBg = isDark
        ? const Color(0xFF27272A)
        : (iconColor != null
            ? iconColor.withValues(alpha: 0.10)
            : const Color(0xFFF6F2FC));
    final iconClr = iconColor ?? purpleAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pillBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconClr,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.font(15),
                    fontWeight: FontWeight.w600,
                    color: textColor ?? primaryTextColor,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
