import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_state.dart';
import '../../../models/user_model.dart';
import '../providers/delivery_provider.dart';
import 'active_order_screen.dart';
import 'delivery_history_screen.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_profile_screen.dart';

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
  bool _locationEnabled = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DeliveryProvider>();
      await provider.bootstrap();
      if (provider.deliveryPerson == null &&
          provider.authToken != null &&
          provider.authUser != null) {
        provider.hydrateFromSession(
          token: provider.authToken!,
          user: UserModel.fromJson(provider.authUser!),
        );
      }
      await provider.syncOnlineState();
      await provider.loadDashboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshLocationStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _locationEnabled = enabled);
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await _refreshLocationStatus();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final appState = context.watch<AppState>();
    final provider = context.watch<DeliveryProvider>();
    final person = provider.deliveryPerson;
    final approvalStatus = (appState.user?.approvalStatus ?? 'approved')
        .toLowerCase();
    final canSeeRequests = person?.active ?? false;
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
          if (!_locationEnabled) ...[
            _LocationDisabledBanner(onTurnOn: _openLocationSettings),
            const SizedBox(height: 16),
          ],
          // ── Profile card ─────────────────────────────────────────────
          _ProfileCard(
            name: person?.name ?? 'Delivery Partner',
            deliveryId: _shortId(person?.id),
            imageUrl: person?.avatarUrl ?? '',
            online: provider.online,
            onToggle: (v) {
              HapticFeedback.lightImpact();
              if (v && !_locationEnabled) {
                _openLocationSettings();
                return;
              }
              v ? provider.goOnline() : provider.goOffline();
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

          // ── New Requests ──────────────────────────────────────────────
          if (canSeeRequests) ...[
            Row(
              children: [
                const Text(
                  'New Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(width: 10),
                if (provider.pendingRequests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _kOrangeLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${provider.pendingRequests.length} Nearby',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kOrange,
                      ),
                    ),
                  ),
                const Spacer(),
                // TextButton(
                //   onPressed: () {},
                //   style: TextButton.styleFrom(
                //     foregroundColor: _kOrange,
                //     padding: EdgeInsets.zero,
                //     minimumSize: Size.zero,
                //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                //   ),
                //   child: const Text(
                //     'View All',
                //     style: TextStyle(fontWeight: FontWeight.w700),
                //   ),
                // ),
              ],
            ),

            const SizedBox(height: 15),

            if (provider.online && provider.pendingRequests.isEmpty)
              _EmptyState(
                icon: Icons.inbox_rounded,
                message: 'No new requests right now',
              )
            else if (!provider.online)
              const _EmptyState(
                icon: Icons.wifi_off_rounded,
                message: 'Go online to receive requests',
              )
            else
              SizedBox(
                height: 520,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.pendingRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final order = provider.pendingRequests[i];
                    return SizedBox(
                      width: MediaQuery.of(context).size.width - 64,
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
          ] else ...[
            const _EmptyState(
              icon: Icons.lock_outline_rounded,
              message: 'Inactive delivery persons cannot receive requests',
            ),
          ],

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
  const _LocationDisabledBanner({required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
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
          const Icon(
            Icons.location_off_rounded,
            color: Color(0xFFEA580C),
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location is turned off',
                  style: TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Turn on your phone location to receive orders and share live delivery tracking.',
                  style: TextStyle(
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
            child: const Text(
              'Turn on',
              style: TextStyle(fontWeight: FontWeight.w900),
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
    required this.onToggle,
  });

  final String name;
  final String deliveryId;
  final String imageUrl;
  final bool online;
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

          // Duty status toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Duty Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        online ? 'ONLINE' : 'OFFLINE',
                        key: ValueKey(online),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: online ? _kOrange : _kTextMid,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch.adaptive(
                        value: online,
                        onChanged: onToggle,
                        activeColor: _kOrange,
                        activeTrackColor: _kOrange.withValues(alpha: 0.25),
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
          Text(
            value,
            style: TextStyle(
              fontSize: largeValue ? 24 : 28,
              fontWeight: FontWeight.w900,
              color: _kOrange,
              height: 1,
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

  final dynamic order;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<_NewRequestCard> createState() => _NewRequestCardState();
}

class _NewRequestCardState extends State<_NewRequestCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE1D6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: restaurant + timer ───────────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kOrangeLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _kOrange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(widget.order.customerName, fallback: 'Customer'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _text(widget.order.customerPhone, fallback: '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextMid,
                      ),
                    ),
                    Text(
                      '${_requestItems(widget.order).length} items • ${_text(widget.order.customerArea, fallback: 'Unknown area')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _kTextMid),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showItemsSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: _kOrange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View Items',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _detailLine('Placed', _formatDate(_orderCreatedAt(widget.order))),
          _detailLine(
            'Phone',
            _text(widget.order.customerPhone, fallback: '—'),
          ),
          _detailLine(
            'Address',
            _text(widget.order.customerAddress, fallback: '—'),
          ),
          _detailLine(
            'Order Amount',
            '₹${_amount(widget.order).toStringAsFixed(2)}',
          ),
          _detailLine(
            'Payment',
            _text(widget.order.paymentType, fallback: 'Online'),
          ),

          // ── Pickup ────────────────────────────────────────────────────
          const SizedBox(height: 14),

          // ── Primary action ────────────────────────────────────────────
          _SpringButton(
            onTap: widget.onAccept,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A1A), Color(0xFFE9471C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Accept delivery request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                  _detailLine(
                    'Amount',
                    '₹${_amount(widget.order).toStringAsFixed(2)}',
                  ),
                  _detailLine(
                    'Payment',
                    _text(widget.order.paymentType, fallback: 'Online'),
                  ),
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
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kTextMid,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
            ),
          ),
        ),
      ],
    ),
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

double _amount(dynamic order) {
  try {
    final value = order.totalAmount;
    if (value is num) return value.toDouble();
  } catch (_) {}
  try {
    final value = order.earnings;
    if (value is num) return value.toDouble();
  } catch (_) {}
  return 0;
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.line1,
    required this.line2,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                TextSpan(
                  text: line1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kTextDark,
                  ),
                ),
                if (line2.isNotEmpty)
                  TextSpan(
                    text: '\n$line2',
                    style: const TextStyle(fontSize: 12, color: _kTextMid),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Active Order Card ────────────────────────────────────────────────────────

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final dynamic order;

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
            _detailRow('Payment', _text(order.paymentType, fallback: '—')),
            _detailRow(
              'Order total',
              '₹${_amount(order).toStringAsFixed(2)}',
              valueColor: _kOrange,
            ),
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

Widget _detailRow(String label, String value, {Color valueColor = _kTextDark}) {
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kTextMid,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActiveOrderStat extends StatelessWidget {
  const _ActiveOrderStat({
    required this.label,
    required this.value,
    this.valueColor = _kTextDark,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kTextMid,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─── Map Grid Painter ─────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
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
                          provider.online ? 'ONLINE' : 'OFFLINE',
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
    }
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
