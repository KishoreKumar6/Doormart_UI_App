import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../features/operations/services/location_service.dart';
import '../../models/order_model.dart';
import '../../providers/app_state.dart';

class LiveOrderTrackingScreen extends StatefulWidget {
  const LiveOrderTrackingScreen({super.key});
  static const routeName = '/live-order-tracking';

  @override
  State<LiveOrderTrackingScreen> createState() =>
      _LiveOrderTrackingScreenState();
}

class _LiveOrderTrackingScreenState extends State<LiveOrderTrackingScreen> {
  Timer? _refreshTimer;
  Timer? _userLocationTimer;
  double? _latitude;
  double? _longitude;
  double? _userLatitude;
  double? _userLongitude;
  DateTime? _updatedAt;
  String? _error;
  bool _loading = true;

  OrderModel? get _order =>
      ModalRoute.of(context)?.settings.arguments as OrderModel?;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocation();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshLocation(),
      );
      _userLocationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshUserLocation(),
      );
      _refreshUserLocation();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _userLocationTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUserLocation() async {
    try {
      final location = await LocationService().currentLocation();
      if (!mounted) return;
      setState(() {
        _userLatitude = location.latitude;
        _userLongitude = location.longitude;
      });
    } catch (_) {
      // The delivery marker remains useful even when customer location is
      // unavailable because permission or device location is disabled.
    }
  }

  Future<void> _refreshLocation() async {
    final order = _order;
    final state = context.read<AppState>();
    if (order == null || state.token == null) return;
    try {
      final response = await state.apiService.get(
        '/delivery/location/${order.id}',
        token: state.token,
      );
      if (!mounted) return;
      if (response is Map<String, dynamic>) {
        setState(() {
          _latitude = (response['latitude'] as num?)?.toDouble();
          _longitude = (response['longitude'] as num?)?.toDouble();
          _updatedAt = DateTime.tryParse(
            response['updatedAt']?.toString() ?? '',
          )?.toLocal();
          _error = null;
          _loading = false;
        });
      } else {
        setState(() {
          _latitude = null;
          _longitude = null;
          _error = null;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Live location is temporarily unavailable. We will retry automatically.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return const Scaffold(
        body: Center(child: Text('Select an active order to track delivery.')),
      );
    }

    final hasLocation = _latitude != null && _longitude != null;
    final hasUserLocation = _userLatitude != null && _userLongitude != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _OrderSummary(order: order),
                  const SizedBox(height: 16),
                  if (_loading)
                    const _MapLoadingCard()
                  else if (hasLocation || hasUserLocation)
                    _LiveMap(
                      latitude: _latitude,
                      longitude: _longitude,
                      userLatitude: _userLatitude,
                      userLongitude: _userLongitude,
                    )
                  else
                    _WaitingForLocationCard(error: _error),
                  if ((hasLocation || hasUserLocation) && hasUserLocation) ...[
                    const SizedBox(height: 8),
                    _MapLegend(showDelivery: hasLocation),
                  ],
                  const SizedBox(height: 16),
                  _DeliveryPartnerCard(
                    name:
                        order.deliveryPersonName ?? 'Delivery partner assigned',
                    updatedAt: _updatedAt,
                    tracking: hasLocation,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The delivery partner’s location updates while they are on the way. Location sharing stops after the order is delivered.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8A8A9A),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Row(
      children: [
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
                  color: Colors.black.withValues(alpha: .07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              size: 26,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Track order',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
              letterSpacing: -.4,
            ),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.location_searching_rounded,
            color: Color(0xFFE8541A),
          ),
        ),
      ],
    ),
  );
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE8541A), Color(0xFFFF7A2F)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white24,
          child: Icon(
            Icons.delivery_dining_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order ${order.displayOrderId}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your delivery partner is on the way',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LiveMap extends StatelessWidget {
  const _LiveMap({
    required this.latitude,
    required this.longitude,
    this.userLatitude,
    this.userLongitude,
  });
  final double? latitude;
  final double? longitude;
  final double? userLatitude;
  final double? userLongitude;

  @override
  Widget build(BuildContext context) {
    final point = latitude != null && longitude != null
        ? LatLng(latitude!, longitude!)
        : null;
    final userPoint = userLatitude != null && userLongitude != null
        ? LatLng(userLatitude!, userLongitude!)
        : null;
    final center = point == null
        ? userPoint!
        : userPoint == null
        ? point
        : LatLng(
            (point.latitude + userPoint.latitude) / 2,
            (point.longitude + userPoint.longitude) / 2,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 330,
        child: FlutterMap(
          key: ValueKey('$latitude,$longitude,$userLatitude,$userLongitude'),
          options: MapOptions(
            initialCenter: center,
            initialZoom: point != null && userPoint != null ? 13.5 : 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.leastaction.doormartdelivery',
            ),
            MarkerLayer(
              markers: [
                if (point != null)
                  _mapMarker(
                    point: point,
                    color: const Color(0xFFE8541A),
                    icon: Icons.delivery_dining_rounded,
                  ),
                if (userPoint != null)
                  _mapMarker(
                    point: userPoint,
                    color: const Color(0xFF2563EB),
                    icon: Icons.person_pin_circle_rounded,
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Marker _mapMarker({
  required LatLng point,
  required Color color,
  required IconData icon,
}) {
  return Marker(
    point: point,
    width: 58,
    height: 58,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 10),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 29),
    ),
  );
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.showDelivery});

  final bool showDelivery;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showDelivery) ...[
          _LegendItem(color: Color(0xFFE8541A), label: 'Delivery person'),
          SizedBox(width: 16),
        ],
        _LegendItem(color: Color(0xFF2563EB), label: 'Your live location'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MapLoadingCard extends StatelessWidget {
  const _MapLoadingCard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 330,
    child: Center(child: CircularProgressIndicator(color: Color(0xFFE8541A))),
  );
}

class _WaitingForLocationCard extends StatelessWidget {
  const _WaitingForLocationCard({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) => Container(
    height: 250,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF1F1F1)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.location_searching_rounded,
          size: 46,
          color: Color(0xFFE8541A),
        ),
        const SizedBox(height: 14),
        const Text(
          'Waiting for live location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          error ??
              'Your delivery partner’s map will appear once they start the delivery.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8A8A9A), height: 1.4),
        ),
      ],
    ),
  );
}

class _DeliveryPartnerCard extends StatelessWidget {
  const _DeliveryPartnerCard({
    required this.name,
    required this.updatedAt,
    required this.tracking,
  });
  final String name;
  final DateTime? updatedAt;
  final bool tracking;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF1F1F1)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFFFF0EB),
          child: Icon(Icons.person_rounded, color: Color(0xFFE8541A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                updatedAt == null
                    ? 'Location will update soon'
                    : 'Updated ${_time(updatedAt!)}',
                style: const TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(
          tracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
          color: tracking ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
        ),
      ],
    ),
  );

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}
