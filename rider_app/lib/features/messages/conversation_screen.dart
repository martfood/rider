import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../../core/services/notification_service.dart';

class ConversationScreen extends StatefulWidget {
  final String otherUserId;
  final String? otherUserName;
  final String? otherUserPhoto;
  final bool isVendor;
  final String? orderId;

  const ConversationScreen({
    super.key,
    required this.otherUserId,
    this.otherUserName,
    this.otherUserPhoto,
    this.isVendor = false,
    this.orderId,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String _displayName = 'Chat';
  String _displayPhoto = '';
  String _riderName = 'Rider';
  String _riderPhoto = '';
  late bool _isVendor;

  @override
  void initState() {
    super.initState();
    _isVendor = widget.isVendor;
    NotificationService.activeChatUserId = widget.otherUserId;
    if (widget.otherUserName != null && widget.otherUserName!.trim().isNotEmpty) {
      _displayName = widget.otherUserName!.trim();
    }
    if (widget.otherUserPhoto != null && widget.otherUserPhoto!.trim().isNotEmpty) {
      _displayPhoto = widget.otherUserPhoto!.trim();
    }
    _loadMetadata();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    if (NotificationService.activeChatUserId == widget.otherUserId) {
      NotificationService.activeChatUserId = null;
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || widget.otherUserId.isEmpty) return;

    try {
      // Load current rider's profile details
      final rDoc = await _firestore.collection('riders').doc(currentUser.uid).get();
      if (rDoc.exists && rDoc.data() != null) {
        final rData = rDoc.data()!;
        _riderName = (rData['fullName'] ?? rData['name'] ?? 'Rider').toString();
        _riderPhoto = (rData['photoUrl'] ?? rData['profilePic'] ?? rData['avatarUrl'] ?? '').toString();
      }

      // Check existing chat document to inspect chatType or vendorId
      final chatId = _getChatId(currentUser.uid, widget.otherUserId);
      final chatSnap = await _firestore.collection('chats').doc(chatId).get();
      if (chatSnap.exists && chatSnap.data() != null) {
        final cData = chatSnap.data()!;
        if (cData['chatType'] == 'vendor' || cData['vendorId'] != null) {
          _isVendor = true;
        }
      }

      if (_isVendor) {
        final vDoc = await _firestore.collection('vendors').doc(widget.otherUserId).get();
        if (vDoc.exists && vDoc.data() != null) {
          final vData = vDoc.data()!;
          final biz = vData['businessProfile'] as Map<String, dynamic>?;
          final resolvedName = (
            biz?['businessName'] ??
            vData['restaurantName'] ??
            vData['businessName'] ??
            vData['fullName'] ??
            vData['name'] ??
            _displayName
          ).toString();
          final resolvedPhoto = (
            biz?['logoUrl'] ??
            vData['logoUrl'] ??
            vData['photoUrl'] ??
            _displayPhoto
          ).toString();

          if (mounted) {
            setState(() {
              if (resolvedName.isNotEmpty && resolvedName != 'null') {
                _displayName = resolvedName;
              }
              if (resolvedPhoto.isNotEmpty && resolvedPhoto != 'null') {
                _displayPhoto = resolvedPhoto;
              }
            });
          }
          return;
        }
      }

      var userDoc = await _firestore.collection('users').doc(widget.otherUserId).get();
      Map<String, dynamic>? data = userDoc.data();

      if (data == null || !userDoc.exists) {
        final custDoc = await _firestore.collection('customers').doc(widget.otherUserId).get();
        if (custDoc.exists) {
          data = custDoc.data();
        } else {
          final vendorDoc = await _firestore.collection('vendors').doc(widget.otherUserId).get();
          if (vendorDoc.exists) {
            data = vendorDoc.data();
            _isVendor = true;
          }
        }
      }

      if (data != null && mounted) {
        final profile = data['profile'] as Map<String, dynamic>?;
        final biz = data['businessProfile'] as Map<String, dynamic>?;

        final resolvedName = (
          biz?['businessName'] ??
          data['restaurantName'] ??
          data['fullName'] ??
          data['name'] ??
          data['businessName'] ??
          profile?['fullName'] ??
          profile?['name'] ??
          (data['firstName'] != null ? '${data['firstName']} ${data['lastName'] ?? ''}'.trim() : null) ??
          _displayName
        ).toString();

        final resolvedPhoto = (
          biz?['logoUrl'] ??
          data['photoUrl'] ??
          data['profilePicture'] ??
          data['photoURL'] ??
          data['avatarUrl'] ??
          data['profileImage'] ??
          data['imageUrl'] ??
          profile?['photoUrl'] ??
          profile?['profilePicture'] ??
          _displayPhoto
        ).toString();

        setState(() {
          if (resolvedName.isNotEmpty && resolvedName != 'null') {
            _displayName = resolvedName;
          }
          if (resolvedPhoto.isNotEmpty && resolvedPhoto != 'null') {
            _displayPhoto = resolvedPhoto;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _getChatId(currentUser.uid, widget.otherUserId);
    try {
      await _firestore.collection('chats').doc(chatId).set({
        'unreadCount': {
          currentUser.uid: 0,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  String _getChatId(String uid1, String uid2) {
    final list = [uid1.trim(), uid2.trim()]..sort();
    return 'chat_${list[0]}_${list[1]}';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _getChatId(currentUser.uid, widget.otherUserId);
    _messageController.clear();

    try {
      final now = FieldValue.serverTimestamp();
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': widget.otherUserId,
        'text': text,
        'createdAt': now,
      });

      final chatPayload = <String, dynamic>{
        'members': [currentUser.uid, widget.otherUserId],
        'lastMessage': text,
        'lastMessageTime': now,
        'chatType': _isVendor ? 'vendor' : 'customer',
        'riderId': currentUser.uid,
        'riderName': _riderName,
        'riderPhoto': _riderPhoto,
        'unreadCount': {
          widget.otherUserId: FieldValue.increment(1),
        },
      };

      if (_isVendor) {
        chatPayload['vendorId'] = widget.otherUserId;
        chatPayload['vendorName'] = _displayName;
        chatPayload['vendorPhoto'] = _displayPhoto;
      } else {
        chatPayload['customerId'] = widget.otherUserId;
        chatPayload['customerName'] = _displayName;
        chatPayload['customerPhoto'] = _displayPhoto;
      }

      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        chatPayload['orderId'] = widget.orderId;
      }

      await _firestore.collection('chats').doc(chatId).set(chatPayload, SetOptions(merge: true));

      if (_isVendor) {
        // Dispatch Push Notification to Vendor directly
        NotificationService.sendPushToVendor(
          vendorId: widget.otherUserId,
          title: 'New Message from Rider ($_riderName)',
          body: text,
          data: {
            'type': 'chat_message',
            'chatId': chatId,
            'senderId': currentUser.uid,
            'riderId': currentUser.uid,
            'riderName': _riderName,
            'riderPhotoUrl': _riderPhoto,
            if (widget.orderId != null) 'orderId': widget.orderId,
          },
        );
      } else {
        // Dispatch Notification and FCM to Customer directly
        await _firestore.collection('notifications').add({
          'userId': widget.otherUserId,
          'customerId': widget.otherUserId,
          'title': 'New Message from Rider',
          'body': text,
          'description': text,
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': currentUser.uid,
          'isRead': false,
          'createdAt': now,
        });

        NotificationService.sendPushToCustomer(
          customerId: widget.otherUserId,
          title: 'New Message from $_riderName',
          body: text,
          data: {
            'type': 'chat_message',
            'chatId': chatId,
            'senderId': currentUser.uid,
            'riderId': currentUser.uid,
            'riderName': _riderName,
            'riderPhotoUrl': _riderPhoto,
            if (widget.orderId != null) 'orderId': widget.orderId,
          },
        );
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: Text("Please log in to view conversation")),
      );
    }

    final chatId = _getChatId(currentUser.uid, widget.otherUserId);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
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
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _displayPhoto.isNotEmpty
                  ? Colors.transparent
                  : purpleColor.withValues(alpha: 0.15),
              backgroundImage: _displayPhoto.isNotEmpty
                  ? NetworkImage(_displayPhoto)
                  : null,
              child: _displayPhoto.isEmpty
                  ? Center(
                      child: Text(
                        _displayName.trim().isNotEmpty
                            ? _displayName.trim().split(RegExp(r'\s+')).first[0].toUpperCase()
                            : 'C',
                        style: TextStyle(
                          color: purpleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: purpleColor));
                      }

                      final messages = snapshot.data?.docs ?? [];
                      if (messages.isNotEmpty) {
                        _scrollToBottom();
                      }

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.messageSquare, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No messages yet. Send a message to start!',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: AppTypography.font(14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index].data() as Map<String, dynamic>;
                          final senderId = msg['senderId'] ?? '';
                          final text = msg['text'] ?? '';
                          final isOutgoing = senderId == currentUser.uid;
                          final timeStamp = msg['createdAt'] as Timestamp?;

                          String formattedTime = '';
                          if (timeStamp != null) {
                            final date = timeStamp.toDate();
                            formattedTime =
                                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          }

                          if (isOutgoing) {
                            return _buildOutgoingMessage(context, text, formattedTime, purpleColor);
                          } else {
                            return _buildIncomingMessage(context, text, formattedTime);
                          }
                        },
                      );
                    },
                  ),
                ),
                _buildInputArea(context, backgroundColor, borderColor, purpleColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingMessage(BuildContext context, String text, String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.grey[200],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: AppTypography.font(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingMessage(BuildContext context, String text, String time, Color purpleColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: purpleColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: AppTypography.font(15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: AppTypography.font(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(
      BuildContext context, Color backgroundColor, Color borderColor, Color purpleColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: purpleColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
