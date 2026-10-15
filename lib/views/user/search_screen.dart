import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../features/customer/search/voice_search_widget.dart';
import '../../providers/app_state.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/closed_store_overlay.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/product_bottom_sheet.dart';
import '../../widgets/product_price_breakdown.dart';
import '../../widgets/toast_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  static const routeName = '/search';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  bool _initialized = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().loadNearbyVendorIds();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final initialQuery = ModalRoute.of(context)?.settings.arguments as String?;
    if (initialQuery != null && initialQuery.trim().isNotEmpty) {
      _searchController.text = initialQuery.trim();
      _query = initialQuery.trim();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _SearchHeader(
                    controller: _searchController,
                    onChanged: (query) {
                      setState(() => _query = query.trim());
                    },
                    onSubmitted: (query) {
                      setState(() => _query = query.trim());
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Consumer<AppState>(
                  builder: (context, state, _) {
                    final products = _filteredProducts(state.nearbyProducts);
                    final count = products.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _ResultPill(label: 'Results', value: count),
                          const SizedBox(width: 8),
                          _ResultPill(label: 'Category', value: 'All'),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              Consumer<AppState>(
                builder: (context, state, _) {
                  final products = _filteredProducts(state.nearbyProducts);
                  if ((state.loading || state.nearbyVendorsLoading) &&
                      products.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (state.error != null && products.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(state.error!),
                      ),
                    );
                  }
                  if (_query.isNotEmpty && products.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: _EmptyState(),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return Selector<AppState, bool>(
                          selector: (_, appState) =>
                              appState.isFavorite(product),
                          builder: (context, isFavorite, _) {
                            return _ProductFeedCard(
                              product: product,
                              isFavorite: isFavorite,
                              onFavoriteToggle: () async {
                                final tapSw = Stopwatch()..start();
                                try {
                                  await context.read<AppState>().toggleFavorite(
                                    product,
                                  );
                                } catch (_) {}
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  debugPrint(
                                    '[perf][favorite:search][ui] ${tapSw.elapsedMilliseconds}ms',
                                  );
                                });
                              },
                              onTap: () => showProductBottomSheet(
                                context,
                                product,
                                onAddToCart: (quantity, variant) async {
                                  final tapSw = Stopwatch()..start();
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
                                        : context.read<AppState>().error ??
                                              'Please login first',
                                  );
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    debugPrint(
                                      '[perf][cart:search][ui] ${tapSw.elapsedMilliseconds}ms',
                                    );
                                  });
                                },
                              ),
                              onAdd: () async {
                                final tapSw = Stopwatch()..start();
                                final added = await context
                                    .read<AppState>()
                                    .addToCart(product);
                                if (!context.mounted) return;
                                showToast(
                                  context,
                                  added
                                      ? '${product.name} added to cart'
                                      : context.read<AppState>().error ??
                                            'Please login first',
                                );
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  debugPrint(
                                    '[perf][cart:search][ui] ${tapSw.elapsedMilliseconds}ms',
                                  );
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        index: 0,
        onTap: (index) => BottomNavBar.navigate(context, index),
      ),
    );
  }

  List<dynamic> _filteredProducts(List<dynamic> input) {
    var items = List<dynamic>.from(input);
    final q = _query.toLowerCase().trim();
    if (q.isNotEmpty) {
      items = items.where((item) {
        final name = (item.name as String).toLowerCase();
        final category = (item.category as String).toLowerCase();
        final description = (item.description as String? ?? '').toLowerCase();
        final supplierName = (item.supplierName as String? ?? '').toLowerCase();
        final supplierCity = (item.supplierCity as String? ?? '').toLowerCase();
        return name.contains(q) ||
            category.contains(q) ||
            description.contains(q) ||
            supplierName.contains(q) ||
            supplierCity.contains(q);
      }).toList();
    }
    return items;
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E8DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Search products',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          VoiceSearchWidget(
            controller: controller,
            autofocus: true,
            hintText: 'Search groceries in English',
            showSearchAction: false,
            onSearchChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear search'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: Color(0xFF0F9D58)),
          SizedBox(height: 10),
          Text(
            'No matching products found',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ProductFeedCard extends StatelessWidget {
  const _ProductFeedCard({
    required this.product,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onAdd,
    required this.onTap,
  });

  final dynamic product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent((product.category as String?) ?? '');
    final storeLabel = _storeLabel(product);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 190,
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
                            child: _BadgeButton(
                              active: isFavorite,
                              onTap: onFavoriteToggle,
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: isFavorite
                                    ? const Color(0xFFE8541A)
                                    : const Color(0xFFAAAAAA),
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
                                  icon: Icons.straighten_rounded,
                                  label: _unitLabel(product.unit),
                                ),
                              ],
                            ),
                          ),
                          if (isStoreClosedForProduct(product))
                            ClosedStoreOverlay(
                              label: closedStoreLabelForProduct(product),
                            ),
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
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.category,
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ProductPriceBreakdown(
                                    product: product,
                                    compact: true,
                                    showBreakdown: false,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to see more packs',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                    ),
                                  ),
                                ],
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE8541A,
                                      ).withValues(alpha: 0.28),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: FilledButton.icon(
                                  onPressed: onAdd,
                                  icon: const Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Add',
                                    style: TextStyle(
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
                                      horizontal: 18,
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
      ),
    );
  }
}

String _storeLabel(dynamic product) {
  final name = (product.supplierName as String? ?? '').trim();
  final city = (product.supplierCity as String? ?? '').trim();
  if (name.isEmpty) return '';
  if (city.isEmpty) return name;
  return '$name · $city';
}

String _unitLabel(String value) {
  final unit = value.trim();
  if (unit.isEmpty) return '1 item';
  if (RegExp(r'^\d').hasMatch(unit)) return unit;
  return '1 $unit';
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
                _funnyMissingImageFallback(context, product, compact: true),
          )
        : _funnyMissingImageFallback(context, product, compact: true);

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

Widget _funnyMissingImageFallback(
  BuildContext context,
  dynamic product, {
  bool compact = false,
}) {
  final accent = _categoryAccent((product.category as String?) ?? '');
  final bubbleSize = compact ? 64.0 : 84.0;
  final iconSize = compact ? 32.0 : 42.0;
  final titleSize = compact ? 11.0 : 12.0;
  final subtitleSize = compact ? 9.0 : 10.0;
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
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: bubbleSize,
                height: bubbleSize,
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
                child: Icon(
                  Icons.hide_image_outlined,
                  size: iconSize,
                  color: accent,
                ),
              ),
              SizedBox(height: compact ? 6 : 10),
              Text(
                'Image took a tea break',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7C2D12).withValues(alpha: 0.92),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                'Still tasty, just camera shy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: subtitleSize,
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

class _BadgeButton extends StatelessWidget {
  const _BadgeButton({
    required this.active,
    required this.child,
    required this.onTap,
  });

  final bool active;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8541A).withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          active ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: active ? const Color(0xFFE8541A) : const Color(0xFFAAAAAA),
        ),
      ),
    );
  }
}
