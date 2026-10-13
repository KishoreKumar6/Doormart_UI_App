import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/delivery_order_model.dart';
import '../providers/delivery_provider.dart';
import 'delivery_home_screen.dart';
import 'delivery_history_screen.dart';
import 'delivery_profile_screen.dart';
import '../../../widgets/toast_widget.dart';

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});
  static const routeName = '/delivery/active-order';

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final TextEditingController _otpController = TextEditingController();
  String? _otpError;
  bool _otpVerified = false;
  bool _markingPickedUp = false;
  bool _markingDelivered = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp(DeliveryOrderModel order) {
    final entered = _otpController.text.trim();
    if (entered.isEmpty) {
      setState(() {
        _otpVerified = false;
        _otpError = 'Enter OTP first';
      });
      return;
    }

    final expected = order.deliveryOtpDisplay;
    if (entered == expected) {
      setState(() {
        _otpVerified = true;
        _otpError = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP matched successfully')));
      return;
    }

    setState(() {
      _otpVerified = false;
      _otpError = 'OTP does not match';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OTP does not match')));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final provider = context.watch<DeliveryProvider>();
    final order = provider.activeOrder;
    if (order == null) {
      return Scaffold(
        backgroundColor: Color(0xFFF6F7FB),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
                border: Border.all(color: const Color(0xFFF0F2F5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0EB),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.inbox_rounded,
                      size: 44,
                      color: Color(0xFFE8541A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'There is no active orders',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New delivery requests will appear here once assigned.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final status = _statusLabel(order.status);
    final isCod = order.isCod;
    final canEnterOtp =
        order.status == DeliveryOrderStatus.pickedUp ||
        order.status == DeliveryOrderStatus.outForDelivery ||
        order.status == DeliveryOrderStatus.delivered;
    final pickupFlowColor =
        order.status == DeliveryOrderStatus.packed ||
            order.status == DeliveryOrderStatus.pickedUp ||
            order.status == DeliveryOrderStatus.outForDelivery ||
            order.status == DeliveryOrderStatus.delivered
        ? const Color(0xFFE8541A)
        : const Color(0xFFD1D5DB);
    final otpMatches =
        _otpVerified && _otpController.text.trim() == order.deliveryOtpDisplay;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8541A), Color(0xFFFF7A2F)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Back',
                        ),
                        const Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Active Order',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        _statusPill(status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Track and complete the assigned delivery.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.receipt_long_rounded,
                            label: 'Order ID',
                            value: order.displayOrderId,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.storefront_rounded,
                            label: 'Store',
                            value:
                                order.vendorStoreName?.trim().isNotEmpty == true
                                ? order.vendorStoreName!.trim()
                                : 'Vendor store',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                child: Column(
                  children: [
                    _DashboardCard(
                      title: 'Vendor Details',
                      child: Column(
                        children: [
                          _infoRow(
                            'Store name',
                            order.vendorStoreName?.trim().isNotEmpty == true
                                ? order.vendorStoreName!.trim()
                                : '—',
                          ),
                          _infoRow('Pickup address', _fullVendorAddress(order)),
                          if (order.vendorLatitude != null &&
                              order.vendorLongitude != null)
                            _infoRow(
                              'Coordinates',
                              '${order.vendorLatitude!.toStringAsFixed(6)}, ${order.vendorLongitude!.toStringAsFixed(6)}',
                            ),
                          _infoRow(
                            'Store phone',
                            order.vendorPhone?.trim().isNotEmpty == true
                                ? order.vendorPhone!.trim()
                                : '—',
                          ),
                          const SizedBox(height: 4),
                          _MapActionButton(
                            label: 'Get Vendor Directions',
                            subtitle: 'Open turn-by-turn vendor navigation',
                            icon: Icons.store_mall_directory_rounded,
                            onPressed:
                                order.vendorLatitude != null &&
                                        order.vendorLongitude != null ||
                                    _hasAddress(_fullVendorAddress(order))
                                ? () => _openDirections(
                                    address: _fullVendorAddress(order),
                                    latitude: order.vendorLatitude,
                                    longitude: order.vendorLongitude,
                                    conflictLatitude: order.customerLatitude,
                                    conflictLongitude: order.customerLongitude,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DashboardCard(
                      title: 'Deliver to customer',
                      child: Column(
                        children: [
                          _infoRow('Customer name', order.customerName),
                          _infoRow('Customer phone', order.customerPhone),
                          _infoRow(
                            'Delivery address',
                            _fullCustomerAddress(order),
                          ),
                          if (order.customerLatitude != null &&
                              order.customerLongitude != null)
                            _infoRow(
                              'Map pin',
                              '${order.customerLatitude!.toStringAsFixed(6)}, ${order.customerLongitude!.toStringAsFixed(6)}',
                            ),
                          const SizedBox(height: 4),
                          _MapActionButton(
                            label: 'Get Customer Directions',
                            subtitle: 'Open turn-by-turn delivery navigation',
                            icon: Icons.map_outlined,
                            onPressed:
                                order.customerLatitude != null &&
                                        order.customerLongitude != null ||
                                    _hasAddress(_fullCustomerAddress(order))
                                ? () => _openDirections(
                                    address: _fullCustomerAddress(order),
                                    latitude: order.customerLatitude,
                                    longitude: order.customerLongitude,
                                    conflictLatitude: order.vendorLatitude,
                                    conflictLongitude: order.vendorLongitude,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DashboardCard(
                      title: 'Payment summary',
                      child: Column(
                        children: [
                          _infoRow('Payment method', order.paymentType),
                          if (isCod)
                            _infoRow(
                              'Collect from customer',
                              '₹${order.codAmount?.toStringAsFixed(2) ?? order.totalAmount.toStringAsFixed(2)}',
                            ),
                          _infoRow(
                            'Order total',
                            '₹${order.totalAmount.toStringAsFixed(2)}',
                          ),
                          _infoRow('Placed at', _formatDate(order.createdAt)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DashboardCard(
                      title: 'Ordered Items',
                      child: order.items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No item details available'),
                            )
                          : Column(
                              children: order.items
                                  .map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _OrderedItemTile(item: item),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _DashboardCard(
                      title: 'Delivery steps',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FlowIntro(
                              subtitle:
                                  'Complete the delivery in this order: pick up from the vendor, then deliver to the customer.',
                              highlight: pickupFlowColor,
                            ),
                            const SizedBox(height: 14),
                            _FlowActionTile(
                              step: '1',
                              icon: Icons.store_mall_directory_rounded,
                              title: 'Go to vendor',
                              subtitle: 'Open directions to collect the order',
                              accent: const Color(0xFFFF8A3D),
                              onTap:
                                  order.vendorLatitude != null &&
                                          order.vendorLongitude != null ||
                                      _hasAddress(_fullVendorAddress(order))
                                  ? () => _openDirections(
                                      address: _fullVendorAddress(order),
                                      latitude: order.vendorLatitude,
                                      longitude: order.vendorLongitude,
                                      conflictLatitude: order.customerLatitude,
                                      conflictLongitude:
                                          order.customerLongitude,
                                    )
                                  : null,
                              disabledLabel: 'Vendor address not available',
                            ),
                            const SizedBox(height: 10),
                            _FlowArrow(color: pickupFlowColor),
                            const SizedBox(height: 10),
                            _FlowActionTile(
                              step: '2',
                              icon: Icons.inventory_2_outlined,
                              title: 'Confirm pickup',
                              subtitle:
                                  'Tap after collecting the order from the vendor',
                              accent: const Color(0xFFFFB366),
                              onTap: () async {
                                if (_markingPickedUp) return;
                                setState(() => _markingPickedUp = true);
                                final message = await provider.markPickedUp();
                                if (!context.mounted) return;
                                setState(() => _markingPickedUp = false);
                                if (message == null) {
                                  showToast(
                                    context,
                                    'Order marked as picked up',
                                  );
                                } else if (message.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              },
                              loading: _markingPickedUp,
                            ),
                            const SizedBox(height: 10),
                            _FlowArrow(color: pickupFlowColor),
                            const SizedBox(height: 10),
                            _FlowActionTile(
                              step: '3',
                              icon: Icons.map_outlined,
                              title: 'Go to customer',
                              subtitle:
                                  'Open directions to the delivery address',
                              accent: const Color(0xFFFFA142),
                              onTap:
                                  order.customerLatitude != null &&
                                          order.customerLongitude != null ||
                                      _hasAddress(_fullCustomerAddress(order))
                                  ? () => _openDirections(
                                      address: _fullCustomerAddress(order),
                                      latitude: order.customerLatitude,
                                      longitude: order.customerLongitude,
                                      conflictLatitude: order.vendorLatitude,
                                      conflictLongitude: order.vendorLongitude,
                                    )
                                  : null,
                              disabledLabel: 'Customer address not available',
                            ),
                            const SizedBox(height: 10),
                            _FlowArrow(color: pickupFlowColor),
                            const SizedBox(height: 10),
                            _OtpFlowCard(
                              step: '4',
                              title: 'Verify delivery OTP',
                              subtitle: canEnterOtp
                                  ? 'Enter the OTP when the order is ready to complete delivery.'
                                  : 'Update the order to In transit first, then the OTP field becomes active.',
                              canEnterOtp: canEnterOtp,
                              controller: _otpController,
                              errorText: _otpError,
                              onChanged: () {
                                if (!canEnterOtp) return;
                                setState(() {
                                  _otpError = null;
                                  _otpVerified = false;
                                });
                              },
                              onVerify: () => _verifyOtp(order),
                            ),
                            const SizedBox(height: 10),
                            _FlowArrow(color: pickupFlowColor),
                            const SizedBox(height: 10),
                            _FlowActionTile(
                              step: '5',
                              icon: Icons.local_shipping_rounded,
                              title: 'Mark Delivered',
                              subtitle:
                                  'Finish the order only after OTP is verified',
                              accent: const Color(0xFFE8541A),
                              isPrimary: true,
                              onTap: otpMatches && !_markingDelivered
                                  ? () async {
                                      setState(() => _markingDelivered = true);
                                      final message = await provider
                                          .markDelivered(_otpController.text);
                                      if (!context.mounted) return;
                                      setState(() => _markingDelivered = false);
                                      if (message == null) {
                                        showToast(
                                          context,
                                          'Order delivered successfully',
                                        );
                                      } else if (message.isNotEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      }
                                    }
                                  : null,
                              disabled: !otpMatches,
                              loading: _markingDelivered,
                              disabledLabel: _markingDelivered
                                  ? 'Delivering...'
                                  : _otpVerified
                                  ? 'Ready to deliver'
                                  : 'Verify OTP first',
                              onDisabledTap: () {
                                setState(() {
                                  _otpError = 'OTP does not match';
                                });
                              },
                            ),
                          ],
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
      bottomNavigationBar: _BottomNav(
        index: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              DeliveryHistoryScreen.routeName,
              (route) => route.isFirst,
            );
          } else if (i == 3) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              DeliveryProfileScreen.routeName,
              (route) => route.isFirst,
            );
          } else if (i == 0) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              DeliveryHomeScreen.routeName,
              (route) => route.isFirst,
            );
          }
        },
      ),
    );
  }

  Widget _statusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(DeliveryOrderStatus status) {
    return switch (status) {
      DeliveryOrderStatus.waitingForAccept => 'Waiting',
      DeliveryOrderStatus.accepted => 'Accepted',
      DeliveryOrderStatus.packed => 'Processing',
      DeliveryOrderStatus.pickedUp => 'Picked up',
      DeliveryOrderStatus.outForDelivery => 'Out for delivery',
      DeliveryOrderStatus.delivered => 'Delivered',
      DeliveryOrderStatus.rejected => 'Rejected',
    };
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute';
  }

  Future<void> _openDirections({
    required String address,
    double? latitude,
    double? longitude,
    double? conflictLatitude,
    double? conflictLongitude,
  }) async {
    final hasUsableAddress = _hasAddress(address);
    final hasCoordinates = latitude != null && longitude != null;
    final coordinatesMatchOtherParty =
        hasCoordinates &&
        conflictLatitude != null &&
        conflictLongitude != null &&
        _coordinatesClose(
          latitude,
          longitude,
          conflictLatitude,
          conflictLongitude,
        );
    final useCoordinates =
        hasCoordinates && (!coordinatesMatchOtherParty || !hasUsableAddress);
    final destination = useCoordinates
        ? '$latitude,$longitude'
        : Uri.encodeComponent(hasUsableAddress ? address.trim() : '');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    if (kIsWeb) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }

    final appUri = switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse(
        'google.navigation:q=$destination&mode=d',
      ),
      TargetPlatform.iOS => Uri.parse(
        'comgooglemaps://?daddr=$destination&directionsmode=driving',
      ),
      _ => webUri,
    };

    if (appUri != webUri && await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  bool _hasAddress(String? address) {
    final trimmed = (address ?? '').trim();
    return trimmed.isNotEmpty && trimmed != '—';
  }

  bool _coordinatesClose(double lat1, double lng1, double lat2, double lng2) {
    return (lat1 - lat2).abs() < 0.0001 && (lng1 - lng2).abs() < 0.0001;
  }

  String _fullVendorAddress(DeliveryOrderModel order) {
    final pickupAddress = order.vendorPickupAddress?.trim() ?? '';
    final primary = pickupAddress.isNotEmpty
        ? pickupAddress
        : (order.vendorAddress ?? '').trim();
    final address = _cleanAddressParts([
      primary,
      order.vendorCity ?? '',
      order.vendorState ?? '',
      order.vendorPincode ?? '',
    ]);
    return address.isEmpty ? '—' : address;
  }

  String _cleanAddressParts(List<String> values) {
    String key(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final cleaned = <String>[];
    final parts = values
        .expand((value) => value.split(','))
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

  String _fullCustomerAddress(DeliveryOrderModel order) {
    final address = _cleanAddressParts([
      order.customerLine1 ?? '',
      order.customerArea,
      order.customerLandmark ?? '',
      order.customerCity ?? '',
      order.customerState ?? '',
      order.customerPincode ?? '',
      order.customerAddress,
    ]);
    return address.isEmpty ? '—' : address;
  }
}

class _FlowIntro extends StatelessWidget {
  const _FlowIntro({required this.subtitle, required this.highlight});

  final String subtitle;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFDFC8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  highlight.withValues(alpha: 0.95),
                  const Color(0xFFE8541A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: highlight.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(Icons.alt_route_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery flow',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBDD),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFFD2B5)),
            ),
            child: Text(
              '1 → 5',
              style: TextStyle(
                color: const Color(0xFFE8541A),
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

class _FlowArrow extends StatelessWidget {
  const _FlowArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: color.withValues(alpha: 0.5),
              thickness: 1.6,
              height: 0,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFFE8541A),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: color.withValues(alpha: 0.5),
              thickness: 1.6,
              height: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowActionTile extends StatelessWidget {
  const _FlowActionTile({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.isPrimary = false,
    this.disabled = false,
    this.disabledLabel,
    this.onDisabledTap,
    this.loading = false,
  });

  final String step;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool disabled;
  final String? disabledLabel;
  final VoidCallback? onDisabledTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !disabled && !loading;
    return InkWell(
      onTap: disabled ? onDisabledTap : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFFFF0E8) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFFFB98F)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent,
                    isPrimary
                        ? const Color(0xFFE8541A)
                        : accent.withValues(alpha: 0.78),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(child: Icon(icon, color: Colors.white, size: 26)),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        step,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (disabledLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      disabledLabel!,
                      style: TextStyle(
                        color: enabled
                            ? const Color(0xFF6B7280)
                            : const Color(0xFFE8541A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  loading
                      ? Icons.hourglass_top_rounded
                      : disabled
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_rounded,
                  color: loading
                      ? const Color(0xFFE8541A)
                      : disabled
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFE8541A),
                  size: 20,
                ),
                if (isPrimary) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDCC8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Final',
                      style: TextStyle(
                        color: Color(0xFFE8541A),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpFlowCard extends StatelessWidget {
  const _OtpFlowCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.canEnterOtp,
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onVerify,
  });

  final String step;
  final String title;
  final String subtitle;
  final bool canEnterOtp;
  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFDCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFB366), Color(0xFFE8541A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Color(0xFFE8541A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: canEnterOtp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              counterText: '',
              hintText: canEnterOtp
                  ? 'Enter OTP to verify'
                  : 'OTP unlocks after the order is updated',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: Color(0xFFFFA142)),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canEnterOtp ? onVerify : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE8541A),
                side: const BorderSide(color: Color(0xFFFFA142)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Verify OTP',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            foregroundColor: enabled
                ? const Color(0xFFE8541A)
                : const Color(0xFF9CA3AF),
            side: BorderSide(
              color: enabled
                  ? const Color(0xFFE8541A)
                  : const Color(0xFFD1D5DB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFFFFF0EB)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? const Color(0xFFE8541A)
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: enabled
                    ? const Color(0xFFE8541A)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.grid_view_rounded, 'Home'),
      (Icons.history_rounded, 'History'),
      (Icons.account_balance_wallet_rounded, 'Earnings'),
      (Icons.person_rounded, 'Profile'),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE8541A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          item.$1,
                          size: 22,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? const Color(0xFFE8541A)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD2C0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE8541A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _OrderedItemTile extends StatelessWidget {
  const _OrderedItemTile({required this.item});

  final DeliveryOrderItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final hasPrice = item.unitPrice > 0;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(18),
            ),
            child: Container(
              width: 72,
              height: 72,
              color: const Color(0xFFFFF0EB),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFFE8541A),
                      ),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                      color: Color(0xFFE8541A),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasPrice
                        ? 'Qty: ${item.quantity}  •  ₹${item.unitPrice.toStringAsFixed(2)} each'
                        : 'Qty: ${item.quantity}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(
                        label: 'Item total',
                        value: hasPrice
                            ? '₹${item.lineTotal.toStringAsFixed(2)}'
                            : '—',
                      ),
                      const SizedBox(width: 10),
                      _Badge(label: 'Ordered', value: '${item.quantity}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE8541A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
