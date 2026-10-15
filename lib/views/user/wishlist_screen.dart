import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../widgets/product_bottom_sheet.dart';
import '../../widgets/closed_store_overlay.dart';
import '../../widgets/product_price_breakdown.dart';
import '../../widgets/premium_selection_sheet.dart';
import '../../widgets/toast_widget.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'cart_screen.dart';
import 'search_screen.dart';
import 'user_home_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  static const routeName = '/wishlist';

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      state.loadNearbyVendorIds();
      state.loadFavorites();
    });
  }

  bool _fastDeliveryOnly = false;
  bool _ratingOnly = false;
  _WishlistSort _sort = _WishlistSort.relevance;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            final favorites = _applyFilters(state.nearbyFavorites);
            return Column(
              children: [
                _TopBar(
                  cartCount: state.cartCount,
                  onBack: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        UserHomeScreen.routeName,
                        (route) => false,
                      );
                    }
                  },
                  onCart: () =>
                      Navigator.pushNamed(context, CartScreen.routeName),
                  onSearch: () =>
                      Navigator.pushNamed(context, SearchScreen.routeName),
                ),
                // Filter pills row
                SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterPill(
                        label: 'Filter',
                        icon: Icons.tune,
                        active: _fastDeliveryOnly || _ratingOnly,
                        onTap: () => _showFilterSheet(context),
                      ),
                      _FilterPill(
                        label: 'Sort by',
                        icon: Icons.keyboard_arrow_down,
                        active: _sort != _WishlistSort.relevance,
                        onTap: () => _showSortSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: state.nearbyVendorsLoading && favorites.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : favorites.isEmpty
                      ? const _EmptyFavoritesCard()
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            24 + bottomInset,
                          ),
                          itemCount: favorites.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final product = favorites[index];
                            final statusProduct = state.storeStatusProduct(
                              product,
                            );
                            return _FavoriteCard(
                              product: product,
                              isClosed: statusProduct.vendorIsOpen == false,
                              closedLabel: closedStoreLabelForProduct(
                                statusProduct,
                              ),
                              onTap: () => showProductBottomSheet(
                                context,
                                product,
                                onAddToCart: (quantity, variant) async {
                                  final added = await context
                                      .read<AppState>()
                                      .addToCart(
                                        product,
                                        quantity: quantity,
                                        unit: variant.unit,
                                        price: variant.price,
                                        discountCost: variant.discountCost,
                                        stock: variant.stock,
                                      );
                                  if (!context.mounted) return;
                                  showToast(
                                    context,
                                    added
                                        ? '${product.name} added to cart'
                                        : state.error ?? 'Please login first',
                                  );
                                },
                              ),
                              onToggleFavorite: () async {
                                await context.read<AppState>().removeFavorite(
                                  product.id,
                                );
                                if (!context.mounted) return;
                                showToast(
                                  context,
                                  '${product.name} removed from favorites',
                                );
                              },
                              isFavorited: true,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        index: 3,
        onTap: (index) => BottomNavBar.navigate(context, index),
      ),
    );
  }

  List<ProductModel> _applyFilters(List<ProductModel> input) {
    var items = List<ProductModel>.from(input);
    if (_fastDeliveryOnly) items = items.where((e) => e.stock >= 10).toList();
    if (_ratingOnly) items = items.where((e) => e.rating >= 4.0).toList();
    switch (_sort) {
      case _WishlistSort.relevance:
        break;
      case _WishlistSort.priceLowHigh:
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _WishlistSort.priceHighLow:
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _WishlistSort.ratingHighLow:
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _WishlistSort.nameAZ:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }
    return items;
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PremiumSelectionSheet(
        icon: Icons.tune_rounded,
        title: 'Filter favourites',
        subtitle: 'Select one or more ways to refine your saved products.',
        options: const ['Fast Delivery', 'Ratings 4.0+'],
        selectedValues: {
          if (_fastDeliveryOnly) 'Fast Delivery',
          if (_ratingOnly) 'Ratings 4.0+',
        },
        multiSelect: true,
        actionLabel: 'Apply Filters',
        onApply: (values) {
          setState(() {
            _fastDeliveryOnly = values.contains('Fast Delivery');
            _ratingOnly = values.contains('Ratings 4.0+');
          });
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PremiumSelectionSheet(
        icon: Icons.swap_vert_rounded,
        title: 'Sort favourites',
        subtitle: 'Choose how your saved products should appear.',
        options: const [
          'Relevance',
          'Price: Low to High',
          'Price: High to Low',
          'Rating: High to Low',
          'Name: A to Z',
        ],
        selectedValues: {_wishlistSortLabel(_sort)},
        listMode: true,
        actionLabel: 'Apply Sort',
        onApply: (values) {
          setState(() => _sort = _wishlistSortFromLabel(values.first));
          Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

enum _WishlistSort {
  relevance,
  priceLowHigh,
  priceHighLow,
  ratingHighLow,
  nameAZ,
}

String _wishlistSortLabel(_WishlistSort sort) {
  return switch (sort) {
    _WishlistSort.relevance => 'Relevance',
    _WishlistSort.priceLowHigh => 'Price: Low to High',
    _WishlistSort.priceHighLow => 'Price: High to Low',
    _WishlistSort.ratingHighLow => 'Rating: High to Low',
    _WishlistSort.nameAZ => 'Name: A to Z',
  };
}

_WishlistSort _wishlistSortFromLabel(String label) {
  return switch (label) {
    'Price: Low to High' => _WishlistSort.priceLowHigh,
    'Price: High to Low' => _WishlistSort.priceHighLow,
    'Rating: High to Low' => _WishlistSort.ratingHighLow,
    'Name: A to Z' => _WishlistSort.nameAZ,
    _ => _WishlistSort.relevance,
  };
}

// ─── Top Bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.cartCount,
    required this.onBack,
    required this.onCart,
    required this.onSearch,
  });

  final int cartCount;
  final VoidCallback onBack;
  final VoidCallback onCart;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chevron_left,
                size: 26,
                color: Color(0xFF1E1C1A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Favourites',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1C1A),
              ),
            ),
          ),
          // Search icon
          GestureDetector(
            onTap: onSearch,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.search, size: 26, color: Color(0xFF1E1C1A)),
            ),
          ),
          const SizedBox(width: 4),
          // Cart icon with badge
          GestureDetector(
            onTap: onCart,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE8541A),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 22,
                    color: Color(0xFFE8541A),
                  ),
                ),
                if (cartCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8541A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$cartCount',
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
          ),
        ],
      ),
    );
  }
}

