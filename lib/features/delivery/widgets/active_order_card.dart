import 'package:flutter/material.dart';

import '../models/delivery_order_model.dart';

class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({super.key, required this.order});

  final DeliveryOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ${order.displayOrderId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Customer name: ${order.customerName}'),
            Text('Customer phone: ${order.customerPhone}'),
            Text('Customer address: ${order.customerAddress}'),
            Text('Customer area: ${order.customerArea}'),
            Text('Items: ${order.itemCount}'),
            Text('Payment: ${order.paymentType}'),
            Text('Total: ₹${order.totalAmount.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}
