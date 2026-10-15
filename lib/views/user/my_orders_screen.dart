import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../providers/app_state.dart';
import '../../widgets/toast_widget.dart';
import '../app_page.dart';
import 'cart_screen.dart';
import 'live_order_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  static const routeName = '/my-orders';

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted) return;
        context.read<AppState>().loadOrders();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'My Orders',
      bottomNavIndex: 1,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: GestureDetector(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
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
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
      children: [
        Consumer<AppState>(
          builder: (context, state, _) {
            final orders = state.orders;
            if (state.loading && orders.isEmpty) {
              return const LinearProgressIndicator();
            }
            if (orders.isEmpty) return const Text('No orders yet');

            final currentOrders = _currentOrdersFrom(orders);
            final previousOrders = orders
                .where((order) => order.status == OrderStatus.delivered)
                .toList();
            final totalOrders = orders.length;
            final activeOrders = orders
                .where((order) => _isActive(order.status))
                .length;
            final deliveredOrders = orders
                .where((order) => order.status == OrderStatus.delivered)
                .length;
            final totalSpent = orders
                .where((order) => order.status == OrderStatus.delivered)
                .fold<double>(0, (sum, order) => sum + order.total);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryPanel(
                  totalOrders: totalOrders,
                  activeOrders: activeOrders,
                  deliveredOrders: deliveredOrders,
                  totalSpent: totalSpent,
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(currentOrders.length),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Current Orders',
                        count: currentOrders.length,
                      ),
                      const SizedBox(height: 12),
                      if (currentOrders.isEmpty)
                        const Text('No active orders right now')
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final columns = width >= 1100
                                ? 2
                                : width >= 700
                                ? 2
                                : 1;
                            final cardWidth = columns == 1
                                ? width
                                : (width - 14) / 2;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: currentOrders
                                  .map(
                                    (order) => SizedBox(
                                      width: cardWidth,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        child: _CurrentOrderCard(
                                          key: ValueKey(
                                            'current-${order.id}-${order.status.name}',
                                          ),
                                          order: order,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _SectionHeader(
                  title: 'Previous Orders',
                  count: previousOrders.length,
                ),
                const SizedBox(height: 12),
                if (previousOrders.isEmpty)
                  const Text('No previous orders yet')
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 1100
                          ? 2
                          : width >= 700
                          ? 2
                          : 1;
                      final cardWidth = columns == 1 ? width : (width - 14) / 2;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: previousOrders
                            .map(
                              (order) => SizedBox(
                                width: cardWidth,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: _PreviousOrderCard(
                                    key: ValueKey(
                                      'previous-${order.id}-${order.status.name}',
                                    ),
                                    order: order,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

bool _isActive(OrderStatus status) {
  return status == OrderStatus.accepted ||
      status == OrderStatus.packed ||
      status == OrderStatus.assigned ||
      status == OrderStatus.deliveryAccepted ||
      status == OrderStatus.pickedUp ||
      status == OrderStatus.outForDelivery;
}

bool _canTrackDelivery(OrderModel order) {
  return order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled;
}

String _statusLabel(OrderStatus status) {
  return switch (status) {
    OrderStatus.placed => 'PLACED',
    OrderStatus.accepted => 'ACCEPTED',
    OrderStatus.packed => 'PACKED',
    OrderStatus.assigned => 'ASSIGNED',
    OrderStatus.deliveryAccepted => 'DELIVERY ACCEPTED',
    OrderStatus.pickedUp => 'PICKED UP',
    OrderStatus.outForDelivery => 'OUT FOR DELIVERY',
    OrderStatus.delivered => 'DELIVERED',
    OrderStatus.cancelled => 'CANCELLED',
  };
}

List<OrderModel> _currentOrdersFrom(List<OrderModel> orders) {
  return orders
      .where(
        (order) =>
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.cancelled,
      )
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

class _CurrentOrderCard extends StatelessWidget {
  const _CurrentOrderCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(order.status);
    final timeline = _timelineFor(order.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F1F1)),
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
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ORDER #${order.displayOrderId}',
                    style: const TextStyle(
                      color: Color(0xFFE8541A),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                _StatusPill(label: status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _formatDate(order.createdAt),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _info('Address', order.address.isEmpty ? '—' : order.address),
            if (order.deliveryPersonName != null)
              _info('Delivery partner', order.deliveryPersonName!),
            _info('Total', '₹${order.total.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD5C4)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Delivery OTP',
                    style: TextStyle(
                      color: Color(0xFFE8541A),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.deliveryOtpDisplay,
                    style: const TextStyle(
                      color: Color(0xFFE8541A),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Status Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            _StatusTimeline(steps: timeline),
            const SizedBox(height: 14),
            const Text(
              'Ordered Items',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            if (order.products.isEmpty)
              const Text(
                'No item details available',
                style: TextStyle(color: Color(0xFF6B7280)),
              )
            else
              Column(
                children: order.products
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ItemRow(item: item),
                      ),
                    )
                    .toList(),
              ),
            if (_canTrackDelivery(order)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    LiveOrderTrackingScreen.routeName,
                    arguments: order,
                  ),
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text('Track delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8541A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year, ${hour12.toString().padLeft(2, '0')}:$minute $period';
  }
}

class _PreviousOrderCard extends StatelessWidget {
  const _PreviousOrderCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final status = _statusLabel(order.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F1F1)),
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
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ORDER #${order.displayOrderId}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                _StatusPill(label: status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _formatDate(order.createdAt),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _info('Address', order.address.isEmpty ? '—' : order.address),
            if (order.deliveryPersonName != null)
              _info('Delivery partner', order.deliveryPersonName!),
            if ((order.deliveryOtp ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD5C4)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Delivery OTP',
                      style: TextStyle(
                        color: Color(0xFFE8541A),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      order.deliveryOtp!,
                      style: const TextStyle(
                        color: Color(0xFFE8541A),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            _info('Total', '₹${order.total.toStringAsFixed(2)}'),
            const SizedBox(height: 14),
            const Text(
              'Ordered Items',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            if (order.products.isEmpty)
              const Text(
                'No item details available',
                style: TextStyle(color: Color(0xFF6B7280)),
              )
            else
              Column(
                children: order.products.map((item) {
                  final reviewed = state.hasReviewedProduct(
                    orderId: order.id,
                    productId: item.id,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemRow(
                      item: item,
                      reviewed: reviewed,
                      onRateTap: reviewed
                          ? null
                          : () => _openProductReviewDialog(
                              context: context,
                              order: order,
                              product: item,
                            ),
                    ),
                  );
                }).toList(),
              ),
            if (order.products.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ReorderOrderButton(order: order),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year, ${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderOrderButton extends StatefulWidget {
  const _ReorderOrderButton({required this.order});

  final OrderModel order;

  @override
  State<_ReorderOrderButton> createState() => _ReorderOrderButtonState();
}

class _ReorderOrderButtonState extends State<_ReorderOrderButton> {
  bool _loading = false;

  Future<void> _reorder() async {
    if (_loading) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final result = await state.addOrderToCart(widget.order);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.hasAddedItems) {
      showToast(
        context,
        state.error ?? 'These items are currently unavailable',
      );
      return;
    }

    final message = result.skippedCount > 0
        ? '${result.addedCount} items added, ${result.skippedCount} unavailable'
        : '${result.addedCount} items added to cart';
    showToast(context, message);
    Navigator.pushNamed(context, CartScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6A2A), Color(0xFFE8541A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8541A).withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _reorder,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.replay_rounded),
          label: Text(_loading ? 'Adding items...' : 'Reorder this order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.78),
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.totalOrders,
    required this.activeOrders,
    required this.deliveredOrders,
    required this.totalSpent,
  });

  final int totalOrders;
  final int activeOrders;
  final int deliveredOrders;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8541A), Color(0xFFFF7A2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8541A).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All your recent order activity at a glance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(label: 'Total', value: '$totalOrders'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(label: 'Active', value: '$activeOrders'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'Delivered',
                  value: '$deliveredOrders',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryTile(
            label: 'Total Spent',
            value: '₹${totalSpent.toStringAsFixed(2)}',
            wide: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.steps});

  final List<_TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: step.done
                        ? const Color(0xFFE8541A)
                        : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 34,
                    color: step.done
                        ? const Color(0xFFE8541A)
                        : const Color(0xFFE5E7EB),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              color: step.done
                                  ? const Color(0xFFE8541A)
                                  : const Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (step.isLive) const _LiveBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFFE8541A),
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.done,
    this.isLive = false,
  });
  final String title;
  final String subtitle;
  final bool done;
  final bool isLive;
}

List<_TimelineStep> _timelineFor(OrderStatus status) {
  final placed = _TimelineStep(
    title: 'Order Placed',
    subtitle: 'Received by system',
    done: true,
  );
  final processing = _TimelineStep(
    title: 'Processing',
    subtitle: 'Order is being prepared',
    done:
        status == OrderStatus.accepted ||
        status == OrderStatus.packed ||
        status == OrderStatus.assigned ||
        status == OrderStatus.deliveryAccepted ||
        status == OrderStatus.pickedUp ||
        status == OrderStatus.outForDelivery ||
        status == OrderStatus.delivered,
    isLive: status != OrderStatus.delivered && status != OrderStatus.cancelled,
  );
  final inTransit = _TimelineStep(
    title: 'In Transit',
    subtitle: 'Delivery is on the way',
    done:
        status == OrderStatus.pickedUp ||
        status == OrderStatus.outForDelivery ||
        status == OrderStatus.deliveryAccepted ||
        status == OrderStatus.delivered,
  );
  final delivered = _TimelineStep(
    title: 'Delivered',
    subtitle: 'Order completed',
    done: status == OrderStatus.delivered,
  );
  return [placed, processing, inTransit, delivered];
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.95 + (_controller.value * 0.08);
        final opacity = 0.62 + (_controller.value * 0.38);
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8541A).withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8541A).withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, this.reviewed = false, this.onRateTap});

  final ProductModel item;
  final bool reviewed;
  final VoidCallback? onRateTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = NetworkImageUrl.normalize(item.imageUrl);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 54,
              height: 54,
              color: const Color(0xFFFFF0EB),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFFE8541A),
                      ),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                      color: Color(0xFFE8541A),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} • ${item.unit}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE8541A),
                ),
              ),
              const SizedBox(height: 6),
              reviewed
                  ? const _RatedChip()
                  : TextButton.icon(
                      onPressed: onRateTap,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        foregroundColor: const Color(0xFFE8541A),
                        backgroundColor: const Color(0xFFFFF0EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.star_rounded, size: 15),
                      label: const Text(
                        'Rate',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatedChip extends StatelessWidget {
  const _RatedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Rated',
        style: TextStyle(
          color: Color(0xFF15803D),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

Future<void> _openProductReviewDialog({
  required BuildContext context,
  required OrderModel order,
  required ProductModel product,
}) async {
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  double rating = 0;
  bool submitting = false;
  final commentCtrl = TextEditingController();
  ModalRoute<void>? dialogRoute;

  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      dialogRoute = ModalRoute.of(dialogContext);
      return StatefulBuilder(
        builder: (dialogContext, setModalState) {
          Future<void> submit() async {
            if (rating <= 0 || submitting) return;
            setModalState(() => submitting = true);
            try {
              await appState.submitProductReview(
                orderId: order.id,
                productId: product.id,
                rating: rating,
                comment: commentCtrl.text.trim(),
                // Rebuild the order screen only after the dialog is disposed.
                notify: false,
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, true);
            } catch (e) {
              if (!dialogContext.mounted) return;
              setModalState(() => submitting = false);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                ),
              );
            }
          }

          final feedbackLabel = _ratingFeedbackLabel(rating);

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Material(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFE8541A), Color(0xFFFF8A3D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rate your order',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        height: 1.15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ReviewInfoChip(
                                    icon: Icons.receipt_long_rounded,
                                    label: order.displayOrderId,
                                  ),
                                  _ReviewInfoChip(
                                    icon: Icons.shopping_bag_rounded,
                                    label: product.category,
                                  ),
                                  _ReviewInfoChip(
                                    icon: Icons.verified_rounded,
                                    label: 'Delivered order',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFE8EEF5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'How was the product?',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const Spacer(),
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          child: Text(
                                            feedbackLabel,
                                            key: ValueKey(feedbackLabel),
                                            style: TextStyle(
                                              color: rating > 0
                                                  ? const Color(0xFFE8541A)
                                                  : const Color(0xFF6B7280),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(5, (index) {
                                        final starValue = index + 1;
                                        final filled = rating >= starValue;
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              onTap: submitting
                                                  ? null
                                                  : () => setModalState(
                                                      () => rating = starValue
                                                          .toDouble(),
                                                    ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 150,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: filled
                                                      ? const Color(0xFFFFF0EB)
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: filled
                                                        ? const Color(
                                                            0xFFFFC7AF,
                                                          )
                                                        : const Color(
                                                            0xFFE5E7EB,
                                                          ),
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      filled
                                                          ? Icons.star_rounded
                                                          : Icons
                                                                .star_border_rounded,
                                                      color: filled
                                                          ? const Color(
                                                              0xFFE8541A,
                                                            )
                                                          : const Color(
                                                              0xFF9CA3AF,
                                                            ),
                                                      size: 28,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      starValue.toString(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: filled
                                                            ? const Color(
                                                                0xFFE8541A,
                                                              )
                                                            : const Color(
                                                                0xFF6B7280,
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      rating > 0
                                          ? _ratingPromptLabel(rating)
                                          : 'Tap a star to rate your experience',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: commentCtrl,
                                maxLines: 4,
                                enabled: !submitting,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  labelText: 'Write a comment',
                                  hintText:
                                      'Share what you liked or what could improve',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8541A),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: submitting
                                          ? null
                                          : () => Navigator.pop(dialogContext),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF374151,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFD1D5DB),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: submitting || rating <= 0
                                          ? null
                                          : submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE8541A,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFFF0B69E,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: submitting
                                            ? const SizedBox(
                                                key: ValueKey('loading'),
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Submit review',
                                                key: ValueKey('label'),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  // Wait until the dialog route is fully removed from the navigator before
  // rebuilding the app. Rebuilding the root MaterialApp while the dialog is
  // mid-teardown leaves stale inherited-widget dependents behind and trips
  // Flutter's '_dependents.isEmpty' assertion on the next frame.
  await dialogRoute?.completed;
  commentCtrl.dispose();

  if (submitted == true) {
    appState.notifyReviewSubmitted();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks for your rating')),
    );
  }
}

String _ratingFeedbackLabel(double rating) {
  if (rating >= 5) return 'Excellent';
  if (rating >= 4) return 'Very good';
  if (rating >= 3) return 'Good';
  if (rating >= 2) return 'Needs improvement';
  if (rating > 0) return 'Poor';
  return 'Select a rating';
}

String _ratingPromptLabel(double rating) {
  if (rating >= 5) return 'Excellent choice. Tell us what stood out.';
  if (rating >= 4) return 'Great. A short note helps other customers too.';
  if (rating >= 3) return 'Thanks. Share what could be better.';
  if (rating >= 2) return 'We appreciate the feedback. Tell us what failed.';
  return 'Please choose a rating to continue.';
}

class _ReviewInfoChip extends StatelessWidget {
  const _ReviewInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD5C0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE8541A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7C2D12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE8541A),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
