import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/order_model.dart';
import '../../providers/app_state.dart';
import '../app_page.dart';

class AdminAssignDeliveryScreen extends StatefulWidget {
  const AdminAssignDeliveryScreen({super.key});

  static const routeName = '/admin/assign-delivery';

  @override
  State<AdminAssignDeliveryScreen> createState() =>
      _AdminAssignDeliveryScreenState();
}

class _AdminAssignDeliveryScreenState extends State<AdminAssignDeliveryScreen> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<OrderModel>> _loadOrders() async {
    final orders = await context.read<AppState>().allOrdersForRole(
      UserRoles.admin,
    );
    return orders.where((order) {
      return order.status == OrderStatus.assigned ||
          order.status == OrderStatus.deliveryAccepted ||
          order.status == OrderStatus.pickedUp ||
          order.status == OrderStatus.delivered ||
          order.status == OrderStatus.cancelled ||
          order.deliveryPersonId != null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Assign Delivery',
      actions: [
        IconButton(
          tooltip: 'Refresh assignments',
          onPressed: () => setState(() => _ordersFuture = _loadOrders()),
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AssignmentError(message: snapshot.error.toString());
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();

            final orders = snapshot.data!;
            if (orders.isEmpty) return const _NoAssignments();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AssignmentHeader(count: orders.length),
                const SizedBox(height: 12),
                ...orders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AssignmentCard(order: order),
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

class _AssignmentHeader extends StatelessWidget {
  const _AssignmentHeader({required this.count});

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
            const Icon(Icons.assignment_ind, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count delivery assignments',
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

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final waiting = order.status == OrderStatus.assigned;
    final cancelled = order.status == OrderStatus.cancelled;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: cancelled
                    ? const Color(0xFFFFF1F2)
                    : waiting
                    ? const Color(0xFFFDF2F8)
                    : const Color(0xFFEAF7EF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  cancelled
                      ? Icons.cancel
                      : waiting
                      ? Icons.hourglass_top
                      : Icons.local_shipping,
                  color: cancelled
                      ? const Color(0xFFBE123C)
                      : waiting
                      ? const Color(0xFFBE185D)
                      : const Color(0xFF0F766E),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.displayOrderId}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.products.length} items | Rs ${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    waiting
                        ? 'Waiting for delivery person'
                        : cancelled
                        ? 'Order cancelled'
                        : 'Handled by ${order.deliveryPersonName ?? 'delivery person'}',
                    style: TextStyle(
                      color: cancelled
                          ? const Color(0xFFBE123C)
                          : waiting
                          ? const Color(0xFFBE185D)
                          : const Color(0xFF0F766E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(status: order.status),
          ],
        ),
      ),
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

class _NoAssignments extends StatelessWidget {
  const _NoAssignments();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.assignment_outlined),
      title: Text('No assigned orders'),
      subtitle: Text('Orders moved to assigned will appear here.'),
    );
  }
}

class _AssignmentError extends StatelessWidget {
  const _AssignmentError({required this.message});

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
