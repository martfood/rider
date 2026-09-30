import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTabIndex = 0; // 0: Customer, 1: Vendor

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1 || (now.day - date.day == 1 && date.month == now.month)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    }
  }

  bool _isVendorChat(Map<String, dynamic> chat) {
    final chatType = (chat['chatType'] ?? '').toString().toLowerCase().trim();
    if (chatType == 'vendor') return true;
    if (chat['vendorId'] != null && chat['vendorId'].toString().trim().isNotEmpty) return true;
    if (chat['vendorName'] != null && chat['vendorName'].toString().trim().isNotEmpty) return true;
    return false;
  }

  int _getUnreadCount(Map<String, dynamic> chat, String userId) {
    int unread = 0;
    final unreadMap = chat['unreadCount'];
    if (unreadMap is Map) {
      final userVal = unreadMap[userId];
      if (userVal is num && userVal > 0) {
        unread = math.max(unread, userVal.toInt());
      } else if (userVal is String) {
        final parsed = int.tryParse(userVal) ?? 0;
        if (parsed > 0) unread = math.max(unread, parsed);
      }

      final riderId = chat['riderId']?.toString();
      if (riderId == null || riderId == userId || riderId.isEmpty) {
        final roleVal = unreadMap['rider_unread'];
        if (roleVal is num && roleVal > 0) {
          unread = math.max(unread, roleVal.toInt());
        } else if (roleVal is String) {
          final parsed = int.tryParse(roleVal) ?? 0;
          if (parsed > 0) unread = math.max(unread, parsed);
        }
      }
    } else if (unreadMap is num && unreadMap > 0) {
      final lastSenderId = chat['lastSenderId']?.toString() ?? chat['senderId']?.toString();
      if (lastSenderId != userId) {
        unread = math.max(unread, unreadMap.toInt());
      }
    }

    final topRider = chat['rider_unread'];
    if (topRider is num && topRider > 0) {
      unread = math.max(unread, topRider.toInt());
    }

    final topUid = chat['unreadCount_$userId'] ?? chat['unread_$userId'];
    if (topUid is num && topUid > 0) {
      unread = math.max(unread, topUid.toInt());
    }

    return unread;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.lock,
                size: 48,
                color: purpleColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Please sign in to view messages',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/auth/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Messages',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
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
            child: _buildActiveChatsStream(currentUser.uid, isDark, purpleColor),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChatsStream(String userId, bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : Colors.black87;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('members', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: purpleColor),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final allChats = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['chatId'] = doc.id;
          return data;
        }).toList();

        // Separate chats into Customer and Vendor
        final customerChats = allChats.where((c) => !_isVendorChat(c)).toList();
        final vendorChats = allChats.where((c) => _isVendorChat(c)).toList();

        // Calculate unread totals for badges
        int customerUnreadTotal = 0;
        for (final c in customerChats) {
          customerUnreadTotal += _getUnreadCount(c, userId);
        }

        int vendorUnreadTotal = 0;
        for (final c in vendorChats) {
          vendorUnreadTotal += _getUnreadCount(c, userId);
        }

        return Column(
          children: [
            // ── Customer / Vendor Segmented Tab Bar ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        title: 'Customer',
                        icon: LucideIcons.user,
                        isSelected: _selectedTabIndex == 0,
                        badgeCount: customerUnreadTotal,
                        isDark: isDark,
                        purpleColor: purpleColor,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTabButton(
                        title: 'Vendor',
                        icon: LucideIcons.store,
                        isSelected: _selectedTabIndex == 1,
                        badgeCount: vendorUnreadTotal,
                        isDark: isDark,
                        purpleColor: purpleColor,
                        onTap: () => setState(() => _selectedTabIndex = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Search Bar Filter (Moved Below Tabs) ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.search,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim().toLowerCase());
                        },
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                        decoration: InputDecoration(
                          hintText: _selectedTabIndex == 0
                              ? 'Search customer conversations...'
                              : 'Search vendor conversations...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Chat List View ──────────────────────────────────────────────
            Expanded(
              child: _buildChatListView(
                chats: _selectedTabIndex == 0 ? customerChats : vendorChats,
                isVendorTab: _selectedTabIndex == 1,
                userId: userId,
                isDark: isDark,
                purpleColor: purpleColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required int badgeCount,
    required bool isDark,
    required Color purpleColor,
    required VoidCallback onTap,
  }) {
    final activeTextColor = Colors.white;
    final inactiveTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? purpleColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeTextColor : inactiveTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : purpleColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.caption),
                    fontWeight: FontWeight.w800,
                    color: isSelected ? purpleColor : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatListView({
    required List<Map<String, dynamic>> chats,
    required bool isVendorTab,
    required String userId,
    required bool isDark,
    required Color purpleColor,
  }) {
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    var filteredList = List<Map<String, dynamic>>.from(chats);

    // Client-side search filtering
    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList.where((chat) {
        final customerName = (chat['customerName'] ?? '').toString().toLowerCase();
        final riderName = (chat['riderName'] ?? '').toString().toLowerCase();
        final vendorName = (chat['vendorName'] ?? '').toString().toLowerCase();
        final lastMsg = (chat['lastMessage'] ?? '').toString().toLowerCase();
        return customerName.contains(_searchQuery) ||
            riderName.contains(_searchQuery) ||
            vendorName.contains(_searchQuery) ||
            lastMsg.contains(_searchQuery);
      }).toList();
    }

    filteredList.sort((a, b) {
      final t1 = a['lastMessageTime'] as Timestamp?;
      final t2 = b['lastMessageTime'] as Timestamp?;
      if (t1 == null) return 1;
      if (t2 == null) return -1;
      return t2.compareTo(t1);
    });

    if (filteredList.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Text(
            'No ${isVendorTab ? "vendor" : "customer"} conversations match "$_searchQuery"',
            style: TextStyle(
              color: mutedTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVendorTab ? LucideIcons.store : LucideIcons.userCheck,
                  size: 48,
                  color: purpleColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isVendorTab ? 'No Vendor Messages' : 'No Customer Messages',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.titleLarge),
                  color: primaryTextColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVendorTab
                    ? 'When store vendors contact you about orders or food pickups, conversations will appear here.'
                    : 'When customers contact you about deliveries or orders, conversations will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                  color: mutedTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = filteredList[index];
        final rawOtherId = (chat['members'] as List<dynamic>?)
                ?.firstWhere((m) => m.toString() != userId, orElse: () => '')
                ?.toString() ??
            '';
        final isVendor = _isVendorChat(chat) || isVendorTab;
        final otherUserId = rawOtherId.isNotEmpty
            ? rawOtherId
            : (isVendor
                ? (chat['vendorId'] ?? userId).toString()
                : (chat['customerId'] ?? userId).toString());
        final displayName = isVendor
            ? (chat['vendorName'] ?? 'Vendor Store')
            : (chat['customerName'] ?? 'Customer');
        final photoUrl = isVendor
            ? (chat['vendorPhoto'] ?? '')
            : (chat['customerPhoto'] ?? '');
        final lastMsg = chat['lastMessage'] ?? 'No messages yet';
        final lastTime = chat['lastMessageTime'] as Timestamp?;
        final unread = _getUnreadCount(chat, userId);
        final formattedTime = _formatTimestamp(lastTime);

        return Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => context.push('/conversation', extra: {
              'chatId': chat['chatId'] ?? '',
              'id': otherUserId,
              'name': displayName,
              'photo': photoUrl,
              'isVendor': isVendor,
              'orderId': chat['orderId']?.toString(),
            }),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  // Avatar with Dynamic Profile Picture
                  _ChatAvatar(
                    initialPhotoUrl: photoUrl,
                    otherUserId: otherUserId,
                    isVendor: isVendor,
                    purpleColor: purpleColor,
                    chatId: chat['chatId']?.toString(),
                  ),
                  const SizedBox(width: 14),

                  // Name and Message Preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                                  fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                            if (isVendor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Vendor',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(AppFontSizes.caption),
                                    fontWeight: FontWeight.w700,
                                    color: purpleColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodySmall + 1),
                            color: unread > 0 ? primaryTextColor : mutedTextColor,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Time & Unread Badge Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.caption),
                          color: unread > 0 ? purpleColor : mutedTextColor,
                          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: purpleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unread',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTypography.font(AppFontSizes.caption),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        Icon(
                          LucideIcons.checkCheck,
                          size: 16,
                          color: purpleColor.withValues(alpha: 0.6),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatAvatar extends StatefulWidget {
  final String? initialPhotoUrl;
  final String otherUserId;
  final bool isVendor;
  final Color purpleColor;
  final String? chatId;

  const _ChatAvatar({
    this.initialPhotoUrl,
    required this.otherUserId,
    required this.isVendor,
    required this.purpleColor,
    this.chatId,
  });

  static final Map<String, String> _photoCache = {};

  @override
  State<_ChatAvatar> createState() => _ChatAvatarState();
}

class _ChatAvatarState extends State<_ChatAvatar> {
  String _resolvedPhoto = '';

  @override
  void initState() {
    super.initState();
    _initPhoto();
  }

  @override
  void didUpdateWidget(covariant _ChatAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhotoUrl != oldWidget.initialPhotoUrl ||
        widget.otherUserId != oldWidget.otherUserId) {
      _initPhoto();
    }
  }

  void _initPhoto() {
    final initial = widget.initialPhotoUrl?.trim() ?? '';
    if (initial.isNotEmpty && initial != 'null') {
      _resolvedPhoto = initial;
      _ChatAvatar._photoCache[widget.otherUserId] = initial;
      return;
    }

    if (widget.otherUserId.isNotEmpty &&
        _ChatAvatar._photoCache.containsKey(widget.otherUserId)) {
      _resolvedPhoto = _ChatAvatar._photoCache[widget.otherUserId]!;
      return;
    }

    _fetchLivePhoto();
  }

  Future<void> _fetchLivePhoto() async {
    if (widget.otherUserId.isEmpty) return;
    try {
      String foundUrl = '';

      if (widget.isVendor) {
        final vDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(widget.otherUserId)
            .get();
        if (vDoc.exists && vDoc.data() != null) {
          final data = vDoc.data()!;
          final biz = data['businessProfile'] as Map<String, dynamic>?;
          final pBiz = data['pendingBusinessProfile'] as Map<String, dynamic>?;
          foundUrl = (
            biz?['logoUrl'] ??
            pBiz?['logoUrl'] ??
            data['logoUrl'] ??
            data['vendorLogo'] ??
            data['photoUrl'] ??
            data['profilePic'] ??
            ''
          ).toString().trim();
        }
      } else {
        // 1. Prioritize 'customers' collection where MartFood stores customer profile pics
        final custDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.otherUserId)
            .get();
        if (custDoc.exists && custDoc.data() != null) {
          final data = custDoc.data()!;
          foundUrl = (
            data['profilePic'] ??
            data['photoUrl'] ??
            data['avatarUrl'] ??
            data['profilePicture'] ??
            data['imageUrl'] ??
            ''
          ).toString().trim();
        }

        // 2. Fallback to 'users' collection if empty
        if (foundUrl.isEmpty || foundUrl == 'null') {
          final uDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.otherUserId)
              .get();
          if (uDoc.exists && uDoc.data() != null) {
            final data = uDoc.data()!;
            final profile = data['profile'] as Map<String, dynamic>?;
            foundUrl = (
              data['profilePic'] ??
              data['photoUrl'] ??
              data['avatarUrl'] ??
              data['profilePicture'] ??
              data['imageUrl'] ??
              profile?['profilePic'] ??
              profile?['photoUrl'] ??
              ''
            ).toString().trim();
          }
        }
      }

      if (foundUrl.isNotEmpty && foundUrl != 'null' && mounted) {
        _ChatAvatar._photoCache[widget.otherUserId] = foundUrl;
        setState(() {
          _resolvedPhoto = foundUrl;
        });

        // Sync back to chat document so future reads are instantaneous
        if (widget.chatId != null && widget.chatId!.isNotEmpty) {
          FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .set({
            if (widget.isVendor) 'vendorPhoto': foundUrl else 'customerPhoto': foundUrl,
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint('Error fetching chat avatar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _resolvedPhoto.isNotEmpty && _resolvedPhoto != 'null';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.purpleColor.withValues(alpha: 0.12),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(_resolvedPhoto),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !hasPhoto
          ? Icon(
              widget.isVendor ? LucideIcons.store : LucideIcons.user,
              color: widget.purpleColor,
              size: 24,
            )
          : null,
    );
  }
}
