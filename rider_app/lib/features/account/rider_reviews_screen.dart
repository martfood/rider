import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class RiderReview {
  final String customerName;
  final String customerAvatarUrl;
  final double rating;
  final String comment;
  final String date;
  final String orderSummary;

  const RiderReview({
    required this.customerName,
    required this.customerAvatarUrl,
    required this.rating,
    required this.comment,
    required this.date,
    required this.orderSummary,
  });
}

String _formatDate(dynamic dateField) {
  if (dateField == null) return 'Just now';
  if (dateField is Timestamp) {
    final date = dateField.toDate();
    final months = [
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
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  return dateField.toString();
}

class RiderReviewsScreen extends ConsumerWidget {
  const RiderReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Ratings & Reviews',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: uid == null
          ? Center(
              child: Text(
                'Please log in to view reviews.',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Responsive.maxContainer(
                  context: context,
                  maxWidth: 600,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('riders')
                        .doc(uid)
                        .collection('reviews')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: purpleColor),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      double totalRating = 0;
                      final list = <RiderReview>[];

                      for (final doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rating = (data['rating'] ?? 5.0).toDouble();
                        totalRating += rating;
                        list.add(RiderReview(
                          customerName: (data['customerName'] ?? 'Customer').toString(),
                          customerAvatarUrl: (data['customerAvatarUrl'] ?? data['customerPhoto'] ?? '').toString(),
                          rating: rating,
                          comment: (data['comment'] ?? '').toString(),
                          date: _formatDate(data['createdAt']),
                          orderSummary: (data['orderSummary'] ?? data['orderId'] ?? 'Delivery Service').toString(),
                        ));
                      }

                      final averageRating =
                          docs.isEmpty ? 5.0 : totalRating / docs.length;

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                              child: _RatingSummaryHeader(
                                isDark: isDark,
                                purpleColor: purpleColor,
                                averageRating: averageRating,
                                totalReviews: list.length,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            sliver: docs.isEmpty
                                ? SliverToBoxAdapter(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(40),
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 58,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                color: purpleColor
                                                    .withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  LucideIcons.star,
                                                  color: purpleColor,
                                                  size: 26,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              'No reviews yet',
                                              style: TextStyle(
                                                fontSize: AppTypography.font(16),
                                                fontWeight: FontWeight.w700,
                                                color: primaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Customer ratings and feedback will appear here after completed deliveries.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: AppTypography.font(13),
                                                color: mutedTextColor,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _ReviewItem(
                                        review: list[index],
                                        isDark: isDark,
                                        purpleColor: purpleColor,
                                      ),
                                      childCount: list.length,
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _RatingSummaryHeader extends StatelessWidget {
  final bool isDark;
  final Color purpleColor;
  final double averageRating;
  final int totalReviews;

  const _RatingSummaryHeader({
    required this.isDark,
    required this.purpleColor,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final int filledStars = averageRating.floor();
    final bool hasHalf = (averageRating - filledStars) >= 0.25;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: AppTypography.font(36),
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  if (index < filledStars) {
                    return const Icon(
                      Icons.star,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    );
                  } else if (index == filledStars && hasHalf) {
                    return const Icon(
                      Icons.star_half,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    );
                  } else {
                    return Icon(
                      Icons.star_outline,
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      size: 16,
                    );
                  }
                }),
              ),
              const SizedBox(height: 6),
              Text(
                'Overall Rating',
                style: TextStyle(
                  fontSize: AppTypography.font(12),
                  color: mutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 56,
            color: borderColor,
          ),
          Column(
            children: [
              Text(
                totalReviews.toString(),
                style: TextStyle(
                  fontSize: AppTypography.font(36),
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    LucideIcons.messageSquare,
                    color: purpleColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Total Reviews',
                    style: TextStyle(
                      fontSize: AppTypography.font(12),
                      color: mutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final RiderReview review;
  final bool isDark;
  final Color purpleColor;

  const _ReviewItem({
    required this.review,
    required this.isDark,
    required this.purpleColor,
  });

  Widget _buildFallbackAvatar() {
    return Container(
      color: purpleColor.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          review.customerName.isNotEmpty
              ? review.customerName[0].toUpperCase()
              : 'C',
          style: TextStyle(
            fontSize: AppTypography.font(15),
            fontWeight: FontWeight.bold,
            color: purpleColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: ClipOval(
                  child: review.customerAvatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: review.customerAvatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildFallbackAvatar(),
                          errorWidget: (context, url, error) =>
                              _buildFallbackAvatar(),
                        )
                      : _buildFallbackAvatar(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      style: TextStyle(
                        fontSize: AppTypography.font(14),
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.date,
                      style: TextStyle(
                        fontSize: AppTypography.font(11),
                        color: mutedTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: AppTypography.font(12),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: AppTypography.font(13),
                color: isDark ? Colors.grey[300] : const Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF27272A)
                  : const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.package,
                  color: purpleColor,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Order: ${review.orderSummary}',
                    style: TextStyle(
                      fontSize: AppTypography.font(11),
                      color: mutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
