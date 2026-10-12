import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/delivery_provider.dart';
import '../screens/active_order_screen.dart';
import '../screens/delivery_earnings_screen.dart';
import '../screens/delivery_history_screen.dart';
import '../screens/delivery_home_screen.dart';
import '../screens/delivery_profile_screen.dart';
import '../screens/delivery_initial_payment_screen.dart';

class DeliverySidebarDrawer extends StatelessWidget {
  const DeliverySidebarDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final person = provider.deliveryPerson;
    final initialsSource = (person?.name ?? '').trim();
    final avatarLetter = initialsSource.isNotEmpty
        ? initialsSource[0].toUpperCase()
        : 'D';
    final currentLabel = switch (currentRoute) {
      DeliveryHomeScreen.routeName => 'Home',
      DeliveryHistoryScreen.routeName => 'History',
      DeliveryEarningsScreen.routeName => 'Earnings',
      DeliveryProfileScreen.routeName => 'Profile',
      ActiveOrderScreen.routeName => 'Active Order',
      DeliveryInitialPaymentScreen.routeName => 'Initial Payment',
      _ => 'Home',
    };

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE8541A), Color(0xFFFF7A2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          provider.online ? 'ACTIVE' : 'INACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    person?.name ?? 'Delivery Partner',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person?.phone ?? 'No phone linked',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Quick access • $currentLabel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                children: [
                  _DrawerItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Home',
                    selected: currentRoute == DeliveryHomeScreen.routeName,
                    onTap: () => _go(context, DeliveryHomeScreen.routeName),
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'History',
                    selected: currentRoute == DeliveryHistoryScreen.routeName,
                    onTap: () => _go(context, DeliveryHistoryScreen.routeName),
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Earnings',
                    selected: currentRoute == DeliveryEarningsScreen.routeName,
                    onTap: () => _go(context, DeliveryEarningsScreen.routeName),
                  ),
                  _DrawerItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: currentRoute == DeliveryProfileScreen.routeName,
                    onTap: () => _go(context, DeliveryProfileScreen.routeName),
                  ),
                  _DrawerItem(
                    icon: Icons.payments_rounded,
                    label: 'Initial Payment',
                    selected:
                        currentRoute == DeliveryInitialPaymentScreen.routeName,
                    badgeText: provider.isInitialPaymentPaid
                        ? 'PAID'
                        : 'REQUIRED',
                    badgeColor: provider.isInitialPaymentPaid
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFE8541A),
                    onTap: () =>
                        _go(context, DeliveryInitialPaymentScreen.routeName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    if (route == currentRoute) return;
    if (route == DeliveryHomeScreen.routeName) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    } else if (route == DeliveryHistoryScreen.routeName) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    } else if (route == DeliveryEarningsScreen.routeName) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DeliveryEarningsScreen()));
    } else if (route == DeliveryProfileScreen.routeName) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    } else if (route == DeliveryInitialPaymentScreen.routeName) {
      Navigator.of(context).pushNamed(route);
    }
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0x1AE8541A) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? const Color(0x33E8541A)
                    : const Color(0x1AFFFFFF),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE8541A)
                        : const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected ? 'Current section' : 'Open $label',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? const Color(0xFFE8541A)).withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (badgeColor ?? const Color(0xFFE8541A))
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        color: badgeColor ?? const Color(0xFFE8541A),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
