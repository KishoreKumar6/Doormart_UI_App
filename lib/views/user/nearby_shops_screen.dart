import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/network_image_url.dart';
import '../../features/operations/services/location_service.dart';
import '../../providers/app_state.dart';
import 'cart_screen.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';
import 'user_home_screen.dart';

const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF6F6F6);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF8F8F8F);
const _kBorder = Color(0xFFECECEC);

class NearbyShopsScreen extends StatefulWidget {
  const NearbyShopsScreen({super.key});

  static const routeName = '/nearby-shops';

  @override
  State<NearbyShopsScreen> createState() => _NearbyShopsScreenState();
}

class _NearbyShopsScreenState extends State<NearbyShopsScreen> {
  List<_NearbyShop> _shops = const [];
  bool _loading = true;
  String? _message;
  bool _apiUnavailable = false;
  double _radiusKm = AppState.nearbyRadiusKm;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops({double? radiusKm}) async {
    final radius = radiusKm ?? _radiusKm;
    setState(() {
      _loading = true;
      _message = null;
      _apiUnavailable = false;
      _radiusKm = radius;
    });

    Object? locationError;
    ({double latitude, double longitude})? location;
    try {
      location = await LocationService().nearbyLocation().timeout(
        const Duration(seconds: 25),
      );
    } catch (error) {
      locationError = error;
      location = await LocationService().cachedNearbyLocation();
      if (location != null) {
        debugPrint(
          'Nearby shops page using cached live location after GPS retry failed: $error',
        );
      }
    }

    if (location == null) {
      if (!mounted) return;
      setState(() {
        _shops = const [];
        _loading = false;
        _message = _locationMessage(locationError ?? 'Location unavailable');
      });
      return;
    }

    try {
      if (!mounted) return;
      final state = context.read<AppState>();
      final response = await state.apiService.get(
        '/vendors/nearby?latitude=${location.latitude}&longitude=${location.longitude}&radiusKm=$radius',
        token: state.token,
      );
      final vendors = response is List ? response : const [];
      if (!mounted) return;
      setState(() {
        _shops = vendors
            .whereType<Map<String, dynamic>>()
            .map(_NearbyShop.fromJson)
            .toList();
        _loading = false;
      });
    } catch (error) {
      debugPrint('Nearby shops page load failed: $error');
      if (!mounted) return;
      setState(() {
        _shops = const [];
        _loading = false;
        _apiUnavailable = true;
        _message = 'Unable to load nearby shops. Please try again.';
      });
    }
  }

  String _locationMessage(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('services are disabled')) {
      return 'Turn on phone location/GPS to see nearby shops.';
    }
    if (value.contains('permission')) {
      return kIsWeb
          ? 'Click the location icon in the browser address bar, choose Allow, then tap Try again.'
          : 'Allow location permission to see nearby shops.';
    }
    return 'Turn on location and allow permission to see nearby shops.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NearbyShopsAppBar(),
            _NearbyHero(
              radiusKm: _radiusKm,
              shopCount: _shops.length,
              loading: _loading,
            ),
            _RadiusSelector(
              radiusKm: _radiusKm,
              onSelect: (radius) => _loadShops(radiusKm: radius),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _ShopLoadingList();
    if (_message != null) {
      return _ShopMessage(
        icon: _apiUnavailable
            ? Icons.cloud_off_rounded
            : Icons.location_off_rounded,
        title: _apiUnavailable ? 'Nearby shops unavailable' : 'Location needed',
        message: _message!,
        actionLabel: 'Try again',
        onAction: () => _loadShops(),
      );
    }
    if (_shops.isEmpty) {
      return _ShopMessage(
        icon: Icons.storefront_outlined,
        title: 'No shops within ${_radiusKm.toStringAsFixed(0)} km',
        message: 'Try a wider search area to find more stores near you.',
        actionLabel: _radiusKm < 10 ? 'Search within 10 km' : null,
        onAction: _radiusKm < 10 ? () => _loadShops(radiusKm: 10) : null,
      );
    }
    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () => _loadShops(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _shops.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ShopCard(shop: _shops[index]),
      ),
    );
  }
}

