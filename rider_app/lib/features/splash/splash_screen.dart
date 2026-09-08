import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../../core/services/account_status_service.dart';

/// Brand splash before onboarding.
class SplashScreen extends StatefulWidget {
  /// Creates the splash screen.
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_goNext());
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('riders')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 4));

          if (doc.exists && AccountStatusService.isSuspended(doc.data())) {
            final info = AccountStatusService.parseSuspension(doc.data());
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              context.go('/auth/login', extra: {
                'suspensionReason': info.reason,
                'suspendedUntil': info.suspendedUntil,
              });
            }
            return;
          }
        } catch (_) {}

        if (mounted) {
          context.go('/home');
        }
        return;
      }
    } catch (e) {
      debugPrint('SplashScreen auth check error: $e');
    }

    if (mounted) {
      context.go('/get-started');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: Image.asset(
            'lib/assets/martfood_logo_light.png',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

