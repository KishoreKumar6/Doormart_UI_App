import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_state.dart';
import '../../../services/api_service.dart';
import '../providers/delivery_provider.dart';
import 'active_order_screen.dart';
import 'delivery_history_screen.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_profile_screen.dart';
import 'delivery_initial_payment_screen.dart';
import '../models/delivery_order_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF7F7F7);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF888888);
const _kGreen = Color(0xFF22C55E);

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});
  static const routeName = '/delivery';

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with WidgetsBindingObserver {
  _MetricRange _range = _MetricRange.today;
  bool _locationServiceEnabled = true;
  LocationPermission _locationPermission = LocationPermission.always;
  bool _locationReady = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck automatically when the user returns from device settings.
      _refreshLocationStatus();
    }
  }

  bool _isCheckingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus();
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
      await provider.syncOnlineState();
      await provider.syncInitialPaymentStatus();
      await provider.loadDashboard();
    });
  }

  void _showInitialPaymentRequiredDialog(BuildContext context, double amount) {
    final displayAmount = amount > 0 ? amount.toStringAsFixed(0) : '500';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: _kOrangeLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.payments_rounded, color: _kOrange, size: 30),
        ),
        title: const Text(
          'Initial Payment Required',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: _kTextDark,
            fontSize: 18,
          ),
        ),
        content: Text(
          'A one-time partner onboarding payment of ₹$displayAmount is required before you can go online and receive customer delivery orders.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kTextMid, fontSize: 14, height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later', style: TextStyle(color: _kTextMid)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(
                context,
              ).pushNamed(DeliveryInitialPaymentScreen.routeName);
            },
            child: Text(
              'Pay ₹$displayAmount Now',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshLocationStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _locationServiceEnabled = serviceEnabled;
      _locationPermission = permission;
      _locationReady =
          serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);
    });
  }

  Future<void> _openLocationSettings() async {
    if (!_locationServiceEnabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
    await _refreshLocationStatus();
  }

  /// Blocks going online until location services AND permission are available.
  Future<bool> _ensureLocationReady() async {
    await _refreshLocationStatus();
    if (!mounted) return _locationReady;
    if (_locationReady) return true;
    if (!_locationServiceEnabled) {
      await _openLocationSettings();
      return _locationReady;
    }
    var permission = _locationPermission;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (mounted) {
        setState(() {
          _locationPermission = permission;
          _locationReady =
              permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse;
        });
      }
    }
    if (!_locationReady) {
      await _openLocationSettings();
    }
    return _locationReady;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final appState = context.watch<AppState>();
    final provider = context.watch<DeliveryProvider>();
    final person = provider.deliveryPerson;
    final approvalStatus = (appState.user?.approvalStatus ?? 'approved');
    final stats = provider.earningsStats;
    final completed = _completedOrdersForRange(stats, _range);
    final earnings = _earningsForRange(stats, _range);
    final statsLoaded = stats.isNotEmpty;

    return Scaffold(
      backgroundColor: _kBg,
      drawer: _DeliverySidebarDrawer(
        currentRoute: DeliveryHomeScreen.routeName,
      ),
      // ── Top App Bar ────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: _kTextDark),
            tooltip: 'Open menu',
          ),
        ),
        title: RichText(
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
        actions: [
          if (approvalStatus != 'approved') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'PENDING APPROVAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kOrange,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Online badge
          if (provider.online)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kOrangeLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'ACTIVE NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kOrange,
                ),
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),

      // ── Body ──────────────────────────────────────────────────────────
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + bottomInset),
        children: [
          if (!_locationReady) ...[
            _LocationDisabledBanner(
              serviceDisabled: !_locationServiceEnabled,
              onTurnOn: _openLocationSettings,
            ),
            const SizedBox(height: 16),
          ],
          // ── Profile card ─────────────────────────────────────────────
          // ── Initial Payment Section ─────────────────────────────────────
          if (provider.isInitialPaymentRequired) ...[
            _InitialPaymentRequiredCard(
              amount: provider.initialPaymentAmount,
              isChecking: _isCheckingPayment,
              onPayTap: () {
                Navigator.of(
                  context,
                ).pushNamed(DeliveryInitialPaymentScreen.routeName);
              },
              onVerifyTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _isCheckingPayment = true);
                try {
                  await provider.syncInitialPaymentStatus();
                  if (!mounted) return;
                  if (provider.isInitialPaymentPaid) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment verified successfully! You are eligible to work.',
                        ),
                      ),
                    );
                    await provider.loadDashboard();
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment not verified yet. If you completed payment, please try again in a few moments.',
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isCheckingPayment = false);
                }
              },
            ),
            const SizedBox(height: 16),
          ] else ...[
            _InitialPaymentPaidCard(
              amount: provider.initialPaymentAmount,
              completedAt: provider.initialPaymentCompletedAt,
              onViewTap: () {
                Navigator.of(
                  context,
                ).pushNamed(DeliveryInitialPaymentScreen.routeName);
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── Work Status & Profile Card ────────────────────────────────
          _ProfileCard(
            name: person?.name ?? 'Delivery Partner',
            deliveryId: _shortId(person?.id),
            imageUrl: person?.avatarUrl ?? '',
            online: provider.online,
            isPaymentRequired: provider.isInitialPaymentRequired,
            onToggle: (v) async {
              HapticFeedback.lightImpact();
              final messenger = ScaffoldMessenger.of(context);
              if (v && !await _ensureLocationReady()) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Turn on location and allow location access to go online.',
                    ),
                  ),
                );
                return;
              }
              if (v && provider.isInitialPaymentRequired) {
                if (!mounted) return;
                _showInitialPaymentRequiredDialog(
                  this.context,
                  provider.initialPaymentAmount,
                );
                return;
              }
              try {
                if (v) {
                  await provider.goOnline();
                } else {
                  await provider.goOffline();
                }
              } on ApiException catch (e) {
                if (!context.mounted) return;
                if (e.code == 'INITIAL_PAYMENT_REQUIRED' ||
                    e.statusCode == 403) {
                  _showInitialPaymentRequiredDialog(
                    context,
                    provider.initialPaymentAmount,
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),

          const SizedBox(height: 16),

          // ── Metric cards ──────────────────────────────────────────────
          _MetricRangeToggle(
            range: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          const SizedBox(height: 12),
          if (provider.loading)
            const _MetricsSkeleton()
          else if (!statsLoaded)
            const _MetricsSkeleton()
          else
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.delivery_dining_rounded,
                    iconBg: const Color(0xFFFFF0EB),
                    iconColor: _kOrange,
                    label: 'ORDERS COMPLETED',
                    value: completed == null ? '0' : '$completed',
                    tag: _range.label,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconColor: const Color(0xFF6366F1),
                    label: 'EARNINGS EARNED',
                    value: '₹${(earnings ?? 0).toStringAsFixed(2)}',
                    tag: _range.label,
                    largeValue: true,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          const SizedBox(height: 15),

          if (approvalStatus != 'approved')
            const _EmptyState(
              icon: Icons.hourglass_top_rounded,
              message:
                  'Your delivery partner account is pending admin approval',
            )
          else if (provider.isInitialPaymentRequired)
            _EmptyState(
              icon: Icons.payments_rounded,
              message:
                  'Complete your one-time onboarding payment to start working and receive delivery orders',
            )
          else if (!provider.online)
            const _EmptyState(
              icon: Icons.pause_circle_outline_rounded,
              message:
                  'You are currently Inactive. Turn on Work Status to start receiving requests.',
            )
          else if (provider.pendingRequests.isEmpty)
            const _EmptyState(
              icon: Icons.inbox_rounded,
              message: 'No new requests right now',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 560,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.92),
                    itemCount: provider.pendingRequests.length,
                    itemBuilder: (context, i) {
                      final order = provider.pendingRequests[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _NewRequestCard(
                          order: order,
                          onAccept: () {
                            HapticFeedback.mediumImpact();
                            provider.acceptOrder(order);
                          },
                          onReject: () => provider.rejectOrder(order),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // ── Active Order ──────────────────────────────────────────────
          if (provider.activeOrder != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(ActiveOrderScreen.routeName),
                  child: _ActiveOrderCard(order: provider.activeOrder!),
                ),
              ],
            )
          else
            const _EmptyState(
              icon: Icons.inbox_rounded,
              message: 'There is no active order right now',
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _LocationDisabledBanner extends StatelessWidget {
  const _LocationDisabledBanner({
    required this.onTurnOn,
    this.serviceDisabled = true,
  });

  final VoidCallback onTurnOn;
  final bool serviceDisabled;

  @override
  Widget build(BuildContext context) {
    final title = serviceDisabled
        ? 'Location is turned off'
        : 'Location permission is required';
    final message = serviceDisabled
        ? 'Turn on your phone location to receive orders and share live delivery tracking.'
        : 'Allow location access in your app settings to receive orders and share live delivery tracking.';
    final actionLabel = serviceDisabled ? 'Turn on' : 'Allow';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            serviceDisabled
                ? Icons.location_off_rounded
                : Icons.location_searching_rounded,
            color: const Color(0xFFEA580C),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTurnOn,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEA580C),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.deliveryId,
    required this.imageUrl,
    required this.online,
    this.isPaymentRequired = false,
    required this.onToggle,
  });

  final String name;
  final String deliveryId;
  final String imageUrl;
  final bool online;
  final bool isPaymentRequired;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kOrange, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _AvatarFallback(),
                        )
                      : const _AvatarFallback(),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: online ? _kGreen : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: $deliveryId',
            style: const TextStyle(
              fontSize: 13,
              color: _kTextMid,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Work status toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        online
                            ? 'Active • Ready for orders'
                            : (isPaymentRequired
                                  ? 'Inactive • Payment required'
                                  : 'Inactive • Off duty'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: online
                              ? _kGreen
                              : (isPaymentRequired
                                    ? const Color(0xFFDC2626)
                                    : _kTextMid),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: online
                              ? const Color(0xFFECFDF5)
                              : (isPaymentRequired
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          online ? 'ACTIVE' : 'INACTIVE',
                          key: ValueKey(online),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: online
                                ? _kGreen
                                : (isPaymentRequired
                                      ? const Color(0xFFDC2626)
                                      : _kTextMid),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch.adaptive(
                        value: online,
                        onChanged: onToggle,
                        activeThumbColor: _kGreen,
                        activeTrackColor: _kGreen.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _shortId(String? id) {
  final value = (id ?? '').trim();
  if (value.isEmpty) return 'DMD-00000000';
  var cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  if (cleaned.startsWith('DMD')) cleaned = cleaned.substring(3);
  if (cleaned.length > 8) cleaned = cleaned.substring(0, 8);
  return 'DMD-${cleaned.padRight(8, '0')}';
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kOrangeLight,
      child: const Icon(Icons.person_rounded, size: 44, color: _kOrange),
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.tag,
    this.largeValue = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String tag;
  final bool largeValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kTextMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: largeValue ? 24 : 28,
                fontWeight: FontWeight.w900,
                color: _kOrange,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kTextMid,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRangeToggle extends StatelessWidget {
  const _MetricRangeToggle({required this.range, required this.onChanged});

  final _MetricRange range;
  final ValueChanged<_MetricRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _MetricRange.values.map((item) {
        final selected = item == range;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(item.label),
            selected: selected,
            onSelected: (_) => onChanged(item),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _kTextDark,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: _kOrange,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _kOrange : const Color(0xFFE5E7EB),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _SkeletonCard()),
        SizedBox(width: 12),
        Expanded(child: _SkeletonCard()),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBar(width: 24),
            SizedBox(height: 14),
            _ShimmerBar(width: 80),
            SizedBox(height: 10),
            _ShimmerBar(width: 54, height: 22),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.width, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

enum _MetricRange { today, weekly, monthly }

extension on _MetricRange {
  String get label => switch (this) {
    _MetricRange.today => 'Today',
    _MetricRange.weekly => 'Weekly',
    _MetricRange.monthly => 'Monthly',
  };
}

int? _completedOrdersForRange(Map<String, dynamic> stats, _MetricRange range) {
  final value = switch (range) {
    _MetricRange.today =>
      stats['todayCompletedOrders'] ?? stats['completedOrders'],
    _MetricRange.weekly =>
      stats['weeklyCompletedOrders'] ?? stats['completedOrders'],
    _MetricRange.monthly =>
      stats['monthlyCompletedOrders'] ?? stats['completedOrders'],
  };
  return (value as num?)?.toInt();
}

double? _earningsForRange(Map<String, dynamic> stats, _MetricRange range) {
  final value = switch (range) {
    _MetricRange.today => stats['today'] ?? stats['todayEarnings'],
    _MetricRange.weekly => stats['weekly'] ?? stats['weeklyEarnings'],
    _MetricRange.monthly => stats['monthly'] ?? stats['monthlyEarnings'],
  };
  return (value as num?)?.toDouble();
}

// ─── New Request Card ─────────────────────────────────────────────────────────

class _NewRequestCard extends StatefulWidget {
  const _NewRequestCard({
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  final DeliveryOrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<_NewRequestCard> createState() => _NewRequestCardState();
}

class _NewRequestCardState extends State<_NewRequestCard> {
  @override
  Widget build(BuildContext context) {
    final storeName = _text(
      widget.order.vendorStoreName,
      fallback: 'Store order',
    );
    final customerName = _text(widget.order.customerName, fallback: 'Customer');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFD8C8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8541A).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF8F4), Color(0xFFFFEEE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: _kOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kOrange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'NEW REQUEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          storeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _kTextDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Deliver to $customerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kTextMid,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showItemsSheet(context),
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    style: TextButton.styleFrom(
                      foregroundColor: _kOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    label: const Text('Items'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailLine(
                    'Placed',
                    _formatDate(_orderCreatedAt(widget.order)),
                  ),
                  _detailLine(
                    'Phone',
                    _text(widget.order.customerPhone, fallback: '—'),
                  ),
                  _detailLine('Address', _fullCustomerAddress(widget.order)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD3C2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.order.isCod
                                    ? 'COLLECT FROM CUSTOMER'
                                    : 'ORDER TOTAL',
                                style: const TextStyle(
                                  color: _kTextMid,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.order.isCod
                                    ? 'Cash on delivery'
                                    : 'Payment received online',
                                style: const TextStyle(
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${(widget.order.codAmount ?? widget.order.totalAmount).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _kOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF7A1A), Color(0xFFE9471C)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                      child: FilledButton.icon(
                        onPressed: widget.onAccept,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                        label: const Text('Accept delivery request'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* Removed duplicate legacy items sheet implementation.
  Future<void> _showItemsSheet(BuildContext context) {
    final items = _requestItems(widget.order);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                            ),
                          ),
                        ),
                        Text(
                          '₹${(widget.order.codAmount ?? widget.order.totalAmount).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _kOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onAccept,
                      icon: const Icon(Icons.check_circle_outline, size: 19),
                      label: const Text('Accept delivery request'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  }
  */

  Future<void> _showItemsSheet(BuildContext context) {
    final items = _requestItems(widget.order);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                  const SizedBox(height: 18),
                  Text(
                    'Order details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pickup from vendor',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _detailLine(
                    'Store',
                    _text(widget.order.vendorStoreName, fallback: '—'),
                  ),
                  _detailLine('Address', _fullVendorAddress(widget.order)),
                  if (widget.order.vendorLatitude != null &&
                      widget.order.vendorLongitude != null)
                    _detailLine(
                      'Coordinates',
                      '${widget.order.vendorLatitude!.toStringAsFixed(6)}, ${widget.order.vendorLongitude!.toStringAsFixed(6)}',
                    ),
                  _detailLine(
                    'Phone',
                    _text(widget.order.vendorPhone, fallback: '—'),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 24),
                  const SizedBox(height: 2),
                  const Text(
                    'Deliver to customer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _detailLine(
                    'Customer',
                    _text(widget.order.customerName, fallback: '—'),
                  ),
                  _detailLine(
                    'Phone',
                    _text(widget.order.customerPhone, fallback: '—'),
                  ),
                  _detailLine('Address', _fullCustomerAddress(widget.order)),
                  if (widget.order.customerLatitude != null &&
                      widget.order.customerLongitude != null)
                    _detailLine(
                      'Coordinates',
                      '${widget.order.customerLatitude!.toStringAsFixed(6)}, ${widget.order.customerLongitude!.toStringAsFixed(6)}',
                    ),
                  _detailLine(
                    'Placed',
                    _formatDate(_orderCreatedAt(widget.order)),
                  ),
                  _DeliveryAmountSummary(order: widget.order),
                  const SizedBox(height: 18),
                  const Text(
                    'Ordered Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No item details available',
                        style: TextStyle(color: _kTextMid),
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestItemRow(item: item),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

List<dynamic> _requestItems(dynamic order) {
  try {
    final items = order.items;
    if (items is List) return items;
  } catch (_) {}
  try {
    final products = order.products;
    if (products is List) return products;
  } catch (_) {}
  return const [];
}

DateTime _orderCreatedAt(dynamic order) {
  try {
    final value = order.createdAt;
    if (value is DateTime) return value;
  } catch (_) {}
  return DateTime.now();
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year, $hour:$minute';
}

Widget _detailLine(String label, String value) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < 300;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _smallLabelStyle),
                  const SizedBox(height: 2),
                  Text(value, style: _smallValueStyle),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(label, style: _smallLabelStyle)),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: _smallValueStyle,
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _RequestItemRow extends StatelessWidget {
  const _RequestItemRow({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final name = _text(_value(item, 'name'), fallback: 'Item');
    final qty = (_value(item, 'quantity') as num?)?.toInt() ?? 1;
    final price =
        (_value(item, 'unitPrice') as num?)?.toDouble() ??
        (_value(item, 'price') as num?)?.toDouble() ??
        0.0;
    final imageUrl = _text(_value(item, 'imageUrl'));
    final total = qty * price;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              color: _kOrangeLight,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: _kOrange,
                      ),
                    )
                  : const Icon(Icons.shopping_bag_outlined, color: _kOrange),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $qty • ₹${price.toStringAsFixed(2)} each',
                  style: const TextStyle(color: _kTextMid, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _kOrange,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

dynamic _value(dynamic item, String key) {
  try {
    if (item is Map<String, dynamic>) return item[key];
    final dynamic result = (item as dynamic);
    switch (key) {
      case 'name':
        return result.name;
      case 'quantity':
        return result.quantity;
      case 'imageUrl':
        return result.imageUrl;
      case 'price':
        return result.price;
      case 'unitPrice':
        return result.unitPrice;
    }
  } catch (_) {}
  return null;
}

String _text(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _fullVendorAddress(dynamic order) {
  final primary = _text(order.vendorPickupAddress, fallback: '').isNotEmpty
      ? _text(order.vendorPickupAddress, fallback: '')
      : _text(order.vendorAddress, fallback: '');
  final address = _cleanAddressParts([
    primary,
    _text(order.vendorCity, fallback: ''),
    _text(order.vendorState, fallback: ''),
    _text(order.vendorPincode, fallback: ''),
  ]);
  return address.isEmpty ? '—' : address;
}

String _cleanAddressParts(List<String> values) {
  String key(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final cleaned = <String>[];
  final parts = values
      .expand((value) => value.split(','))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  for (final part in parts) {
    final partKey = key(part);
    final duplicate = cleaned.any((existing) {
      final existingKey = key(existing);
      return existingKey == partKey || existingKey.contains(partKey);
    });
    if (!duplicate) cleaned.add(part);
  }
  return cleaned.join(', ');
}

String _fullCustomerAddress(dynamic order) {
  final address = _cleanAddressParts([
    _text(order.customerLine1, fallback: ''),
    _text(order.customerArea, fallback: ''),
    _text(order.customerLandmark, fallback: ''),
    _text(order.customerCity, fallback: ''),
    _text(order.customerState, fallback: ''),
    _text(order.customerPincode, fallback: ''),
    _text(order.customerAddress, fallback: ''),
  ]);
  return address.isEmpty ? '—' : address;
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final DeliveryOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border(left: BorderSide(color: _kOrange, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kOrangeLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ACTIVE ORDER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: _kOrange,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kOrangeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: _kOrange,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Deliver to customer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kTextMid,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Store: ${_text(order.vendorStoreName, fallback: 'Store order')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kOrange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _text(order.customerName, fallback: 'Customer'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            _detailRow('Phone', _text(order.customerPhone, fallback: '—')),
            _detailRow('Address', _fullCustomerAddress(order)),
            _DeliveryAmountSummary(order: order, compact: true),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: _kOrangeLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open active order',
                    style: TextStyle(
                      color: _kOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: _kOrange, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryAmountSummary extends StatelessWidget {
  const _DeliveryAmountSummary({required this.order, this.compact = false});

  final DeliveryOrderModel order;
  final bool compact;

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final payment = order.isCod ? 'Cash on delivery' : 'Paid online';
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: compact ? 8 : 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _detailRow('Items subtotal', _money(order.itemSubtotal)),
          _detailRow('Delivery fee', _money(order.deliveryFee)),
          if (order.gstAmount > 0) _detailRow('GST', _money(order.gstAmount)),
          _detailRow(
            'Customer total',
            _money(order.totalAmount),
            valueColor: _kOrange,
          ),
          _detailRow('Payment', payment),
          if (order.isCod)
            _detailRow(
              'Collect from customer',
              _money(order.codAmount ?? order.totalAmount),
              valueColor: _kOrange,
            ),
        ],
      ),
    );
  }
}

Widget _detailRow(String label, String value, {Color valueColor = _kTextDark}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < 280;
      final valueStyle = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: valueColor,
      );
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _amountLabelStyle),
                  const SizedBox(height: 2),
                  Text(value, style: valueStyle),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(label, style: _amountLabelStyle)),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      softWrap: true,
                      style: valueStyle,
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

const _smallLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: _kTextMid,
);

const _smallValueStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w800,
  color: _kTextDark,
);

const _amountLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: _kTextMid,
);

// ─── Initial Payment Required Card ──────────────────────────────────────────

class _InitialPaymentRequiredCard extends StatelessWidget {
  const _InitialPaymentRequiredCard({
    required this.amount,
    required this.onPayTap,
    required this.onVerifyTap,
    this.isChecking = false,
  });

  final double amount;
  final VoidCallback onPayTap;
  final VoidCallback onVerifyTap;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final displayAmount = amount > 0 ? amount.toStringAsFixed(0) : '500';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD8CC)),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _kOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: _kOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Initial Payment Required',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pay ₹$displayAmount onboarding fee to unlock orders',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'UNPAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Order requests and online dispatch are locked until the initial partner fee is verified.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: _kTextDark.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPayTap,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(
                'Complete Payment (₹$displayAmount)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: isChecking ? null : onVerifyTap,
              icon: isChecking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kOrange,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: _kOrange,
                    ),
              label: Text(
                isChecking
                    ? 'Checking verification...'
                    : 'Already paid? Check verification status',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Initial Payment Paid Card ──────────────────────────────────────────────

class _InitialPaymentPaidCard extends StatelessWidget {
  const _InitialPaymentPaidCard({
    required this.amount,
    this.completedAt,
    required this.onViewTap,
  });

  final double amount;
  final DateTime? completedAt;
  final VoidCallback onViewTap;

  @override
  Widget build(BuildContext context) {
    final displayAmount = amount > 0 ? amount.toStringAsFixed(0) : '500';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1FAE5)),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _kGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'Initial Payment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PAID',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _kGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₹$displayAmount • Eligible to work',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewTap,
            style: TextButton.styleFrom(
              foregroundColor: _kOrange,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Details',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delivery Sidebar ─────────────────────────────────────────────────────────

class _DeliverySidebarDrawer extends StatelessWidget {
  const _DeliverySidebarDrawer({required this.currentRoute});

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
      Navigator.of(context).pushNamed(route);
    } else if (route == DeliveryEarningsScreen.routeName) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DeliveryEarningsScreen()));
    } else if (route == DeliveryProfileScreen.routeName) {
      Navigator.of(context).pushNamed(route);
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

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFFDDDDDD)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextMid, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Spring Button ────────────────────────────────────────────────────────────

class _SpringButton extends StatefulWidget {
  const _SpringButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<_SpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 0.93,
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
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(scale: _s, child: widget.child),
    );
  }
}
