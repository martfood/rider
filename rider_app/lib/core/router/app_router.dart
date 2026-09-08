import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/account/account_change_pin_screen.dart';
import '../../features/account/bank_details_wizard_screen.dart';
import '../../features/account/help_center_rider_screen.dart';
import '../../features/account/id_documents_screen.dart';
import '../../features/account/notifications_settings_rider_screen.dart';
import '../../features/account/profile_edit_screen.dart';
import '../../features/account/rider_legal_screen.dart';
import '../../features/account/rider_privacy_policy_screen.dart';
import '../../features/account/rider_terms_of_use_screen.dart';
import '../../features/account/rider_reviews_screen.dart';
import '../../features/account/rider_security_screen.dart';
import '../../features/account/rider_settings_screen.dart';
import '../../features/account/support_chat_screen.dart';
import '../../features/account/support_conversation_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/forgot_password_otp_screen.dart';
import '../../features/auth/reset_forgotten_password_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/rider_success_screen.dart';
import '../../features/delivery/delivery_shell_screen.dart';
import '../../features/delivery/order_detail_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/earnings/transaction_history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/incoming_order_request_screen.dart';
import '../../features/home/order_request_detail_screen.dart';
import '../../features/messages/conversation_screen.dart';
import '../../features/messages/message_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/get_started_screen.dart';
import '../../features/route_preview/route_preview_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../shell/rider_shell_screen.dart';

/// Root navigator for full-screen routes stacked above the tab shell.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Application-wide routing configuration.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/get-started',
      name: 'get-started',
      builder: (context, state) => const GetStartedScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/auth/login',
      name: 'login',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return LoginScreen(
          suspensionReason: extra?['suspensionReason'] as String?,
          suspendedUntil: extra?['suspendedUntil'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/auth/otp',
      name: 'otp',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return OtpScreen(riderData: data);
      },
    ),
    GoRoute(
      path: '/auth/forgot-password-otp',
      name: 'forgot-password-otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ForgotPasswordOtpScreen(
          email: extra['email'] as String? ?? '',
          otp: extra['otp'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/auth/reset-forgotten-password',
      name: 'reset-forgotten-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ResetForgottenPasswordScreen(
          email: extra['email'] as String? ?? '',
          otp: extra['otp'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/auth/success',
      name: 'auth-success',
      builder: (context, state) => const RiderSuccessScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return RiderShellScreen(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/delivery',
              name: 'delivery',
              builder: (context, state) => const DeliveryShellScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/messages',
              name: 'messages',
              builder: (context, state) => const MessageScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/earnings',
              name: 'earnings',
              builder: (context, state) => const EarningsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/account',
              name: 'account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/incoming-orders',
      name: 'incoming-orders',
      builder: (context, state) => const IncomingOrderRequestScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/conversation',
      name: 'conversation',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ConversationScreen(
          otherUserId: extra['id'] as String? ?? '',
          otherUserName: extra['name'] as String?,
          otherUserPhoto: extra['photo'] as String?,
          isVendor: extra['isVendor'] as bool? ?? false,
          orderId: extra['orderId'] as String?,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/route-preview',
      name: 'route-preview',
      builder: (context, state) => const RoutePreviewScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/order-request/:orderId',
      name: 'order-request-detail',
      builder: (context, state) {
        final id = state.pathParameters['orderId'] ?? '';
        return OrderRequestDetailScreen(orderId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/order/:orderId',
      name: 'order-detail',
      builder: (context, state) {
        final id = state.pathParameters['orderId'] ?? '';
        return OrderDetailScreen(orderId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/orders/:orderId',
      name: 'orders-detail',
      builder: (context, state) {
        final id = state.pathParameters['orderId'] ?? '';
        return OrderDetailScreen(orderId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/profile',
      name: 'account-profile',
      builder: (context, state) => const ProfileEditScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/reviews',
      name: 'account-reviews',
      builder: (context, state) => const RiderReviewsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/id-documents',
      name: 'account-id',
      builder: (context, state) => const IdDocumentsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/security',
      name: 'account-security',
      builder: (context, state) => const RiderSecurityScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/help',
      name: 'account-help',
      builder: (context, state) => const HelpCenterRiderScreen(),
      routes: [
        GoRoute(
          path: 'support',
          name: 'support-chat',
          builder: (context, state) => const SupportChatScreen(),
          routes: [
            GoRoute(
              path: 'conversation',
              name: 'support-conversation',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return SupportConversationScreen(
                  chatId: extra?['id'] ?? 'new',
                  status: extra?['status'] ?? 'active',
                );
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/legal',
      name: 'account-legal',
      builder: (context, state) => const RiderLegalScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/legal/privacy-policy',
      name: 'rider-privacy-policy',
      builder: (context, state) => const RiderPrivacyPolicyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/legal/terms-of-use',
      name: 'rider-terms-of-use',
      builder: (context, state) => const RiderTermsOfUseScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/settings',
      name: 'account-settings',
      builder: (context, state) => const RiderSettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const RiderSettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/appearance',
      name: 'account-appearance',
      builder: (context, state) => const RiderSettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/notifications',
      name: 'account-notifications',
      builder: (context, state) => const NotificationsSettingsRiderScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/change-pin',
      name: 'account-change-pin',
      builder: (context, state) => const AccountChangePinScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/earnings/bank-details',
      name: 'bank-details',
      builder: (context, state) => const BankDetailsWizardScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/account/bank-details',
      name: 'account-bank-details',
      builder: (context, state) => const BankDetailsWizardScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/earnings/transaction-history',
      name: 'earnings-transaction-history',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/transaction-history',
      name: 'transaction-history',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
  ],
);
