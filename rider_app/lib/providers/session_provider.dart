import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/notification_service.dart';
import '../core/services/rider_location_service.dart';
import '../features/home/home_screen.dart';
import 'orders_providers.dart';
import 'rider_app_providers.dart';
import 'rider_profile_provider.dart';

/// Simple session notifier: tracks authentication session status.
class SessionNotifier extends Notifier<bool> {
  @override
  bool build() => FirebaseAuth.instance.currentUser != null;

  /// Marks the user as signed in.
  void signIn() => state = true;

  /// Clears session.
  void signOut() => state = false;
}

final sessionProvider = NotifierProvider<SessionNotifier, bool>(
  SessionNotifier.new,
);

/// Stream provider for Firebase Auth state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Current authenticated rider UID provider.
final currentRiderUidProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.value?.uid ?? FirebaseAuth.instance.currentUser?.uid;
});

/// Invalidate and reset all user-scoped Rider providers so no stale data leaks across accounts.
void resetAllRiderProviders(WidgetRef ref) {
  HomeScreen.resetVerificationPrompt();
  ref.invalidate(riderProfileProvider);
  ref.invalidate(ordersProvider);
  ref.invalidate(riderAvailabilityProvider);
  ref.invalidate(bankDetailsProvider);
  ref.invalidate(riderPendingBankRequestProvider);
  ref.invalidate(ledgerEntriesProvider);
}

/// Invalidate and reset all user-scoped Rider providers via Ref.
void resetAllRiderProvidersRef(Ref ref) {
  HomeScreen.resetVerificationPrompt();
  ref.invalidate(riderProfileProvider);
  ref.invalidate(ordersProvider);
  ref.invalidate(riderAvailabilityProvider);
  ref.invalidate(bankDetailsProvider);
  ref.invalidate(riderPendingBankRequestProvider);
  ref.invalidate(ledgerEntriesProvider);
}

/// Complete sign out helper: cleans up tracking, notification listeners,
/// signs out of Firebase Auth, clears session state, and invalidates all user providers.
Future<void> appSignOut(WidgetRef ref) async {
  try {
    RiderLocationService.instance.stopLiveTracking();
    NotificationService.cancelNotificationsSubscription();
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
  resetAllRiderProviders(ref);
}

/// Variant of appSignOut that accepts a Ref instead of WidgetRef (for use inside Notifiers/Providers).
Future<void> appSignOutRef(Ref ref) async {
  try {
    RiderLocationService.instance.stopLiveTracking();
    NotificationService.cancelNotificationsSubscription();
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
  resetAllRiderProvidersRef(ref);
}
