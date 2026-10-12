import 'package:flutter/material.dart';

Future<bool> confirmAdminLogout(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.logout_rounded,
        color: Color(0xFFE8541A),
        size: 40,
      ),
      title: const Text(
        'Logout',
        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
      ),
      content: const Text(
        'Are you sure you want to logout?',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF9E9E9E)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8541A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  return result == true;
}
