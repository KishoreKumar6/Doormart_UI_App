import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_state.dart';
import '../providers/delivery_provider.dart';
import '../widgets/delivery_sidebar_drawer.dart';
import 'delivery_login_screen.dart';
import 'delivery_status_details_screen.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_initial_payment_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF7F7F7);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF888888);
const _kBorder = Color(0xFFF0F0F0);

class DeliveryProfileScreen extends StatefulWidget {
  const DeliveryProfileScreen({super.key});
  static const routeName = '/delivery/profile';

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppState>();
      final provider = context.read<DeliveryProvider>();
      if ((provider.authToken == null || provider.authToken!.isEmpty) &&
          appState.token != null &&
          appState.token!.isNotEmpty) {
        provider.authToken = appState.token;
      }
      if (provider.authUser == null && appState.user != null) {
        provider.authUser = appState.user!.toJson();
      }
      await provider.bootstrap();
      if (provider.deliveryPerson == null && appState.user != null) {
        provider.hydrateFromSession(
          token: provider.authToken ?? appState.token ?? '',
          user: appState.user!,
        );
      }
      await provider.refreshProfile();
      await provider.syncInitialPaymentStatus();
      await provider.loadStatusDetails();
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.logout_rounded, color: _kOrange, size: 40),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w900, color: _kTextDark),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kTextMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextMid)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<DeliveryProvider>().logout();
      await context.read<AppState>().logout();
    } catch (e) {
      debugPrint('Delivery logout cleanup skipped: $e');
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(DeliveryLoginScreen.routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final appState = context.watch<AppState>();
    final provider = context.watch<DeliveryProvider>();
    final person = provider.deliveryPerson;
    final approvalStatus = (appState.user?.approvalStatus ?? 'approved')
        .toLowerCase();
    final earnings = provider.earningsStats;
    final totalEarnings =
        (earnings['total'] as num?)?.toDouble() ?? person?.todayEarnings ?? 0;
    final completedOrders =
        (earnings['completedOrders'] as num?)?.toInt() ??
        person?.completedOrders ??
        0;
    final activeSince = _activeSinceLabel(provider.statusDetails);

    return Scaffold(
      backgroundColor: _kBg,
      drawer: const DeliverySidebarDrawer(
        currentRoute: DeliveryProfileScreen.routeName,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──────────────────────────────────────────────────
            _AppBar(person: person, approvalStatus: approvalStatus),

            // ── Scrollable body ──────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 100 + bottomInset),
                children: [
                  // ── Profile header ─────────────────────────────────────
                  _ProfileHeader(
                    person: person,
                    approvalStatus: approvalStatus,
                  ),

                  const SizedBox(height: 20),

                  // ── Work status card ───────────────────────────────────
                  _ShiftStatusCard(
                    online: provider.online,
                    isPaymentRequired: provider.isInitialPaymentRequired,
                    activeSince: activeSince,
                  ),

                  const SizedBox(height: 16),

                  // ── Stats banner ───────────────────────────────────────
                  _StatsBanner(
                    person: person,
                    totalEarnings: totalEarnings,
                    completedOrders: completedOrders,
                  ),

                  const SizedBox(height: 20),

                  // ── Account settings ───────────────────────────────────
                  _AccountSettingsCard(person: person),

                  const SizedBox(height: 20),

                  // ── Logout button ──────────────────────────────────────
                  _LogoutButton(onTap: _logout),

                  const SizedBox(height: 20),

                  // ── Footer ────────────────────────────────────────────
                  const _Footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _activeSinceLabel(List<Map<String, dynamic>> logs) {
  final onlineLog = logs
      .where(
        (log) => (log['status']?.toString().toLowerCase() ?? '') == 'online',
      )
      .where((log) => log['startedAt'] != null)
      .where(
        (log) =>
            log['endedAt'] == null || log['endedAt'].toString().trim().isEmpty,
      )
      .toList();
  if (onlineLog.isEmpty) {
    return 'Just now';
  }
  final latest = onlineLog.first;
  final startedAt = DateTime.tryParse(
    latest['startedAt'].toString(),
  )?.toLocal();
  if (startedAt == null) {
    return 'Just now';
  }
  final hour = startedAt.hour % 12 == 0 ? 12 : startedAt.hour % 12;
  final minute = startedAt.minute.toString().padLeft(2, '0');
  final period = startedAt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.person, required this.approvalStatus});
  final dynamic person;
  final String approvalStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: _kTextDark),
              tooltip: 'Open menu',
            ),
          ),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Door ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kOrange,
                  ),
                ),
                TextSpan(
                  text: 'Mart',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
              ],
            ),
          ),
          if (approvalStatus != 'approved') ...[
            const SizedBox(width: 10),
            _StatusBadge(status: approvalStatus),
          ],
          const Spacer(),
          // Bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: _kTextDark,
                size: 24,
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kOrange, width: 2),
            ),
            child: ClipOval(
              child: person?.avatarUrl?.startsWith('http') == true
                  ? Image.network(
                      person!.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _AvatarFallback(size: 36),
                    )
                  : const _AvatarFallback(size: 36),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.person, required this.approvalStatus});
  final dynamic person;
  final String approvalStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Avatar with verified badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kOrange, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: person?.avatarUrl?.startsWith('http') == true
                    ? Image.network(
                        person!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _AvatarFallback(size: 100),
                      )
                    : const _AvatarFallback(size: 100),
              ),
            ),
            // Verified badge
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _kOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _StatusBadge(status: approvalStatus),

        const SizedBox(height: 12),

        // Name
        Text(
          person?.name ?? 'Delivery Partner',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _kTextDark,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 4),

        // ID
        Text(
          'ID: ${_shortId(person?.id)}',
          style: const TextStyle(
            fontSize: 14,
            color: _kTextMid,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 14),

        // Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Badge(
              label: '⭐  Top Rated',
              bgColor: _kOrangeLight,
              textColor: _kOrange,
            ),
            const SizedBox(width: 8),
            _Badge(
              label: 'Active Now',
              bgColor: const Color(0xFFF0F0F0),
              textColor: _kTextDark,
            ),
          ],
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final label = switch (normalized) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'suspended' => 'Suspended',
      _ => 'Pending Approval',
    };
    final bgColor = switch (normalized) {
      'approved' => const Color(0xFFEAF7ED),
      'rejected' => const Color(0xFFFDECEC),
      'suspended' => const Color(0xFFFFF4DB),
      _ => const Color(0xFFFFF0EB),
    };
    final textColor = switch (normalized) {
      'approved' => const Color(0xFF15803D),
      'rejected' => const Color(0xFFB91C1C),
      'suspended' => const Color(0xFFB45309),
      _ => _kOrange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

// ─── Work / Shift Status Card ─────────────────────────────────────────────────

class _ShiftStatusCard extends StatelessWidget {
  const _ShiftStatusCard({
    required this.online,
    this.isPaymentRequired = false,
    required this.activeSince,
  });
  final bool online;
  final bool isPaymentRequired;
  final String activeSince;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Work Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  online ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF22C55E)
                            : (isPaymentRequired
                                  ? const Color(0xFFDC2626)
                                  : Colors.grey),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        online
                            ? 'Active since $activeSince'
                            : (isPaymentRequired
                                  ? 'Payment required to work'
                                  : 'Currently off duty'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: online
                              ? const Color(0xFF22C55E)
                              : (isPaymentRequired
                                    ? const Color(0xFFDC2626)
                                    : _kTextMid),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // WiFi signal icon box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: online ? const Color(0xFFECFDF5) : _kOrangeLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: online ? const Color(0xFF22C55E) : _kOrange,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Banner ─────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.person,
    required this.totalEarnings,
    required this.completedOrders,
  });
  final dynamic person;
  final double totalEarnings;
  final int completedOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF26522), Color(0xFFE8401A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background watermark icon
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.delivery_dining_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Top 5% Driver',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Total Earnings',
                      value: '₹${totalEarnings.toStringAsFixed(2)}',
                      large: true,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.check_circle_rounded,
                      label: 'Completed',
                      value: '$completedOrders',
                      large: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.large,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: large ? 24 : 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Account Settings Card ────────────────────────────────────────────────────

class _AccountSettingsCard extends StatelessWidget {
  const _AccountSettingsCard({required this.person});
  final dynamic person;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final isPaid = provider.isInitialPaymentPaid;
    final amount = provider.initialPaymentAmount;
    final displayAmount = amount > 0 ? amount.toStringAsFixed(0) : '500';

    final items = [
      _SettingItem(
        icon: Icons.payments_rounded,
        label: 'Partner Onboarding Fee',
        subtitle: isPaid
            ? 'Verified & Paid (₹$displayAmount)'
            : 'Payment Required • ₹$displayAmount',
        onTap: () => Navigator.of(
          context,
        ).pushNamed(DeliveryInitialPaymentScreen.routeName),
      ),
      _SettingItem(
        icon: Icons.phone_rounded,
        label: 'Phone Number',
        subtitle: person?.phone ?? '+1 (555) 012-3456',
        onTap: () => _editField(
          context,
          title: 'Edit Phone Number',
          initialValue: person?.phone ?? '',
          hint: 'Enter phone number',
          keyboardType: TextInputType.phone,
          onSave: (value) async {
            final message = await provider.updateProfile(phone: value);
            if (context.mounted && message != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          },
        ),
      ),
      _SettingItem(
        icon: Icons.local_shipping_rounded,
        label: 'Vehicle Number',
        subtitle: person?.vehicleNumber ?? 'NY-8829-DEL',
        onTap: () => _editField(
          context,
          title: 'Edit Vehicle Number',
          initialValue: person?.vehicleNumber ?? '',
          hint: 'Enter vehicle number',
          keyboardType: TextInputType.text,
          onSave: (value) async {
            final message = await provider.updateProfile(vehicleNumber: value);
            if (context.mounted && message != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          },
        ),
      ),
      _SettingItem(
        icon: Icons.bar_chart_rounded,
        label: 'Earnings Detail',
        subtitle: 'View daily, weekly and monthly earnings',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeliveryEarningsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.av_timer_rounded,
        label: 'Status Details',
        subtitle: 'View online/offline timing history',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DeliveryStatusDetailsScreen(),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.help_outline_rounded,
        label: 'Help & Support',
        subtitle: '24/7 dedicated partner support',
        onTap: () => _showInfoSheet(
          context,
          title: 'Help & Support',
          body:
              'For delivery issues, order assignment problems, or account help, contact support at doormartdelivery@gmail.com or call +91 82481 18563.',
        ),
        isLast: false,
      ),
      _SettingItem(
        icon: Icons.description_outlined,
        label: 'Terms of Service',
        subtitle: 'Policy updates and legal info',
        onTap: () => _showInfoSheet(
          context,
          title: 'Terms of Service',
          body:
              'By using the delivery dashboard, you agree to follow order assignment rules, delivery verification steps, and platform policies set by DoorMart.',
        ),
        isLast: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 4),
            child: Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
              ),
            ),
          ),
          ...items.map((item) => _SettingRow(item: item)),
        ],
      ),
    );
  }
}

