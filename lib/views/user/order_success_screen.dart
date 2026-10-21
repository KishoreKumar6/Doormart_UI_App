import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../models/order_model.dart';
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
            final latest = state.orders.isEmpty ? null : state.orders.first;
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

                  // Product card
                  if (latest != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                            ),
                            child: latest.products.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _OrderThumb(
                                      imageUrl: latest.products.first.imageUrl,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Color(0xFF999999),
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latest.products.isNotEmpty
                                      ? latest.products.first.name
                                      : 'Your Order',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  latest.products.isNotEmpty
                                      ? latest.products.first.category
                                      : '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Rs ${latest.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
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

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Quantity',
                          value: _quantityLabel(latest),
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          label: 'Order ID',
                          value: latest?.displayOrderId ?? '—',
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          label: 'Shipping Address',
                          value: latest?.address ?? '—',
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          label: 'Estimated Delivery Date',
                          value: _estimatedDelivery(),
                        ),
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

  String _quantityLabel(OrderModel? order) {
    if (order == null || order.quantities.isEmpty) return '—';
    final total = order.quantities.fold<int>(0, (sum, value) => sum + value);
    return total == 1 ? '1 item' : '$total items';
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
                border: Border.all(
                  color: const Color(0xFFFFC7B0),
                  width: 2,
                ),
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
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 27,
                ),
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
        errorBuilder: (_, __, ___) => const Icon(
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
        errorBuilder: (_, __, ___) => const Icon(
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
