import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../providers/rider_profile_provider.dart';

/// Interactive live chat conversation screen between a rider and customer care agents.
class SupportConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String status;

  const SupportConversationScreen({
    super.key,
    required this.chatId,
    required this.status,
  });

  @override
  ConsumerState<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState
    extends ConsumerState<SupportConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();
    final profile = ref.read(riderProfileProvider);
    final uid = user.uid;
    final nowStr = DateTime.now().toIso8601String();

    final messageObj = {
      'senderId': uid,
      'senderName': profile.displayName.isNotEmpty ? profile.displayName : 'Rider',
      'text': text,
      'createdAt': nowStr,
    };

    try {
      final docRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(widget.chatId);
      await docRef.update({
        'status': 'active',
        'lastMessage': text,
        'lastMessageAt': nowStr,
        'messages': FieldValue.arrayUnion([messageObj]),
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending support message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isUploadingImage || widget.chatId.isEmpty) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      String imageUrl = '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('support_chats')
            .child(widget.chatId)
            .child(fileName);
        await storageRef.putFile(File(pickedFile.path));
        imageUrl = await storageRef.getDownloadURL();
      } catch (storageErr) {
        debugPrint('Firebase Storage error, encoding fallback: $storageErr');
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Str = base64Encode(bytes);
        imageUrl = 'data:image/jpeg;base64,$base64Str';
      }

      if (imageUrl.isEmpty) return;

      final profile = ref.read(riderProfileProvider);
      final nowStr = DateTime.now().toIso8601String();
      final messageObj = {
        'senderId': user.uid,
        'senderName': profile.displayName.isNotEmpty ? profile.displayName : 'Rider',
        'text': '',
        'imageUrl': imageUrl,
        'createdAt': nowStr,
      };

      final docRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(widget.chatId);
      await docRef.update({
        'status': 'active',
        'lastMessage': '📷 Image attachment',
        'lastMessageAt': nowStr,
        'messages': FieldValue.arrayUnion([messageObj]),
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minStr = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minStr $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

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
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('support_chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final subject = data?['subject'] ?? 'Customer Support';
            final ticketStatus = (data?['status'] ?? widget.status).toString();
            final isResolved = ticketStatus == 'closed';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w800,
                    fontSize: AppTypography.font(16),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isResolved ? 'Resolved Ticket' : 'Active Support Ticket',
                      style: TextStyle(
                        fontSize: AppTypography.font(11),
                        fontWeight: FontWeight.w600,
                        color: isResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_chats')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: purpleColor));
                }

                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final messages = (data?['messages'] as List<dynamic>?) ?? [];
                final ticketStatus = (data?['status'] ?? widget.status).toString();
                final isResolved = ticketStatus == 'closed';

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return Column(
                  children: [
                    // Chat Messages List
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: purpleColor.withValues(alpha: 0.10),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(LucideIcons.messageSquare, color: purpleColor, size: 28),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'How can we help you?',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(16),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Type your message below and a member of our support team will reply shortly.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: AppTypography.font(13),
                                        color: mutedTextColor,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index] as Map<String, dynamic>;
                                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                                final isMe = msg['senderId'] == currentUid;
                                final text = (msg['text'] ?? '').toString();
                                final imageUrl = (msg['imageUrl'] ?? '').toString();
                                final timeStr = _formatTime((msg['createdAt'] ?? '').toString());

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (!isMe) ...[
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: purpleColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(LucideIcons.headset, color: purpleColor, size: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? const Color(0xFF4A154B)
                                                    : cardBg,
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(18),
                                                  topRight: const Radius.circular(18),
                                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                                ),
                                                border: isMe
                                                    ? null
                                                    : Border.all(color: borderColor, width: 1),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (imageUrl.isNotEmpty) ...[
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: imageUrl.startsWith('data:image')
                                                          ? Image.memory(
                                                              base64Decode(imageUrl.split(',').last),
                                                              width: 200,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : CachedNetworkImage(
                                                              imageUrl: imageUrl,
                                                              width: 200,
                                                              fit: BoxFit.cover,
                                                              placeholder: (c, u) => Container(
                                                                height: 120,
                                                                width: 200,
                                                                color: Colors.black12,
                                                                child: const Center(
                                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                                ),
                                                              ),
                                                              errorWidget: (c, u, e) => const Icon(Icons.broken_image),
                                                            ),
                                                    ),
                                                    if (text.isNotEmpty) const SizedBox(height: 8),
                                                  ],
                                                  if (text.isNotEmpty)
                                                    Text(
                                                      text,
                                                      style: TextStyle(
                                                        color: isMe ? Colors.white : primaryTextColor,
                                                        fontSize: AppTypography.font(14),
                                                        height: 1.4,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (timeStr.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: 4,
                                            left: isMe ? 0 : 40,
                                            right: isMe ? 4 : 0,
                                          ),
                                          child: Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: AppTypography.font(10),
                                              color: mutedTextColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Resolved banner or Input Bar
                    if (isResolved)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border(top: BorderSide(color: borderColor, width: 1)),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.circleCheck, color: const Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This ticket is closed. Start a new ticket from the support menu if you need further help.',
                                style: TextStyle(
                                  fontSize: AppTypography.font(12),
                                  color: mutedTextColor,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border(top: BorderSide(color: borderColor, width: 1)),
                        ),
                        child: Row(
                          children: [
                            // Image Attachment Button
                            GestureDetector(
                              onTap: _isUploadingImage ? null : _pickAndSendImage,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: _isUploadingImage
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: purpleColor,
                                          ),
                                        ),
                                      )
                                    : Icon(LucideIcons.image, color: purpleColor, size: 20),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Text Input Field
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: TextStyle(
                                    fontSize: AppTypography.font(14),
                                    color: primaryTextColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type your message...',
                                    hintStyle: TextStyle(
                                      fontSize: AppTypography.font(13),
                                      color: mutedTextColor,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Send Button
                            GestureDetector(
                              onTap: _isSending ? null : _sendMessage,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4A154B),
                                  shape: BoxShape.circle,
                                ),
                                child: _isSending
                                    ? const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          LucideIcons.send,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                              ),
                            ),
                          ],
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
