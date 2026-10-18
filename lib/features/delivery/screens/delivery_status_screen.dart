import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/app_state.dart';
import '../providers/delivery_provider.dart';
import 'delivery_home_screen.dart';
import 'delivery_initial_payment_screen.dart';
import 'delivery_login_screen.dart';
import 'delivery_register_screen.dart';

const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFFFF6F0);
const _kTextDark = Color(0xFF1A1A1A);

class DeliveryStatusScreen extends StatelessWidget {
  const DeliveryStatusScreen({super.key});

  static const routeName = '/delivery/status';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Consumer<AppState>(
                    builder: (context, state, _) {
                      final user = state.user;
                      final status = (user?.approvalStatus ?? 'pending')
                          .toLowerCase();
                      final rejectionReason = user?.rejectionReason ?? '';
                      final title = switch (status) {
                        'approved' => 'Delivery Account Approved',
                        'rejected' => 'Delivery Registration Rejected',
                        'suspended' => 'Delivery Account Suspended',
                        _ => 'Account Under Review',
                      };
                      final message = switch (status) {
                        'approved' =>
                          'Congratulations! Your delivery partner account has been approved. You can now access the delivery dashboard.',
                        'rejected' =>
                          rejectionReason.isEmpty
                              ? 'Your delivery registration has been rejected. Please update your details and resubmit for approval.'
                              : rejectionReason,
                        'suspended' =>
                          rejectionReason.isEmpty
                              ? 'Your delivery account is suspended. Please contact support for assistance.'
                              : rejectionReason,
                        _ =>
                          'Your delivery registration is currently being reviewed by the Super Admin team. You will receive access after approval.',
                      };

                      return Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 560),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 30,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: _kOrangeLight,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Icon(
                                _statusIcon(status),
                                color: _kOrange,
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.55,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (status == 'approved') ...[
                              if (context
                                  .watch<DeliveryProvider>()
                                  .isInitialPaymentRequired) ...[
                                _ActionButton(
                                  label: 'Pay Initial Onboarding Fee',
                                  filled: true,
                                  onPressed: () =>
                                      Navigator.of(context).pushNamed(
                                        DeliveryInitialPaymentScreen.routeName,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _ActionButton(
                                  label: 'Go to Dashboard',
                                  filled: false,
                                  onPressed: () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                        DeliveryHomeScreen.routeName,
                                        (route) => false,
                                      ),
                                ),
                              ] else
                                _ActionButton(
                                  label: 'Go to Dashboard',
                                  filled: true,
                                  onPressed: () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                        DeliveryHomeScreen.routeName,
                                        (route) => false,
                                      ),
                                ),
                            ] else if (status == 'rejected') ...[
                              _ActionButton(
                                label: 'Refresh Status',
                                filled: true,
                                onPressed: () async {
                                  await context
                                      .read<AppState>()
                                      .refreshProfile();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Status refreshed'),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                label: 'Update Registration',
                                filled: false,
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(DeliveryRegisterScreen.routeName),
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                label: 'Logout',
                                filled: false,
                                onPressed: () => _logout(context),
                              ),
                            ] else ...[
                              _ActionButton(
                                label: 'Refresh Status',
                                filled: true,
                                onPressed: () async {
                                  await context
                                      .read<AppState>()
                                      .refreshProfile();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Status refreshed'),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                label: 'Contact Support',
                                filled: false,
                                onPressed: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Contact support at doormartdelivery@gmail.com or call +91 82481 18563',
                                        ),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                label: 'Logout',
                                filled: false,
                                onPressed: () => _logout(context),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _logout(BuildContext context) async {
  final deliveryProvider = context.read<DeliveryProvider>();
  final appState = context.read<AppState>();
  try {
    await deliveryProvider.logout();
    await appState.logout();
  } catch (e) {
    debugPrint('Delivery logout cleanup skipped: $e');
  }
  if (!context.mounted) return;
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(DeliveryLoginScreen.routeName, (route) => false);
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'approved':
      return Icons.verified_rounded;
    case 'rejected':
      return Icons.cancel_rounded;
    case 'suspended':
      return Icons.block_rounded;
    default:
      return Icons.hourglass_top_rounded;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 26,
                color: _kOrange,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Delivery Registration',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                side: const BorderSide(color: _kOrange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }
}
