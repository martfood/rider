import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'core/services/account_status_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/theme_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppTypography.scale = 1.0;
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('PreferredOrientations error: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stack) {
    debugPrint('Firebase initialization error: $e\n$stack');
  }

  // Non-blocking notification initialization so runApp() is never blocked or delayed
  try {
    NotificationService.initialize().catchError((e) {
      debugPrint('NotificationService initialization error: $e');
    });
  } catch (e, stack) {
    debugPrint('NotificationService kickoff error: $e\n$stack');
  }

  try {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        NotificationService.registerRiderToken(user.uid);
        NotificationService.listenToFirestoreNotifications(user.uid);
        FirebaseFirestore.instance
            .collection('riders')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
          if (snap.exists) {
            final data = snap.data();
            if (AccountStatusService.isSuspended(data)) {
              final info = AccountStatusService.parseSuspension(data);
              FirebaseAuth.instance.signOut();
              appRouter.go('/auth/login', extra: {
                'suspensionReason': info.reason,
                'suspendedUntil': info.suspendedUntil,
              });
              return;
            }

            final themeStr = data?['themeMode'] as String?;
            if (themeStr != null) {
              ThemeMode mode;
              if (themeStr == 'light') {
                mode = ThemeMode.light;
              } else if (themeStr == 'dark') {
                mode = ThemeMode.dark;
              } else {
                mode = ThemeMode.system;
              }
              ThemeManager.themeModeNotifier.value = mode;
            }
          }
        });
      }
    });
  } catch (e, stack) {
    debugPrint('Auth state changes setup error: $e\n$stack');
  }

  runApp(
    const ProviderScope(
      child: MartFoodRiderApp(),
    ),
  );
}
