import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Matches the web app's shared toast component: one queued message,
/// short-lived, non-blocking.
class ToastHelper {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: AppColors.text)),
          backgroundColor: AppColors.card,
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.only(bottom: 90, left: 40, right: 40),
        ),
      );
  }
}