// ─── Favorite Card ───────────────────────────────────────────────────────────

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.product,
    required this.isClosed,
    required this.closedLabel,
    required this.onTap,
    required this.onToggleFavorite,
    required this.isFavorited,
  });

  final ProductModel product;
  final bool isClosed;
  final String closedLabel;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final bool isFavorited;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColor(product.category);
    final storeLabel = _storeLabel(product);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withValues(alpha: 0.74),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 198,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _GlassThumb(product: product, accent: accent),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: _StarBadge(
                            rating: product.rating.toStringAsFixed(1),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: GestureDetector(
                            onTap: onToggleFavorite,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFE8541A,
                                    ).withValues(alpha: 0.22),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: isFavorited
                                    ? const Color(0xFFE8541A)
                                    : const Color(0xFFAAAAAA),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (storeLabel.isNotEmpty)
                                _MiniGlassChip(
                                  icon: Icons.storefront_rounded,
                                  label: storeLabel,
                                ),
                              _MiniGlassChip(
                                icon: Icons.alarm_rounded,
                                label: '20-25 Min',
                              ),
                            ],
                          ),
                        ),
                        if (isClosed)
                          ClosedStoreOverlay(label: closedLabel),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fresh, quality-picked product ready to add to your cart.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.58),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            ProductPriceBreakdown(
                              product: product,
                              showBreakdown: false,
                            ),
                            const Spacer(),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF7A34),
                                    Color(0xFFE8541A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: FilledButton.icon(
                                onPressed: onToggleFavorite,
                                icon: Icon(
                                  isFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                ),
                                label: Text(
                                  isFavorited ? 'Saved' : 'Save',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
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
  }
}

Widget _funnyMissingImageFallback(BuildContext context, dynamic product) {
  final accent = _categoryAccent((product.category as String?) ?? '');
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
          top: 16,
          right: 16,
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
                width: 72,
                height: 72,
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
                child: Icon(Icons.hide_image_outlined, size: 36, color: accent),
              ),
              const SizedBox(height: 8),
              Text(
                'Image took a tea break',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7C2D12).withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Still tasty, just camera shy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GlassThumb extends StatelessWidget {
  const _GlassThumb({required this.product, required this.accent});

  final dynamic product;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final normalized = NetworkImageUrl.normalize(product.imageUrl);
    final child = normalized.startsWith('assets/')
        ? Image.asset(normalized, fit: BoxFit.cover)
        : normalized.startsWith('http')
        ? Image.network(
            normalized,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _funnyMissingImageFallback(context, product),
          )
        : _funnyMissingImageFallback(context, product);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniGlassChip extends StatelessWidget {
  const _MiniGlassChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 92,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarBadge extends StatelessWidget {
  const _StarBadge({required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFD54F)),
          const SizedBox(width: 3),
          Text(
            rating,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _categoryColor(String category) {
  return switch (category.toLowerCase()) {
    'vegetables' => const Color(0xFF16A34A),
    'fruits' => const Color(0xFFEA580C),
    'dairy' => const Color(0xFF2563EB),
    'staples' => const Color(0xFFB45309),
    'snacks' => const Color(0xFFDB2777),
    'beverages' => const Color(0xFF0891B2),
    _ => const Color(0xFFE8541A),
  };
}

String _storeLabel(ProductModel product) {
  final name = product.supplierName.trim();
  final city = product.supplierCity.trim();
  if (name.isEmpty) return '';
  if (city.isEmpty) return name;
  return '$name · $city';
}

Color _categoryAccent(String category) {
  return switch (category.toLowerCase()) {
    'vegetables' => const Color(0xFF16A34A),
    'fruits' => const Color(0xFFEA580C),
    'dairy' => const Color(0xFF2563EB),
    'staples' => const Color(0xFFB45309),
    'snacks' => const Color(0xFFDB2777),
    'beverages' => const Color(0xFF0891B2),
    _ => const Color(0xFFE8541A),
  };
}

// ─── Filter Pill ─────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? const [Color(0xFFFFF0EB), Color(0xFFFFE3D3)]
                  : const [Colors.white, Color(0xFFFFF7F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(0xFFE8541A) : const Color(0xFFF1CDBD),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFE8541A,
                ).withValues(alpha: active ? 0.28 : 0.16),
                blurRadius: active ? 18 : 14,
                spreadRadius: active ? 0.6 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon!, size: 18, color: const Color(0xFFE8541A)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: Color(0xFFE8541A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyFavoritesCard extends StatelessWidget {
  const _EmptyFavoritesCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 38,
              color: Color(0xFFE8541A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No favourites yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1C1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the heart on any product\nto save it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
