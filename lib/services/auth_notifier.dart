// auth_notifier.dart
import 'package:flutter/foundation.dart';

/// Simple notifier for auth state changes
class AuthNotifier {
  static final AuthNotifier _instance = AuthNotifier._internal();
  static AuthNotifier get instance => _instance;
  AuthNotifier._internal();

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notifyAuthStateChanged() {
    for (final listener in _listeners) {
      listener();
    }
  }
}