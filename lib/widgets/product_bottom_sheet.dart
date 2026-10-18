import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/network_image_url.dart';
import '../models/product_model.dart';
import '../providers/app_state.dart';
import '../widgets/toast_widget.dart';
import 'closed_store_overlay.dart';
import 'product_price_breakdown.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kGreen = Color(0xFF0F9D58);
const _kGreenLight = Color(0xFFEAF7EF);

Future<void> showProductBottomSheet(
  BuildContext context,
  ProductModel product, {
  Future<void> Function(int quantity, ProductUnitVariant variant)? onAddToCart,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) {
      return SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _ProductSheet(product: product, onAddToCart: onAddToCart),
          ),
        ),
      );
    },
  );
}

// ─── Main Sheet ───────────────────────────────────────────────────────────────

class _ProductSheet extends StatefulWidget {
  const _ProductSheet({required this.product, required this.onAddToCart});
  final ProductModel product;
  final Future<void> Function(int quantity, ProductUnitVariant variant)?
  onAddToCart;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet>
    with SingleTickerProviderStateMixin {
  int _quantity = 1;
  bool _adding = false;
  late int _selectedVariantIndex;
  late final Future<List<ProductReviewModel>> _reviewsFuture;

  // Sheet entry animation
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _selectedVariantIndex = 0;
    _reviewsFuture = Future.microtask(
      () => context.read<AppState>().loadProductReviews(widget.product.id),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _increment() {
    final selectedStock = _selectedVariant.stock > 0
        ? _selectedVariant.stock
        : widget.product.stock;
    if (selectedStock > 0 && _quantity >= selectedStock) return;
    HapticFeedback.selectionClick();
    setState(() => _quantity++);
  }

  void _decrement() {
    if (_quantity <= 1) return;
    HapticFeedback.selectionClick();
    setState(() => _quantity--);
  }

  ProductUnitVariant get _selectedVariant {
    final variants = widget.product.unitVariants;
    if (variants.isNotEmpty && _selectedVariantIndex < variants.length) {
      return variants[_selectedVariantIndex];
    }
    return ProductUnitVariant(
      unit: widget.product.unit,
      price: widget.product.price,
      discountCost: widget.product.mrp,
      stock: widget.product.stock,
    );
  }

  void _selectVariant(int index) {
    final variants = widget.product.unitVariants;
    if (index < 0 || index >= variants.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedVariantIndex = index;
      final stock = variants[index].stock;
      if (stock > 0 && _quantity > stock) {
        _quantity = stock;
      }
      if (_quantity <= 0) _quantity = 1;
    });
  }

  Future<void> _addToCart() async {
    HapticFeedback.mediumImpact();
    setState(() => _adding = true);
    await widget.onAddToCart?.call(_quantity, _selectedVariant);
    if (mounted) {
      setState(() => _adding = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final selectedVariant = _selectedVariant;
    final catColor = _categoryAccent(product.category);
    final vendorName = _vendorNameFor(product);
    final canPickVariant = product.unitVariants.length > 1;
    final selectedPrice = selectedVariant.price > 0
        ? selectedVariant.price
        : product.price;
    final selectedMrp = selectedVariant.discountCost > selectedPrice
        ? selectedVariant.discountCost
        : product.mrp > selectedPrice
        ? product.mrp
        : selectedPrice * 1.12;
    final selectedStock = selectedVariant.stock > 0
        ? selectedVariant.stock
        : product.stock;
    final stockText = selectedStock > 0
        ? '$selectedStock available'
        : 'Out of stock';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ImageHero(product: product, catColor: catColor),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [_CategoryPill(category: product.category)],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              size: 14,
                              color: Color(0xFF888888),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                vendorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.straighten_rounded,
                              size: 14,
                              color: Color(0xFF888888),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _unitLabel(selectedVariant.unit),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.inventory_2_rounded,
                              size: 14,
                              color: Color(0xFF888888),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              stockText,
                              style: TextStyle(
                                fontSize: 13,
                                color: selectedStock > 10
                                    ? _kGreen
                                    : const Color(0xFFE8541A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ProductPriceBreakdown(
                              product: product,
                              basePrice: selectedPrice,
                              showBreakdown: false,
                            ),
                            Text(
                              'Rs ${selectedMrp.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFFAAAAAA),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Color(0xFFAAAAAA),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kGreenLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '13% OFF',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _kGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (canPickVariant) ...[
                          const SizedBox(height: 14),
                          _VariantPicker(
                            variants: product.unitVariants,
                            selectedIndex: _selectedVariantIndex,
                            onSelected: _selectVariant,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _DeliveryStrip(),
                        const SizedBox(height: 14),
                        _VendorSourceCard(product: product),
                        const SizedBox(height: 14),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _descriptionFor(product),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF777777),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ProductReviewsSection(
                          product: product,
                          reviewsFuture: _reviewsFuture,
                        ),
                        const SizedBox(height: 20),
                        _QuantityCartBar(
                          quantity: _quantity,
                          adding: _adding,
                          onIncrement: _increment,
                          onDecrement: _decrement,
                          onAddToCart: _addToCart,
                          product: product,
                          selectedUnit: selectedVariant.unit,
                          selectedPrice: selectedPrice,
                          taxPercent: product.tax,
                          selectedStock: selectedStock,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Image Hero ───────────────────────────────────────────────────────────────

class _ImageHero extends StatelessWidget {
  const _ImageHero({required this.product, required this.catColor});
  final ProductModel product;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).width * 0.58).clamp(
      190.0,
      240.0,
    );

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catColor, catColor.withValues(alpha: 0.60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          // Product image
          _ProductBackground(product: product),

          if (product.vendorIsOpen == false)
            ClosedStoreOverlay(label: closedStoreLabelForProduct(product)),

          // Bottom fade
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Close button
          Positioned(top: 12, right: 12, child: _CloseButton()),

          // Wishlist button
          Positioned(
            top: 12,
            left: 12,
            child: _WishlistButton(product: product),
          ),

          // Fresh badge
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 13, color: _kOrange),
                  SizedBox(width: 3),
                  Text(
                    'Delivered in 10 mins',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
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
}

// ─── Close Button ─────────────────────────────────────────────────────────────

class _CloseButton extends StatefulWidget {
  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 0.88,
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
        Navigator.pop(context);
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

// ─── Wishlist Button ──────────────────────────────────────────────────────────

class _WishlistButton extends StatelessWidget {
  const _WishlistButton({required this.product});

  final ProductModel product;

  Future<void> _toggleFavorite(BuildContext context, AppState state) async {
    if (state.token == null || state.user == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await state.toggleFavorite(product);
    } catch (e) {
      if (!context.mounted) return;
      showToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final liked = state.isFavorite(product);
        return GestureDetector(
          onTap: () => _toggleFavorite(context, state),
          child: AnimatedScale(
            scale: liked ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: liked ? _kOrangeLight : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: liked ? _kOrange : const Color(0xFF888888),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Category Pill ────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryAccent(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(category), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delivery Strip ───────────────────────────────────────────────────────────

class _DeliveryStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_rounded, size: 16, color: _kGreen),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Free delivery • Arrives in 10 minutes',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: _kGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'FREE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorSourceCard extends StatelessWidget {
  const _VendorSourceCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final vendorName = _vendorNameFor(product);
    final vendorCity = product.supplierCity.trim();
    final sourceLine = vendorName == 'Doormart Main Store'
        ? 'Fulfilled from the main store'
        : 'Fulfilled by $vendorName';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7D9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _VendorLogoBadge(product: product),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sourced directly from',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            vendorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vendorCity.isEmpty ? sourceLine : '$sourceLine in $vendorCity',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorLogoBadge extends StatelessWidget {
  const _VendorLogoBadge({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final logo = NetworkImageUrl.normalize(product.supplierLogo);
    final hasLogo = logo.isNotEmpty && logo != 'null';

    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8541A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: hasLogo
            ? (logo.startsWith('http')
                  ? Image.network(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : Image.asset(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    ))
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return const ColoredBox(
      color: Colors.transparent,
      child: Icon(Icons.storefront_rounded, color: _kOrange, size: 20),
    );
  }
}

// ─── Quantity + Cart Bar ──────────────────────────────────────────────────────

class _QuantityCartBar extends StatelessWidget {
  const _QuantityCartBar({
    required this.quantity,
    required this.adding,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddToCart,
    required this.product,
    required this.selectedUnit,
    required this.selectedPrice,
    required this.taxPercent,
    required this.selectedStock,
  });

  final int quantity;
  final bool adding;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onAddToCart;
  final ProductModel product;
  final String selectedUnit;
  final double selectedPrice;
  final double taxPercent;
  final int selectedStock;

  @override
  Widget build(BuildContext context) {
    final baseTotal = selectedPrice * quantity;
    final gstAmount = baseTotal * taxPercent / 100;
    final totalPrice = baseTotal + gstAmount;
    final canIncrease = selectedStock > 0 ? quantity < selectedStock : false;
    final canAdd = selectedStock > 0;

    return Row(
      children: [
        // ── Quantity selector ──────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                icon: Icons.remove_rounded,
                enabled: quantity > 1,
                onTap: onDecrement,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: SizedBox(
                  width: 36,
                  child: Text(
                    '$quantity',
                    key: ValueKey(quantity),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.add_rounded,
                enabled: canIncrease,
                onTap: onIncrement,
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ── Add to cart button ─────────────────────────────────────────
        Expanded(
          child: _AddToCartButton(
            adding: adding,
            totalPrice: totalPrice,
            unitLabel: selectedUnit,
            taxPercent: taxPercent,
            enabled: canAdd,
            onTap: onAddToCart,
          ),
        ),
      ],
    );
  }
}

class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.variants,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ProductUnitVariant> variants;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose pack size',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(variants.length, (index) {
              final variant = variants[index];
              final selected = index == selectedIndex;
              final displayPrice = variant.price > 0 ? variant.price : 0;
              final stock = variant.stock;
              return InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF0EB) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFE8541A)
                          : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: selected
                            ? const Color(0xFFE8541A).withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 16,
                            color: selected
                                ? const Color(0xFFE8541A)
                                : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _unitLabel(variant.unit),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? const Color(0xFFE8541A)
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs ${displayPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock > 0 ? '$stock in stock' : 'Out of stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: stock > 0
                              ? const Color(0xFF6B7280)
                              : const Color(0xFFE8541A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatefulWidget {
  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_QtyBtn> createState() => _QtyBtnState();
}

class _QtyBtnState extends State<_QtyBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _s = Tween<double>(
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
      onTapDown: widget.enabled ? (_) => _c.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _c.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: widget.enabled ? _kOrange : const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatefulWidget {
  const _AddToCartButton({
    required this.adding,
    required this.totalPrice,
    required this.unitLabel,
    required this.taxPercent,
    required this.enabled,
    required this.onTap,
  });
  final bool adding;
  final double totalPrice;
  final String unitLabel;
  final double taxPercent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final Animation<double> _s = Tween<double>(
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
    final taxLabel = widget.taxPercent > 0 ? 'incl. GST' : 'GST included';
    return GestureDetector(
      onTapDown: widget.adding || !widget.enabled ? null : (_) => _c.forward(),
      onTapUp: widget.adding || !widget.enabled
          ? null
          : (_) {
              _c.reverse();
              widget.onTap();
            },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: widget.adding || !widget.enabled
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFF26522), Color(0xFFE8401A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: widget.adding || !widget.enabled
                ? const Color(0xFFE0E0E0)
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.adding || !widget.enabled
                ? []
                : [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: widget.adding
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rs ${widget.totalPrice.toStringAsFixed(2)} • ${widget.unitLabel} • $taxLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Product Background Image ─────────────────────────────────────────────────

class _ProductBackground extends StatelessWidget {
  const _ProductBackground({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = NetworkImageUrl.normalize(product.imageUrl);
    debugPrint('ProductSheet image: $imageUrl');

    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            _funnyMissingImageFallback(context, product),
      );
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _categoryAccent(product.category),
            ),
          );
        },
        errorBuilder: (_, __, ___) =>
            _funnyMissingImageFallback(context, product),
      );
    }
    return _funnyMissingImageFallback(context, product);
  }
}

Widget _funnyMissingImageFallback(BuildContext context, ProductModel product) {
  final accent = _categoryAccent(product.category);
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.16),
          const Color(0xFFFFF7ED),
          Colors.white,
        ],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 18,
          right: 18,
          child: Transform.rotate(
            angle: 0.12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: const Text(
                'oops',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7C2D12),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.hide_image_outlined, size: 46, color: accent),
              ),
              const SizedBox(height: 10),
              Text(
                'Image took a tea break',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7C2D12).withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Still tasty, just camera shy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Icon(
            Icons.sentiment_satisfied_rounded,
            size: 18,
            color: accent.withValues(alpha: 0.55),
          ),
        ),
      ],
    ),
  );
}

class _ProductReviewsSection extends StatelessWidget {
  const _ProductReviewsSection({
    required this.product,
    required this.reviewsFuture,
  });

  final ProductModel product;
  final Future<List<ProductReviewModel>> reviewsFuture;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: FutureBuilder<List<ProductReviewModel>>(
        future: reviewsFuture,
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <ProductReviewModel>[];
          final visibleReviews = reviews.take(3).toList();
          final count = product.ratingCount > 0
              ? product.ratingCount
              : reviews.length;
          final average = product.rating > 0
              ? product.rating
              : (reviews.isEmpty
                    ? 0
                    : reviews.fold<double>(
                            0,
                            (sum, review) => sum + review.rating,
                          ) /
                          reviews.length);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.reviews_rounded, color: _kOrange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Customer reviews',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    average > 0 ? average.toStringAsFixed(1) : 'No rating yet',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  _CompactStars(rating: average.toDouble()),
                  Text(
                    count > 0
                        ? 'from $count customers'
                        : 'Be the first to review',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                const Text(
                  'Could not load review comments right now.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  reviews.isEmpty)
                const _ReviewLoading()
              else if (visibleReviews.isEmpty)
                const _ReviewEmptyState()
              else
                Column(
                  children: [
                    for (final review in visibleReviews) ...[
                      _ReviewTile(review: review),
                      if (review != visibleReviews.last)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactStars extends StatelessWidget {
  const _CompactStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final filled = rating.clamp(0, 5).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final active = index < filled;
        return Icon(
          active ? Icons.star_rounded : Icons.star_border_rounded,
          size: 15,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }
}

class _ReviewLoading extends StatelessWidget {
  const _ReviewLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: const Text(
        'No written reviews yet. Ratings from delivered orders will appear here.',
        style: TextStyle(
          fontSize: 12.5,
          color: Color(0xFF6B7280),
          height: 1.45,
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReviewModel review;

  @override
  Widget build(BuildContext context) {
    final name = review.userName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewAvatar(review: review, initial: initial),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _reviewTimeLabel(review.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _CompactStars(rating: review.rating),
                if (review.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    review.comment.trim(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF374151),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  const _ReviewAvatar({required this.review, required this.initial});

  final ProductReviewModel review;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final avatar = review.userAvatarUrl.trim();
    final hasAsset = avatar.startsWith('assets/');
    final hasHttp = avatar.startsWith('http');

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFFEEAD8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF9C7A6)),
      ),
      child: ClipOval(
        child: hasHttp
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(),
              )
            : hasAsset
            ? Image.asset(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: _kOrange,
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _unitLabel(String value) {
  final unit = value.trim();
  if (unit.isEmpty) return '1 item';
  if (RegExp(r'^\d').hasMatch(unit)) return unit;
  return '1 $unit';
}

String _descriptionFor(ProductModel product) {
  final description = product.description.trim();
  if (description.isNotEmpty) return description;
  return 'Fresh ${product.name.toLowerCase()} — sourced directly and '
      'delivered to your door in under 10 minutes.';
}

String _vendorNameFor(ProductModel product) {
  final supplier = product.supplierName.trim();
  if (supplier.isNotEmpty) return supplier;
  return 'Doormart Main Store';
}

String _reviewTimeLabel(DateTime? createdAt) {
  if (createdAt == null) return '';
  final local = createdAt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${local.day}/${local.month}/${local.year}';
}

Color _categoryAccent(String category) {
  return switch (category.toLowerCase()) {
    'vegetables' => const Color(0xFF16A34A),
    'fruits' => const Color(0xFFEA580C),
    'dairy' => const Color(0xFF2563EB),
    'staples' => const Color(0xFFB45309),
    'snacks' => const Color(0xFFDB2777),
    'beverages' => const Color(0xFF0891B2),
    _ => _kOrange,
  };
}

IconData _categoryIcon(String category) {
  return switch (category.toLowerCase()) {
    'vegetables' => Icons.eco_rounded,
    'fruits' => Icons.apple_rounded,
    'dairy' => Icons.water_drop_rounded,
    'staples' => Icons.rice_bowl_rounded,
    'snacks' => Icons.cookie_rounded,
    'beverages' => Icons.local_drink_rounded,
    _ => Icons.local_grocery_store_rounded,
  };
}

String _bestImageAsset(ProductModel product) {
  final name = product.name.toLowerCase();
  final cat = product.category.toLowerCase();
  if (name.contains('tomato')) return 'assets/images/products/tomato.png';
  if (name.contains('milk')) return 'assets/images/products/milk.png';
  if (name.contains('rice')) return 'assets/images/products/rice.png';
  if (name.contains('dal') || name.contains('toor')) {
    return 'assets/images/products/dal.png';
  }
  if (name.contains('ghee') || name.contains('oil')) {
    return 'assets/images/products/oil.png';
  }
  if (name.contains('banana')) return 'assets/images/products/banana.png';
  return switch (cat) {
    'vegetables' => 'assets/images/products/tomato.png',
    'fruits' => 'assets/images/products/banana.png',
    'dairy' => 'assets/images/products/milk.png',
    'staples' => 'assets/images/products/rice.png',
    _ => 'assets/images/products/oil.png',
  };
}
