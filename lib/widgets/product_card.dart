import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/utils/network_image_url.dart';
import '../models/product_model.dart';
import 'product_price_breakdown.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
    required this.onFavoriteToggle,
    required this.isFavorite,
    this.onTap,
    this.imageFallbackBuilder,
    this.showRating = false,
  });

  final ProductModel product;
  final VoidCallback onAdd;
  final VoidCallback onFavoriteToggle;
  final bool isFavorite;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, ProductModel product)?
  imageFallbackBuilder;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                flex: 58,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(
                      product: product,
                      imageFallbackBuilder: imageFallbackBuilder,
                    ),
                    if (showRating)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                product.rating > 0
                                    ? product.rating.toStringAsFixed(1)
                                    : 'New',
                                style: const TextStyle(
                                  color: Color(0xFF142019),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFE8541A,
                                ).withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorite
                                ? const Color(0xFFE8541A)
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF142019),
                              fontSize: 17,
                            ),
                      ),
                      if (_storeLabel(product).isNotEmpty)
                        Row(
                          children: [
                            _StoreLogoBadge(product: product),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _storeLabel(product),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE8541A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        product.unit.trim().isEmpty
                            ? '1 item'
                            : (RegExp(r'^\d').hasMatch(product.unit.trim())
                                  ? product.unit.trim()
                                  : '1 ${product.unit.trim()}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ProductPriceBreakdown(
                              product: product,
                              compact: true,
                              showBreakdown: false,
                            ),
                          ),
                          const Icon(
                            Icons.timer,
                            size: 11,
                            color: Color(0xFFE8541A),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${product.stock > 20 ? 10 : 18} min',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8541A),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE8541A,
                              ).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _storeLabel(ProductModel product) {
  final name = product.supplierName.trim();
  final city = product.supplierCity.trim();
  if (name.isEmpty) return '';
  if (city.isEmpty) return name;
  return '$name · $city';
}

class _StoreLogoBadge extends StatelessWidget {
  const _StoreLogoBadge({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final logo = NetworkImageUrl.normalize(product.supplierLogo);
    final hasLogo = logo.isNotEmpty && logo != 'null';
    final tint = const Color(0xFFE8541A);

    return Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ClipOval(
        child: hasLogo
            ? (logo.startsWith('http')
                  ? Image.network(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(tint),
                    )
                  : Image.asset(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(tint),
                    ))
            : _fallback(tint),
      ),
    );
  }

  Widget _fallback(Color tint) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(Icons.storefront_rounded, size: 10, color: tint),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, this.imageFallbackBuilder});

  final ProductModel product;
  final Widget Function(BuildContext context, ProductModel product)?
  imageFallbackBuilder;

  @override
  Widget build(BuildContext context) {
    final path = NetworkImageUrl.normalize(product.imageUrl);
    debugPrint('Cloudinary Image URL (product card): $path');
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, _, _) => _fallbackProductImage(
          context,
          product,
          imageFallbackBuilder: imageFallbackBuilder,
        ),
      );
    }
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (context, _, _) => _fallbackProductImage(
          context,
          product,
          imageFallbackBuilder: imageFallbackBuilder,
        ),
      );
    }
    if (path.isNotEmpty) {
      return _fallbackProductImage(
        context,
        product,
        imageFallbackBuilder: imageFallbackBuilder,
      );
    }
    return _fallbackProductImage(
      context,
      product,
      imageFallbackBuilder: imageFallbackBuilder,
    );
  }
}

Widget _fallbackIcon(String category) {
  return Container(
    color: _categoryColor(category),
    alignment: Alignment.center,
    child: Icon(
      _categoryIcon(category),
      size: 48,
      color: const Color(0xFF0F9D58),
    ),
  );
}

Widget _fallbackProductImage(
  BuildContext context,
  ProductModel product, {
  Widget Function(BuildContext context, ProductModel product)?
  imageFallbackBuilder,
}) {
  if (imageFallbackBuilder != null) {
    return imageFallbackBuilder(context, product);
  }

  final asset = _bestImageAsset(product);

  return Image.asset(
    asset,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) => _fallbackIcon(product.category),
  );
}

String _bestImageAsset(ProductModel product) {
  final name = product.name.toLowerCase();
  final category = product.category.toLowerCase();

  if (name.contains('tomato')) return 'assets/images/products/tomato.png';
  if (name.contains('milk')) return 'assets/images/products/milk.png';
  if (name.contains('rice')) return 'assets/images/products/rice.png';
  if (name.contains('dal') || name.contains('toor')) {
    return 'assets/images/products/dal.png';
  }
  if (name.contains('ghee')) return 'assets/images/products/oil.png';
  if (name.contains('ice cream')) return 'assets/images/products/milk.png';
  if (name.contains('banana') || name.contains('fruit')) {
    return 'assets/images/products/banana.png';
  }

  return switch (category) {
    'vegetables' => 'assets/images/products/tomato.png',
    'fruits' => 'assets/images/products/banana.png',
    'dairy' => 'assets/images/products/milk.png',
    'staples' => 'assets/images/products/rice.png',
    _ => 'assets/images/products/oil.png',
  };
}

class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.onTap, this.tint});

  final Widget child;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint ?? Colors.white.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  return switch (category.toLowerCase()) {
    'vegetables' => Icons.eco,
    'fruits' => Icons.apple,
    'dairy' => Icons.local_drink,
    'staples' => Icons.rice_bowl,
    _ => Icons.local_grocery_store,
  };
}

Color _categoryColor(String category) {
  return switch (category.toLowerCase()) {
    'vegetables' => const Color(0xFFE7F7EC),
    'fruits' => const Color(0xFFFFF0D7),
    'dairy' => const Color(0xFFEAF1FF),
    'staples' => const Color(0xFFFFEFEA),
    _ => const Color(0xFFF1F4EF),
  };
}
