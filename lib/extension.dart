import 'package:flutter/material.dart';

extension BuildContextExt on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    // Access the theme to use Material 3 colors
    final theme = Theme.of(this);

    ScaffoldMessenger.of(this)
      ..clearSnackBars() // Removes existing snackbars to prevent queuing
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: isError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onInverseSurface,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? theme.colorScheme.errorContainer : theme.colorScheme.inverseSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16), // Gives it the "floating" look
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: isError ? theme.colorScheme.error : theme.colorScheme.inversePrimary,
            onPressed: () {
              ScaffoldMessenger.of(this).hideCurrentSnackBar();
            },
          ),
        ),
      );
  }
}