Future<void> _editField(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String hint,
  required TextInputType keyboardType,
  required Future<void> Function(String value) onSave,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _kOrange),
                  onPressed: () =>
                      Navigator.pop(sheetContext, controller.text.trim()),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (result == null || result.isEmpty) return;
  await onSave(result);
}

void _showInfoSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: _kTextMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class _SettingItem {
  const _SettingItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;
}

class _SettingRow extends StatefulWidget {
  const _SettingRow({required this.item});
  final _SettingItem item;

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.97,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.item.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: [
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // Icon box
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.item.icon, size: 20, color: _kTextDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _kTextMid,
                  ),
                ],
              ),
            ),
            if (!widget.item.isLast)
              Divider(height: 1, indent: 72, endIndent: 18, color: _kBorder),
          ],
        ),
      ),
    );
  }
}

// ─── Logout Button ────────────────────────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTap: () {
        _c.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF26522), Color(0xFFE8401A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kOrange.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

String _shortId(String? id) {
  final value = (id ?? '').trim();
  if (value.isEmpty) return 'DMD-00000000';
  var cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  if (cleaned.startsWith('DMD')) cleaned = cleaned.substring(3);
  if (cleaned.length > 8) cleaned = cleaned.substring(0, 8);
  return 'DMD-${cleaned.padRight(8, '0')}';
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Version 1',
          style: TextStyle(
            fontSize: 12,
            color: _kTextMid,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '© 2026 Delivery Pro Logistics',
          style: TextStyle(fontSize: 12, color: _kTextMid),
        ),
      ],
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

// ─── Avatar Fallback ──────────────────────────────────────────────────────────

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: _kOrangeLight,
      child: Icon(Icons.person_rounded, size: size * 0.55, color: _kOrange),
    );
  }
}
