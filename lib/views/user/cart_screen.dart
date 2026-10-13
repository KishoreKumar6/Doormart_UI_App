import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../providers/app_state.dart';
import '../../widgets/toast_widget.dart';
import '../../widgets/product_price_breakdown.dart';
import 'checkout_screen.dart';
import 'search_screen.dart';
import 'user_home_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF6F6F6);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF9E9E9E);

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const routeName = '/cart';

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadNearbyVendorIds();
      state.loadCheckoutSettings();
    });
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            _CartAppBar(),

            // ── Item list ─────────────────────────────────────────────────
            Expanded(
              child: Consumer<AppState>(
                builder: (context, state, _) {
                  if (state.cart.isEmpty) {
                    return _EmptyCart();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount:
                        state.cart.length +
                        ((state.nearbyLocationUnavailable ||
                                state.hasUnavailableCartItems)
                            ? 1
                            : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final showNotice =
                          state.nearbyLocationUnavailable ||
                          state.hasUnavailableCartItems;
                      if (showNotice && index == 0) {
                        return _CartLocationNotice(
                          locationUnavailable: state.nearbyLocationUnavailable,
                          message: state.nearbyLocationMessage,
                        );
                      }
                      final line = state.cart[showNotice ? index - 1 : index];
                      final isUnavailable =
                          !state.nearbyVendorsLoading &&
                          !state.nearbyLocationUnavailable &&
                          !state.isProductNearUser(line.product);
                      return _CartItemCard(
                        key: ValueKey(line.key),
                        line: line,
                        isUnavailable: isUnavailable,
                        onIncrement: () {
                          if (isUnavailable) {
                            showToast(
                              context,
                              'This item is not available near your location',
                            );
                            return;
                          }
                          HapticFeedback.lightImpact();
                          unawaited(
                            state.addToCart(
                              line.product,
                              quantity: 1,
                              unit: line.selectedUnit,
                              price: line.price,
                              discountCost: line.discountCost,
                              stock: line.stock,
                            ),
                          );
                        },
                        onDecrement: () {
                          HapticFeedback.lightImpact();
                          unawaited(
                            state.decrement(
                              line.product,
                              unit: line.selectedUnit,
                            ),
                          );
                        },
                        onUnitChanged: (unit) {
                          if (isUnavailable) {
                            showToast(
                              context,
                              'This item is not available near your location',
                            );
                            return;
                          }
                          HapticFeedback.lightImpact();
                          unawaited(() async {
                            final ok = await state.changeCartUnit(
                              line.product,
                              fromUnit: line.selectedUnit,
                              toUnit: unit,
                            );
                            if (!ok && context.mounted) {
                              showToast(
                                context,
                                state.error ?? 'Unable to change unit',
                              );
                            }
                          }());
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Bottom summary + checkout ──────────────────────────────────
            Consumer<AppState>(
              builder: (context, state, _) => _BottomBar(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _CartAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    void goBack() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      navigator.pushReplacementNamed(UserHomeScreen.routeName);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: goBack,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kCard,
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
                color: _kTextDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Cart',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
                letterSpacing: -0.4,
              ),
            ),
          ),
          // Search
          _AppBarIcon(
            icon: Icons.search_rounded,
            onTap: () => Navigator.pushNamed(context, SearchScreen.routeName),
          ),
          const SizedBox(width: 10),
          // Cart badge
          Consumer<AppState>(
            builder: (context, state, _) => _AppBarIcon(
              icon: Icons.shopping_bag_outlined,
              badge: state.cart.isEmpty
                  ? null
                  : state.cart
                        .fold<int>(0, (sum, l) => sum + l.quantity)
                        .toString(),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({required this.icon, this.badge, required this.onTap});
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: _kTextDark),
          ),
          if (badge != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _kOrange,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartLocationNotice extends StatelessWidget {
  const _CartLocationNotice({
    required this.locationUnavailable,
    required this.message,
  });

  final bool locationUnavailable;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC7B0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: _kOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              locationUnavailable
                  ? (message.isNotEmpty
                        ? message
                        : 'Turn on location and allow permission to check item availability near you.')
                  : 'Some cart items are not available near your location.',
              style: const TextStyle(
                color: _kTextDark,
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

// ─── Cart Item Card ───────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    super.key,
    required this.line,
    required this.isUnavailable,
    required this.onIncrement,
    required this.onDecrement,
    required this.onUnitChanged,
  });

  final dynamic line; // your CartLine / CartItem type
  final bool isUnavailable;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnavailable ? 0.62 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Product image ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(22),
              ),
              child: SizedBox(
                width: 96,
                height: 124,
                child: _ProductImage(imageUrl: line.product.imageUrl ?? ''),
              ),
            ),

            const SizedBox(width: 10),

            // ── Details ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _kTextDark,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                line.product.category ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kTextMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _UnitSwitcher(line: line, onUnitChanged: onUnitChanged),
                      ],
                    ),
                    if (isUnavailable) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Not available near you',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: _kOrange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _descriptionText(
                        line.product.description,
                        name: line.product.name,
                        category: line.product.category ?? '',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextMid,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Price
                        Expanded(
                          child: ProductPriceBreakdown(
                            product: line.product,
                            basePrice: line.unitPrice,
                            compact: true,
                            showBreakdown: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Quantity pill ──────────────────────────────
                        _QuantityPill(
                          quantity: line.quantity,
                          onDecrement: onDecrement,
                          onIncrement: onIncrement,
                        ),
                        const SizedBox(width: 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD1BE)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _kOrange,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UnitSwitcher extends StatelessWidget {
  const _UnitSwitcher({required this.line, required this.onUnitChanged});

  final dynamic line;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final variants = <String, Map<String, dynamic>>{};
    for (final variant in line.product.unitVariants) {
      variants[variant.unit.toString()] = {
        'price': variant.price,
        'stock': variant.stock,
      };
    }
    if (variants.length <= 1) {
      return _UnitChip(label: _unitLabel(line.selectedUnit));
    }

    return PopupMenuButton<String>(
      tooltip: 'Change unit',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: onUnitChanged,
      itemBuilder: (context) {
        return variants.entries.map((entry) {
          final unit = entry.key;
          final price = (entry.value['price'] as num?)?.toDouble() ?? 0;
          final stock = (entry.value['stock'] as num?)?.toInt() ?? 0;
          final isSelected =
              unit.trim().toLowerCase() ==
              line.selectedUnit.trim().toLowerCase();
          return PopupMenuItem<String>(
            value: unit,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _unitLabel(unit),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Rs ${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _kTextMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  stock > 0 ? '$stock' : '0',
                  style: const TextStyle(color: _kTextMid, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: _UnitChip(label: '${_unitLabel(line.selectedUnit)}  ▾'),
    );
  }
}

// ─── Quantity Pill ────────────────────────────────────────────────────────────

class _QuantityPill extends StatelessWidget {
  const _QuantityPill({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: _kOrange,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus
          _PillBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                '$quantity',
                key: ValueKey(quantity),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // Plus
          _PillBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _PillBtn extends StatefulWidget {
  const _PillBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0,
    upperBound: 1,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.80,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.onTap();
      },
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(widget.icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ─── Product Image ────────────────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalized = NetworkImageUrl.normalize(imageUrl);
    if (normalized.startsWith('http')) {
      return Image.network(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      );
    }
    if (normalized.startsWith('assets/')) {
      return Image.asset(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      );
    }
    return const _ImageFallback();
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kOrangeLight,
      child: const Center(
        child: Icon(Icons.fastfood_rounded, color: _kOrange, size: 40),
      ),
    );
  }
}

// ─── Empty Cart ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kOrangeLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: _kOrange,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items to get started',
            style: TextStyle(color: _kTextMid),
          ),
        ],
      ),
    );
  }
}

String _unitLabel(String value) {
  final unit = value.trim();
  if (unit.isEmpty) return '1 item';
  if (RegExp(r'^\d').hasMatch(unit)) return unit;
  return '1 $unit';
}

String _descriptionText(
  String value, {
  required String name,
  required String category,
}) {
  final description = value.trim();
  if (description.isNotEmpty) return description;

  final seed =
      (name.codeUnits.fold<int>(0, (sum, unit) => sum + unit) +
              category.codeUnits.fold<int>(0, (sum, unit) => sum + unit))
          .abs();
  final fallbackDescriptions = [
    'Fresh pick for your daily needs',
    'Quality choice for every home',
    'Handpicked for quick everyday use',
    'Popular essential with trusted quality',
    'Perfect addition to your grocery basket',
    'Carefully selected for DoorMart customers',
  ];
  return fallbackDescriptions[seed % fallbackDescriptions.length];
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final totalQty = state.cart.fold<int>(0, (s, l) => s + l.quantity);
    final itemsTotal = state.subtotal + state.gstAmount;
    final canCheckout =
        state.cart.isNotEmpty &&
        !state.nearbyVendorsLoading &&
        !state.nearbyLocationUnavailable &&
        !state.hasUnavailableCartItems;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalQty Selected Food',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _kTextDark,
                    ),
                  ),
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _kTextDark,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Items Total (incl. GST)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _kTextMid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs ${itemsTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GST included · Delivery calculated at checkout',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _kTextMid,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (state.freeDeliveryEnabled && state.cart.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.isFreeDelivery
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isFreeDelivery
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFED7AA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isFreeDelivery
                        ? Icons.check_circle_rounded
                        : Icons.local_shipping_outlined,
                    size: 18,
                    color: state.isFreeDelivery
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.isFreeDelivery
                          ? 'FREE delivery unlocked!'
                          : 'Add Rs ${state.amountNeededForFreeDelivery.toStringAsFixed(0)} more to get FREE delivery',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: state.isFreeDelivery
                            ? const Color(0xFF15803D)
                            : const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Checkout button
          _CheckoutButton(
            enabled: canCheckout,
            onTap: () {
              if (state.cart.isEmpty) {
                showToast(context, 'Your cart is empty');
                return;
              }
              if (state.nearbyLocationUnavailable) {
                showToast(
                  context,
                  'Turn on location and allow permission to checkout nearby items',
                );
                return;
              }
              if (state.hasUnavailableCartItems) {
                showToast(context, 'Remove unavailable items before checkout');
                return;
              }
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(context, CheckoutScreen.routeName);
            },
          ),
        ],
      ),
    );
  }
}

class _CheckoutButton extends StatefulWidget {
  const _CheckoutButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<_CheckoutButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0,
    upperBound: 1,
  );
  late final Animation<double> _scale = Tween<double>(
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
      onTapDown: widget.enabled ? (_) => _c.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _c.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? const LinearGradient(
                    colors: [Color(0xFFF26522), Color(0xFFE8401A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: widget.enabled ? null : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(999),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              'Checkout',
              style: TextStyle(
                color: widget.enabled ? Colors.white : Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
