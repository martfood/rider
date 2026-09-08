import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple mock session: after logout, shell should not be reachable without re-auth (v1: navigation only).
class SessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Marks the user as signed in (mock).
  void signIn() => state = true;

  /// Clears mock session.
  void signOut() => state = false;
}

/// Mock authentication session flag.
final sessionProvider = NotifierProvider<SessionNotifier, bool>(
  SessionNotifier.new,
);
