import 'package:flutter/material.dart';
import '../app.dart';

void showToast(BuildContext context, String message) {
  final messenger =
      DoormartDeliveryApp.scaffoldMessengerKey.currentState ??
      ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
}