class _NearbyShopsAppBar extends StatelessWidget {
  const _NearbyShopsAppBar();

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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _AppBarIcon(icon: Icons.chevron_left_rounded, onTap: goBack),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shops near you',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stores available around your live location',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kTextMid,
                  ),
                ),
              ],
            ),
          ),
          _AppBarIcon(
            icon: Icons.search_rounded,
            onTap: () => Navigator.pushNamed(context, SearchScreen.routeName),
          ),
          const SizedBox(width: 10),
          Consumer<AppState>(
            builder: (context, state, _) => _AppBarIcon(
              icon: Icons.shopping_bag_outlined,
              badge: state.cart.isEmpty
                  ? null
                  : state.cart
                        .fold<int>(0, (sum, line) => sum + line.quantity)
                        .toString(),
              onTap: () => Navigator.pushNamed(context, CartScreen.routeName),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({required this.icon, required this.onTap, this.badge});

  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
            child: Icon(icon, size: 24, color: _kTextDark),
          ),
          if (badge != null)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _kOrange,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NearbyHero extends StatelessWidget {
  const _NearbyHero({
    required this.radiusKm,
    required this.shopCount,
    required this.loading,
  });

  final double radiusKm;
  final int shopCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6A2A), Color(0xFFE8340C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? 'Finding nearby shops' : '$shopCount shops found',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing stores within ${radiusKm.toStringAsFixed(0)} km of your current location.',
                  style: const TextStyle(
                    color: Color(0xFFFFE4DA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.radiusKm, required this.onSelect});

  final double radiusKm;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        scrollDirection: Axis.horizontal,
        children: [
          _RadiusChip(
            label: 'Within 5 km',
            active: radiusKm.round() == 5,
            onTap: () => onSelect(5),
          ),
          const SizedBox(width: 10),
          _RadiusChip(
            label: 'Within 10 km',
            active: radiusKm.round() == 10,
            onTap: () => onSelect(10),
          ),
        ],
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(active ? Icons.check_rounded : Icons.near_me_rounded),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kOrange,
        backgroundColor: active ? _kOrangeLight : Colors.white,
        side: BorderSide(color: active ? _kOrange : const Color(0xFFF1CDBD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});

  final _NearbyShop shop;

  @override
  Widget build(BuildContext context) {
    final isClosed = shop.isOpen == false;
    return GestureDetector(
      onTap: isClosed
          ? null
          : () => Navigator.pushNamed(
              context,
              ProductListScreen.routeName,
              arguments: ProductListArgs(
                vendorId: shop.id,
                shopName: shop.name,
                shopCity: shop.city,
                shopLogo: shop.logo,
                shopImageUrl: shop.shopImageUrl,
                shopAddress: shop.address,
                distanceKm: shop.distanceKm,
                rating: shop.rating,
                etaMinutes: shop.etaMinMinutes,
                deliveryFee: shop.deliveryFee,
                minOrderAmount: shop.minOrderAmount,
                isOpen: shop.isOpen,
                todayOpenTime: shop.todayOpenTime,
                todayCloseTime: shop.todayCloseTime,
              ),
            ),
      child: Opacity(
        opacity: isClosed ? 0.62 : 1,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 1, maxScaleFactor: 1.05),
          ),
          child: Container(
            height: 142,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isClosed ? const Color(0xFFF9FAFB) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  height: double.infinity,
                  child: _ShopImage(shop: shop),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _kTextDark,
                                ),
                              ),
                            ),
                            if (isClosed)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE7E0),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Closed',
                                  style: TextStyle(
                                    color: _kOrange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Color(0xFFF5A623),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  shop.ratingLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (shop.etaLabel != null)
                              Text(
                                shop.etaLabel!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _kTextMid,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            Text(
                              '${shop.productCount} items',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kTextMid,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.deliveryLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kTextDark,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isClosed ? _kTextMid : _kOrange,
                              size: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopImage extends StatelessWidget {
  const _ShopImage({required this.shop});

  final _NearbyShop shop;

  @override
  Widget build(BuildContext context) {
    final image = shop.shopImageUrl.trim().isNotEmpty
        ? shop.shopImageUrl.trim()
        : shop.logo.trim();
    final normalized = NetworkImageUrl.normalize(image);
    if (normalized.isEmpty) return const _ShopFallback();
    return Image.network(
      normalized,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _ShopFallback(),
    );
  }
}

class _ShopFallback extends StatefulWidget {
  const _ShopFallback();

  @override
  State<_ShopFallback> createState() => _ShopFallbackState();
}

class _ShopFallbackState extends State<_ShopFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final Animation<double> _pulse = Tween<double>(
    begin: 0.94,
    end: 1.08,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF0EB), Color(0xFFFFC9B4)],
              ),
            ),
          ),
          Center(
            child: Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _kOrange,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopLoadingList extends StatelessWidget {
  const _ShopLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => Container(
        height: 132,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 116,
              decoration: const BoxDecoration(color: _kOrangeLight),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skeleton(width: 130, height: 14),
                    const SizedBox(height: 10),
                    _Skeleton(width: 180, height: 10),
                    const SizedBox(height: 14),
                    _Skeleton(width: 150, height: 10),
                    const Spacer(),
                    _Skeleton(width: 120, height: 10),
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

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _ShopMessage extends StatelessWidget {
  const _ShopMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kOrange, size: 44),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyShop {
  const _NearbyShop({
    required this.id,
    required this.name,
    required this.city,
    required this.logo,
    required this.shopImageUrl,
    required this.address,
    required this.productCount,
    required this.rating,
    this.etaMinMinutes,
    this.etaMaxMinutes,
    this.deliveryFee,
    this.minOrderAmount,
    this.isOpen,
    this.todayOpenTime,
    this.todayCloseTime,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String city;
  final String logo;
  final String shopImageUrl;
  final String address;
  final int productCount;
  final double rating;
  final int? etaMinMinutes;
  final int? etaMaxMinutes;
  final double? deliveryFee;
  final double? minOrderAmount;
  final bool? isOpen;
  final String? todayOpenTime;
  final String? todayCloseTime;
  final double? distanceKm;

  String get subtitle {
    final parts = <String>[
      if (isOpen != null) isOpen == true ? 'Open now' : 'Closed',
      if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)} km',
      if (city.trim().isNotEmpty) city,
    ];
    return parts.join(' · ');
  }

  String? get etaLabel {
    final min = etaMinMinutes;
    final max = etaMaxMinutes;
    if (min == null && max == null) return null;
    if (min != null && max != null && max > min) return '$min–$max min';
    return '${min ?? max} min';
  }

  String get ratingLabel => rating > 0 ? rating.toStringAsFixed(1) : 'New';

  String get deliveryLabel {
    final fee = deliveryFee;
    final min = minOrderAmount;
    final parts = <String>[];
    if (fee != null && fee > 0) {
      parts.add('Delivery ₹${fee.toStringAsFixed(0)}');
    }
    if (min != null) parts.add('Min order ₹${min.toStringAsFixed(0)}');
    return parts.isEmpty ? 'Tap to shop products' : parts.join(' · ');
  }

  factory _NearbyShop.fromJson(Map<String, dynamic> json) {
    return _NearbyShop(
      id: json['vendorId']?.toString() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : 'Local grocery shop',
      city: json['city']?.toString().trim().isNotEmpty == true
          ? json['city'].toString()
          : 'Nearby',
      logo: json['logoUrl']?.toString() ?? '',
      shopImageUrl: json['shopImageUrl']?.toString() ?? '',
      address: _nearbyFullAddress(json),
      productCount: _nearbyInt(json['productCount']),
      rating: _nearbyDouble(json['rating']),
      etaMinMinutes: _nearbyNullableInt(
        json['etaMinMinutes'] ?? json['etaMinutes'],
      ),
      etaMaxMinutes: _nearbyNullableInt(json['etaMaxMinutes']),
      deliveryFee: _nearbyNullableDouble(json['deliveryFee']),
      minOrderAmount: _nearbyNullableDouble(json['minOrderAmount']),
      isOpen: json['isOpen'] is bool ? json['isOpen'] as bool : null,
      todayOpenTime: json['todayOpenTime']?.toString(),
      todayCloseTime: json['todayCloseTime']?.toString(),
      distanceKm: _nearbyNullableDouble(json['distanceKm']),
    );
  }
}

String _nearbyFullAddress(Map<String, dynamic> json) {
  final direct = _cleanNearbyAddressParts([json['fullAddress']]);
  if (direct.isNotEmpty) return direct;

  return _cleanNearbyAddressParts([
    json['pickupAddress'] ?? json['address'],
    json['city'],
    json['state'],
    json['pincode'],
  ]);
}

String _cleanNearbyAddressParts(List<dynamic> values) {
  String key(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  final cleaned = <String>[];
  final parts = values
      .expand((value) => (value ?? '').toString().split(','))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);

  for (final part in parts) {
    final partKey = key(part);
    final duplicate = cleaned.any((existing) {
      final existingKey = key(existing);
      return existingKey == partKey || existingKey.contains(partKey);
    });
    if (!duplicate) cleaned.add(part);
  }
  return cleaned.join(', ');
}

double _nearbyDouble(dynamic value, {double fallback = 0}) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number?.isFinite == true ? number! : fallback;
}

int _nearbyInt(dynamic value, {int fallback = 0}) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  return number ?? fallback;
}

int? _nearbyNullableInt(dynamic value) {
  return value is num ? value.toInt() : int.tryParse('$value');
}

double? _nearbyNullableDouble(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number?.isFinite == true ? number : null;
}
