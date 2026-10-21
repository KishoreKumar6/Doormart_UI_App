import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../user/user_home_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  static const routeName = '/order-success';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            final confirmedOrders = state.lastCheckoutOrders.isNotEmpty
                ? state.lastCheckoutOrders
                : (state.orders.isEmpty
                      ? const <OrderModel>[]
                      : [state.orders.first]);
            final latest = confirmedOrders.isEmpty
                ? null
                : confirmedOrders.first;
            final totalItems = confirmedOrders.fold<int>(
              0,
              (sum, order) => sum + _quantity(order),
            );
            final subtotal = confirmedOrders.fold<double>(
              0,
              (sum, order) => sum + _subtotal(order),
            );
            final deliveryFee = confirmedOrders.fold<double>(
              0,
              (sum, order) => sum + order.deliveryFee,
            );
            final gst = confirmedOrders.fold<double>(
              0,
              (sum, order) => sum + order.gstAmount,
            );
            final grandTotal = confirmedOrders.fold<double>(
              0,
              (sum, order) => sum + order.total,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CelebrationHero(
                    imageUrl: latest != null && latest.products.isNotEmpty
                        ? latest.products.first.imageUrl
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Order Confirmed',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your order is on the way',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 22),

                  if (confirmedOrders.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Items ordered',
                      icon: Icons.shopping_bag_outlined,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < confirmedOrders.length;
                            index++
                          ) ...[
                            _OrderDetailsCard(order: confirmedOrders[index]),
                            if (index != confirmedOrders.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Order Summary section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _SectionCard(
                    title: 'Order details',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Items', value: '$totalItems'),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label:
                              'Order ID${confirmedOrders.length > 1 ? 's' : ''}',
                          value: confirmedOrders.isEmpty
                              ? '—'
                              : confirmedOrders
                                    .map((order) => order.displayOrderId)
                                    .join(', '),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Payment',
                          value: latest?.paymentMethod == 'cod'
                              ? 'Cash on delivery'
                              : 'Paid online',
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Delivering to',
                          value: latest?.address ?? '—',
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Estimated delivery',
                          value: _estimatedDelivery(),
                        ),
                        if (confirmedOrders.isNotEmpty) ...[
                          const Divider(height: 28),
                          _PriceRow(label: 'Subtotal', value: subtotal),
                          const SizedBox(height: 8),
                          _PriceRow(label: 'Delivery fee', value: deliveryFee),
                          const SizedBox(height: 8),
                          _PriceRow(label: 'GST', value: gst),
                          const Divider(height: 28),
                          _PriceRow(
                            label: 'Total paid / payable',
                            value: grandTotal,
                            emphasize: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Return to Home button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        UserHomeScreen.routeName,
                        (route) => false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8541A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: const Color(0xFFE8541A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Return to Home',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Confirmation note
                  const Text(
                    'Your order has been confirmed successfully',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2EAA5A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _estimatedDelivery() {
    final delivery = DateTime.now().add(const Duration(hours: 1));
    final hour24 = delivery.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = delivery.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return 'Today, ${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  static int _quantity(OrderModel order) =>
      order.quantities.fold<int>(0, (sum, value) => sum + value);

  static double _subtotal(OrderModel order) {
    var total = 0.0;
    for (var index = 0; index < order.products.length; index++) {
      final quantity = index < order.quantities.length
          ? order.quantities[index]
          : 1;
      total += order.products[index].price * quantity;
    }
    return total;
  }
}

class _CelebrationHero extends StatefulWidget {
  const _CelebrationHero({this.imageUrl});

  final String? imageUrl;

  @override
  State<_CelebrationHero> createState() => _CelebrationHeroState();
}

class _CelebrationHeroState extends State<_CelebrationHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 20,
            child: Container(
              width: 220,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9DF),
                borderRadius: BorderRadius.circular(54),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8541A).withValues(alpha: 0.12),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _motionController,
            builder: (context, child) {
              final value = _motionController.value;
              final lift = -8 * Curves.easeInOut.transform(value);
              final tilt = (value - 0.5) * 0.035;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateZ(tilt)
                  ..translateByDouble(0.0, lift, 0.0, 1.0),
                child: child,
              );
            },
            child: Container(
              width: 204,
              height: 164,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: const Color(0xFFFFC7B0), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _DeliveryScene(
                animation: _motionController,
                imageUrl: widget.imageUrl,
              ),
            ),
          ),
          Positioned(
            left: 36,
            bottom: 22,
            child: _FloatingBadge(
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFFE8541A),
              delay: 0.15,
            ),
          ),
          Positioned(
            right: 34,
            top: 28,
            child: _FloatingBadge(
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF16A34A),
              delay: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryScene extends StatelessWidget {
  const _DeliveryScene({required this.animation, this.imageUrl});

  final Animation<double> animation;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(animation.value);
        final scooterOffset = -12 + (progress * 24);
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF8F4), Color(0xFFFFE5D8)],
                ),
              ),
            ),
            Positioned(
              left: 26,
              right: 26,
              bottom: 54,
              child: Row(
                children: List.generate(
                  7,
                  (index) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? const Color(0xFFFFB18F)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 30 + scooterOffset,
              bottom: 65,
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 68,
                color: Color(0xFFE8541A),
              ),
            ),
            Positioned(
              top: 25 + (progress * 5),
              left: 46,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  width: 44,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ),
            if (imageUrl != null)
              Positioned(
                right: 26,
                top: 27,
                child: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _OrderImage(imageUrl: imageUrl!),
                  ),
                ),
              ),
            const Positioned(
              right: 14,
              bottom: 12,
              child: CircleAvatar(
                radius: 21,
                backgroundColor: Color(0xFFE8541A),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 27),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.color,
    required this.delay,
  });

  final IconData icon;
  final Color color;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: delay == 0.15 ? -0.12 : 0.12,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E5E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFE8541A), size: 21),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final storeName = order.vendorStoreName.trim().isNotEmpty
        ? order.vendorStoreName.trim()
        : (order.vendorId == 'main' ? 'DoorMart Store' : 'Store order');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: Color(0xFFE8541A),
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                order.displayOrderId,
                style: const TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < order.products.length; index++) ...[
            _OrderItemRow(
              product: order.products[index],
              quantity: index < order.quantities.length
                  ? order.quantities[index]
                  : 1,
            ),
            if (index != order.products.length - 1) const Divider(height: 18),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Store order total',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Rs ${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFE8541A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.product, required this.quantity});

  final ProductModel product;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: _OrderThumb(imageUrl: product.imageUrl),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Qty $quantity × Rs ${product.price.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Rs ${(product.price * quantity).toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasize
                ? const Color(0xFF1A1A1A)
                : const Color(0xFF777777),
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 16 : 14,
          ),
        ),
        Text(
          'Rs ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: emphasize
                ? const Color(0xFFE8541A)
                : const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w900,
            fontSize: emphasize ? 19 : 14,
          ),
        ),
      ],
    );
  }
}

class _OrderImage extends StatelessWidget {
  const _OrderImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalized = NetworkImageUrl.normalize(imageUrl);
    if (normalized.startsWith('http')) {
      return Image.network(
        normalized,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.delivery_dining,
          size: 72,
          color: Color(0xFFE8541A),
        ),
      );
    }
    if (normalized.startsWith('assets/')) {
      return Image.asset(
        normalized,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.delivery_dining,
          size: 72,
          color: Color(0xFFE8541A),
        ),
      );
    }
    return const Icon(
      Icons.delivery_dining,
      size: 72,
      color: Color(0xFFE8541A),
    );
  }
}

class _OrderThumb extends StatelessWidget {
  const _OrderThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalized = NetworkImageUrl.normalize(imageUrl);
    if (normalized.startsWith('http')) {
      return Image.network(
        normalized,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
      );
    }
    if (normalized.startsWith('assets/')) {
      return Image.asset(normalized, fit: BoxFit.cover, width: 48, height: 48);
    }
    return const ColoredBox(
      color: Color(0xFFF1F1F1),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF999999),
          size: 18,
        ),
      ),
    );
  }
}
