import 'package:flutter/material.dart';

extension BuildContextExt on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    final theme = Theme.of(this);
    final scaffoldMessenger = ScaffoldMessenger.of(this); // Capture it here

    scaffoldMessenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: isError
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onInverseSurface,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.inverseSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: isError
                ? theme.colorScheme.error
                : theme.colorScheme.inversePrimary,
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar(); // Use the captured reference
            },
          ),
        ),
      );
  }
}