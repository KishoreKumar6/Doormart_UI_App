import 'package:flutter/material.dart';

import '../models/delivery_order_model.dart';

class NewOrderRequestCard extends StatefulWidget {
  const NewOrderRequestCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  final DeliveryOrderModel order;
  final Future<String?> Function() onAccept;
  final Future<String?> Function() onReject;

  @override
  State<NewOrderRequestCard> createState() => _NewOrderRequestCardState();
}

class _NewOrderRequestCardState extends State<NewOrderRequestCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final accepted =
        widget.order.status == DeliveryOrderStatus.accepted ||
        widget.order.status == DeliveryOrderStatus.pickedUp ||
        widget.order.status == DeliveryOrderStatus.outForDelivery ||
        widget.order.status == DeliveryOrderStatus.delivered;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${widget.order.displayOrderId}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: accepted ? 'Accepted' : 'Waiting',
                  color: accepted
                      ? const Color(0xFF0F9D58)
                      : const Color(0xFFE8541A),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Customer Name: ${widget.order.customerName}'),
            Text('Area: ${widget.order.customerArea}'),
            Text('Placed: ${_formatDate(widget.order.createdAt)}'),
            Text('Phone: ${widget.order.customerPhone}'),
            Text('Address: ${widget.order.customerAddress}'),
            Text('${widget.order.itemCount} items'),
            const SizedBox(height: 10),
            Text(
              'Ordered Items',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...widget.order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderedItemRow(item: item),
              ),
            ),
            const SizedBox(height: 4),
            _SummaryLine(
              label: 'Items subtotal',
              value: '₹${widget.order.itemSubtotal.toStringAsFixed(2)}',
            ),
            _SummaryLine(
              label: 'Delivery fee',
              value: '₹${widget.order.deliveryFee.toStringAsFixed(2)}',
            ),
            if (widget.order.gstAmount > 0)
              _SummaryLine(
                label: 'GST',
                value: '₹${widget.order.gstAmount.toStringAsFixed(2)}',
              ),
            _SummaryLine(
              label: 'Customer total',
              value: '₹${widget.order.totalAmount.toStringAsFixed(2)}',
            ),
            _SummaryLine(
              label: 'Payment',
              value: widget.order.isCod ? 'Cash on delivery' : 'Paid online',
            ),
            if (widget.order.isCod)
              _SummaryLine(
                label: 'Collect from customer',
                value:
                    '₹${widget.order.codAmount?.toStringAsFixed(2) ?? widget.order.totalAmount.toStringAsFixed(2)}',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _accept,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    final message = await widget.onAccept();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    final message = await widget.onReject();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year, $hour:$minute $period';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _OrderedItemRow extends StatelessWidget {
  const _OrderedItemRow({required this.item});

  final DeliveryOrderItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
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
              width: 52,
              height: 52,
              color: const Color(0xFFFFF0EB),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
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
                  'Qty: ${item.quantity} • ₹${item.unitPrice.toStringAsFixed(2)} each',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${item.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFFE8541A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 280;
        const labelStyle = TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
        );
        const valueStyle = TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w900,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle),
                    const SizedBox(height: 2),
                    Text(value, style: valueStyle),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: Text(label, style: labelStyle)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: valueStyle,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
