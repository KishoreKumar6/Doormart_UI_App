import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/app_state.dart';
import '../app_page.dart';

class DeliveryStatusScreen extends StatefulWidget {
  const DeliveryStatusScreen({super.key});

  static const routeName = '/delivery/status';

  @override
  State<DeliveryStatusScreen> createState() => _DeliveryStatusScreenState();
}

class _DeliveryStatusScreenState extends State<DeliveryStatusScreen> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<OrderModel>> _loadOrders() async {
    final state = context.read<AppState>();
    final openOrders = await state.availableDeliveryOrders();
    final historyOrders = await state.deliveryOrderHistory();
    final byId = <String, OrderModel>{};
    for (final order in [...openOrders, ...historyOrders]) {
      byId[order.id] = order;
    }
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Delivery Status',
      actions: [
        IconButton(
          tooltip: 'Refresh status',
          onPressed: () => setState(() => _ordersFuture = _loadOrders()),
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StatusError(message: snapshot.error.toString());
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();

            final orders = snapshot.data!;
            if (orders.isEmpty) return const _NoStatusOrders();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusHeader(count: orders.length),
                const SizedBox(height: 12),
                ...orders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StatusCard(order: order),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF12372A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timeline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count assigned or active orders',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${_shortId(order.id)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.products.length} items | Rs ${order.total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _ProgressLine(status: order.status),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    const steps = [
      OrderStatus.assigned,
      OrderStatus.deliveryAccepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
    ];
    final activeIndex = status == OrderStatus.cancelled
        ? -1
        : steps.indexOf(status);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final active = activeIndex >= 0 && index <= activeIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: status == OrderStatus.cancelled
                    ? const Color(0xFFFFCBD5)
                    : active
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SizedBox(height: 8),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      OrderStatus.assigned => 'ASSIGNED',
      OrderStatus.deliveryAccepted => 'ACCEPTED',
      OrderStatus.pickedUp => 'PICKED UP',
      OrderStatus.delivered => 'DELIVERED',
      OrderStatus.cancelled => 'CANCELLED',
      _ => 'ACTIVE',
    };
    final color = status == OrderStatus.cancelled
        ? const Color(0xFFBE123C)
        : status == OrderStatus.delivered
        ? const Color(0xFF0F766E)
        : const Color(0xFF1D4ED8);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _NoStatusOrders extends StatelessWidget {
  const _NoStatusOrders();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.timeline),
      title: Text('No assigned orders'),
      subtitle: Text('Assigned and accepted orders will appear here.'),
    );
  }
}

class _StatusError extends StatelessWidget {
  const _StatusError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFBE123C),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(id.length - 8).toUpperCase();
}
