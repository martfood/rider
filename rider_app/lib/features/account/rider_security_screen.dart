import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class RiderSecurityScreen extends StatelessWidget {
  const RiderSecurityScreen({super.key});

  void _resetPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User email not found. Please log in again.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('password_resets').add({
        'email': user.email!,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userType': 'rider',
      });
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.mark_email_read, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Email Sent', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Password reset email sent to ${user.email}. Please check your inbox.',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: AppTextStyles.bodyLarge.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Security', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Responsive.maxContainer(
        context: context,
        maxWidth: 600,
        child: ListView(
          padding: Responsive.padding(context),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Reset password', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Send a secure password reset email link.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _resetPassword(context),
            ),
          ],
        ),
      ),
    );
  }
}
