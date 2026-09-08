import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help Center for Riders with searchable FAQs, direct Support Chat navigation, and Contact channels.
class HelpCenterRiderScreen extends StatefulWidget {
  const HelpCenterRiderScreen({super.key});

  @override
  State<HelpCenterRiderScreen> createState() => _HelpCenterRiderScreenState();
}

class _HelpCenterRiderScreenState extends State<HelpCenterRiderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = const [
    // Payouts & Earnings
    {
      'category': 'Payouts & Earnings',
      'q': 'How do payouts and delivery earnings work?',
      'a':
          'Earnings accrue on every completed delivery in real time and are credited to your MartFood Rider Wallet. Automated weekly payouts are disbursed every Friday to your verified bank account.',
    },
    {
      'category': 'Payouts & Earnings',
      'q': 'What happens if an order is cancelled by the customer or vendor?',
      'a':
          'If an order is cancelled after you have accepted it and started traveling to the pickup location, a standard dispatch cancellation fee will be automatically credited to your wallet balance.',
    },
    {
      'category': 'Payouts & Earnings',
      'q': 'How do I add or update my bank account details?',
      'a':
          'Navigate to the Earnings tab, tap "Bank Details" or the settings icon, select your bank from the list, and enter your 10-digit NUBAN account number for instant automated name verification.',
    },
    // Orders & Dispatch
    {
      'category': 'Orders & Dispatch',
      'q': 'What does Online vs Offline status mean?',
      'a':
          'When your status is set to "Online", our automated dispatch system matches you with nearby vendor pickup requests within your service radius. Switching to "Offline" pauses incoming delivery broadcasts.',
    },
    {
      'category': 'Orders & Dispatch',
      'q': 'What if the customer PIN code fails or does not match?',
      'a':
          'Ask the customer to check the 4-digit Delivery PIN displayed on their active order tracking screen in their MartFood customer app. If issues persist, reach out immediately via Support Chat with the Order ID.',
    },
    {
      'category': 'Orders & Dispatch',
      'q':
          'What should I do if a restaurant is closed or items are unavailable?',
      'a':
          'Do not force-cancel the assignment on your own. Immediately use the "Contact Support" option to alert our dispatch agents so we can verify with the vendor and reassign or cancel cleanly.',
    },
    // Account & Verification
    {
      'category': 'Account & Verification',
      'q': 'How do I complete ID & Document Verification?',
      'a':
          'Go to Account > ID & Verification. Upload high-resolution photos of your government-issued ID (NIN/Voter Card/Passport) and your driver’s license. Reviews are typically approved within 24 to 48 hours.',
    },
    {
      'category': 'Account & Verification',
      'q': 'How can I change my registered vehicle type?',
      'a':
          'Changing your vehicle classification (e.g. from bicycle to motorbike or car) requires updated vehicle documentation. Please tap "Rider Support" in the Contact Us tab to submit your new vehicle credentials.',
    },
    {
      'category': 'Account & Verification',
      'q': 'How is my live GPS location tracked?',
      'a':
          'Your location is securely broadcast in real time only when you are Online or on an active delivery assignment. This ensures accurate distance calculation, fair dispatch matching, and real-time customer tracking.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

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
          'Help Center',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: purpleColor),
            insets: const EdgeInsets.symmetric(horizontal: 28),
          ),
          labelColor: purpleColor,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          labelStyle: TextStyle(
            fontSize: AppTypography.font(14),
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Contact Us'),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFAQTab(isDark, purpleColor),
                _buildContactUsTab(isDark, purpleColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQTab(bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('faqs')
          .snapshots(),
      builder: (context, snapshot) {
        List<Map<String, String>> effectiveFaqs = _faqs;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final dynamic rawList = data?['riderFaqs'];
          if (rawList is List && rawList.isNotEmpty) {
            effectiveFaqs = rawList
                .map((item) {
                  final map = item as Map<String, dynamic>;
                  return {
                    'category': (map['category'] ?? 'General').toString(),
                    'q': (map['q'] ?? '').toString(),
                    'a': (map['a'] ?? '').toString(),
                  };
                })
                .where((f) => f['q']!.isNotEmpty && f['a']!.isNotEmpty)
                .toList();
          }
        }

        final String query = _searchQuery.trim().toLowerCase();
        final filteredFaqs = effectiveFaqs.where((faq) {
          return query.isEmpty ||
              faq['q']!.toLowerCase().contains(query) ||
              faq['a']!.toLowerCase().contains(query) ||
              (faq['category'] ?? '').toLowerCase().contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(14),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search FAQ (e.g. payouts, PIN, verification)',
                hintStyle: TextStyle(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                  fontSize: AppTypography.font(13),
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: purpleColor, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (filteredFaqs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: purpleColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        LucideIcons.search,
                        color: purpleColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No FAQs found',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: AppTypography.font(16),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try another search term or reach out to Rider Support directly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: AppTypography.font(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filteredFaqs.map((faq) =>
                  _buildFAQItem(faq['q']!, faq['a']!, isDark, purpleColor)),
          ],
        );
      },
    );
  }

  Widget _buildFAQItem(
      String question, String answer, bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            iconColor: purpleColor,
            collapsedIconColor: Colors.grey[500],
            title: Text(
              question,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppTypography.font(15),
                color: primaryTextColor,
              ),
            ),
            children: [
              Text(
                answer,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(13),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactUsTab(bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('contact_us')
          .snapshots(),
      builder: (context, snapshot) {
        String whatsappTitle = 'WhatsApp';
        String whatsappLink = 'https://wa.me/2348000000000';
        String websiteTitle = 'Website';
        String websiteLink = 'https://www.martfooddelivery.com';
        String facebookTitle = 'Facebook';
        String facebookLink = 'https://facebook.com/martfooddelivery';
        String twitterTitle = 'Twitter';
        String twitterLink = 'https://twitter.com/martfood';
        String instagramTitle = 'Instagram';
        String instagramLink = 'https://instagram.com/martfood';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            final wa = data['whatsapp'] as Map<String, dynamic>?;
            if (wa != null) {
              whatsappTitle = (wa['title'] ?? whatsappTitle).toString();
              whatsappLink = (wa['link'] ?? whatsappLink).toString();
            }
            final web = data['website'] as Map<String, dynamic>?;
            if (web != null) {
              websiteTitle = (web['title'] ?? websiteTitle).toString();
              websiteLink = (web['link'] ?? websiteLink).toString();
            }
            final fb = data['facebook'] as Map<String, dynamic>?;
            if (fb != null) {
              facebookTitle = (fb['title'] ?? facebookTitle).toString();
              facebookLink = (fb['link'] ?? facebookLink).toString();
            }
            final tw = data['twitter'] as Map<String, dynamic>?;
            if (tw != null) {
              twitterTitle = (tw['title'] ?? twitterTitle).toString();
              twitterLink = (tw['link'] ?? twitterLink).toString();
            }
            final ig = data['instagram'] as Map<String, dynamic>?;
            if (ig != null) {
              instagramTitle = (ig['title'] ?? instagramTitle).toString();
              instagramLink = (ig['link'] ?? instagramLink).toString();
            }
          }
        }

        final List<Map<String, dynamic>> items = [
          {
            'title': whatsappTitle,
            'icon': LucideIcons.messageCircle,
            'isLink': true,
            'link': whatsappLink,
          },
          {
            'title': websiteTitle,
            'icon': LucideIcons.globe,
            'isLink': true,
            'link': websiteLink,
          },
          {
            'title': facebookTitle,
            'icon': Icons.facebook,
            'isLink': true,
            'link': facebookLink,
          },
          {
            'title': twitterTitle,
            'icon': Icons.flutter_dash,
            'isLink': true,
            'link': twitterLink,
          },
          {
            'title': instagramTitle,
            'icon': Icons.camera_alt_outlined,
            'isLink': true,
            'link': instagramLink,
          },
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            ...List.generate(items.length, (index) {
              final item = items[index];
              final bool isLink = item['isLink'] as bool;

              if (!isLink) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: item['onTap'] as VoidCallback,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: purpleColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppTypography.font(15),
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Icon(LucideIcons.chevronRight,
                                  color: purpleColor, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final String linkUrl = item['link'] as String;

              return Padding(
                padding:
                    EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        iconColor: purpleColor,
                        collapsedIconColor:
                            isDark ? Colors.grey[500] : Colors.grey[400],
                        title: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: purpleColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: purpleColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: AppTypography.font(15),
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse(linkUrl);
                              try {
                                if (!await launchUrl(url,
                                    mode: LaunchMode.externalApplication)) {
                                  debugPrint('Could not launch $url');
                                }
                              } catch (e) {
                                debugPrint('Error launching url: $e');
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFF7F8FC),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: borderColor, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: purpleColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      linkUrl,
                                      style: TextStyle(
                                        color: purpleColor,
                                        fontSize: AppTypography.font(13),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
