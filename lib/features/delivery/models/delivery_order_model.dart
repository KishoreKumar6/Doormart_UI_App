import '../../../core/utils/network_image_url.dart';

enum DeliveryOrderStatus {
  waitingForAccept,
  accepted,
  packed,
  pickedUp,
  outForDelivery,
  delivered,
  rejected,
}

class DeliveryOrderItem {
  const DeliveryOrderItem({
    required this.imageUrl,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String imageUrl;
  final String name;
  final int quantity;
  final double unitPrice;

  double get lineTotal => unitPrice * quantity;

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    final rawPrice =
        json['price'] ?? json['unitPrice'] ?? json['amount'] ?? json['rate'];
    return DeliveryOrderItem(
      imageUrl: NetworkImageUrl.normalize(json['imageUrl'] as String?),
      name: json['name'] as String? ?? 'Item',
      quantity: (json['quantity'] as num? ?? 1).toInt(),
      unitPrice: rawPrice is num ? rawPrice.toDouble() : 0,
    );
  }
}

class DeliveryOrderModel {
  const DeliveryOrderModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerArea,
    required this.items,
    required this.totalAmount,
    required this.paymentType,
    required this.status,
    required this.createdAt,
    this.customerLine1,
    this.customerLandmark,
    this.customerCity,
    this.customerState,
    this.customerPincode,
    this.vendorStoreName,
    this.vendorAddress,
    this.vendorPickupAddress,
    this.vendorCity,
    this.vendorState,
    this.vendorPincode,
    this.vendorPhone,
    this.customerLatitude,
    this.customerLongitude,
    this.vendorLatitude,
    this.vendorLongitude,
    this.codAmount,
    this.orderId,
    this.deliveryEarning,
    this.deliveredAt,
    this.deliveryOtp,
    this.deliveryFee = 0.0,
    this.gstAmount = 0.0,
  });

  final String id;
  final String? orderId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String customerArea;
  final String? customerLine1;
  final String? customerLandmark;
  final String? customerCity;
  final String? customerState;
  final String? customerPincode;
  final List<DeliveryOrderItem> items;
  final double totalAmount;
  final double deliveryFee;
  final double gstAmount;
  final String paymentType;
  final DeliveryOrderStatus status;
  final DateTime createdAt;
  final String? vendorStoreName;
  final String? vendorAddress;
  final String? vendorPickupAddress;
  final String? vendorCity;
  final String? vendorState;
  final String? vendorPincode;
  final String? vendorPhone;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? vendorLatitude;
  final double? vendorLongitude;
  final DateTime? deliveredAt;
  final double? codAmount;
  final double? deliveryEarning;
  final String? deliveryOtp;

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);
  double get itemSubtotal => items.fold<double>(
    0,
    (sum, item) => sum + item.lineTotal,
  );
  bool get isCod => paymentType.toLowerCase() == 'cod';
  String get displayOrderId {
    final source = (orderId ?? id)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    if (source.isEmpty) return 'DMD-000-000';

    final tail = source.length >= 6
        ? source.substring(source.length - 6)
        : source.padLeft(6, '0');
    final first = tail.substring(0, 3);
    final second = tail.substring(3, 6);
    return 'DMD-$first-$second';
  }

  String get deliveryOtpDisplay {
    if ((deliveryOtp ?? '').isNotEmpty) return deliveryOtp!;
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length >= 6
        ? digits.substring(digits.length - 6)
        : digits.padLeft(6, '0');
    return tail;
  }

  factory DeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    final itemsJson =
        (json['items'] as List<dynamic>? ??
                json['products'] as List<dynamic>? ??
                [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final user = json['user'];
    final userMap = user is Map<String, dynamic> ? user : null;
    final address = json['address'];
    final addressMap = address is Map<String, dynamic> ? address : null;
    final addressText =
        [
              addressMap?['line1'] ??
                  addressMap?['addressLine1'] ??
                  addressMap?['street'],
              addressMap?['area'],
              addressMap?['landmark'],
              addressMap?['city'],
              addressMap?['state'],
              addressMap?['pincode'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .map((part) => part.toString().trim())
            .join(', ');
    final addressLocation = _extractLocation(addressMap?['location']);

    return DeliveryOrderModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? json['order_id'] as String?,
      customerName:
          json['customerName'] as String? ??
          userMap?['name'] as String? ??
          json['userName'] as String? ??
          'Customer',
      customerPhone:
          json['customerPhone'] as String? ??
          userMap?['phone'] as String? ??
          json['phone'] as String? ??
          '',
      customerAddress:
          json['customerAddress'] as String? ??
          (addressText.isNotEmpty
              ? addressText
              : (json['address']?.toString() ?? '')),
      customerArea:
          json['customerArea'] as String? ??
          addressMap?['area'] as String? ??
          addressMap?['city'] as String? ??
          json['area'] as String? ??
          'Unknown area',
      customerLine1:
          json['customerLine1'] as String? ??
          addressMap?['line1'] as String? ??
          addressMap?['addressLine1'] as String? ??
          addressMap?['street'] as String?,
      customerLandmark:
          json['customerLandmark'] as String? ??
          addressMap?['landmark'] as String?,
      customerCity:
          json['customerCity'] as String? ?? addressMap?['city'] as String?,
      customerState:
          json['customerState'] as String? ?? addressMap?['state'] as String?,
      customerPincode:
          json['customerPincode'] as String? ??
          addressMap?['pincode'] as String?,
      items: itemsJson.map(DeliveryOrderItem.fromJson).toList(),
      totalAmount: (json['totalAmount'] as num? ?? json['total'] as num? ?? 0)
          .toDouble(),
      paymentType:
          json['paymentType'] as String? ??
          json['paymentMethod'] as String? ??
          json['payment_method'] as String? ??
          'Online',
      status: _statusFromJson(json['status'] as String?),
      createdAt:
          _parseDate(
            json['createdAt'] as String? ?? json['dateTime'] as String? ?? '',
          ) ??
          DateTime.now(),
      vendorStoreName: json['vendorStoreName'] as String?,
      vendorAddress: json['vendorAddress'] as String?,
      vendorPickupAddress: json['vendorPickupAddress'] as String?,
      vendorCity: json['vendorCity'] as String?,
      vendorState: json['vendorState'] as String?,
      vendorPincode: json['vendorPincode'] as String?,
      vendorPhone: json['vendorPhone'] as String?,
      customerLatitude:
          _asDouble(json['customerLatitude']) ?? addressLocation?.latitude,
      customerLongitude:
          _asDouble(json['customerLongitude']) ?? addressLocation?.longitude,
      vendorLatitude: _asDouble(json['vendorLatitude']),
      vendorLongitude: _asDouble(json['vendorLongitude']),
      deliveredAt: _parseDate(
        json['deliveredAt'] as String? ??
            json['completedAt'] as String? ??
            json['deliveryCompletedAt'] as String? ??
            '',
      ),
      codAmount: (json['codAmount'] as num?)?.toDouble(),
      deliveryEarning: (json['deliveryEarning'] as num?)?.toDouble(),
      deliveryOtp: json['deliveryOtp'] as String?,
      deliveryFee: (json['deliveryFee'] as num? ?? json['delivery_fee'] as num? ?? 0).toDouble(),
      gstAmount: (json['gstAmount'] as num? ?? json['gst_amount'] as num? ?? 0).toDouble(),
    );
  }
}

class _LocationPoint {
  const _LocationPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

_LocationPoint? _extractLocation(dynamic value) {
  if (value is! Map<String, dynamic>) return null;
  final latitude = _asDouble(value['latitude'] ?? value['lat']);
  final longitude = _asDouble(
    value['longitude'] ?? value['lng'] ?? value['lon'],
  );
  if (latitude == null || longitude == null) return null;
  return _LocationPoint(latitude: latitude, longitude: longitude);
}

DeliveryOrderStatus _statusFromJson(String? value) {
  return switch (value) {
    'WAITING_FOR_ACCEPT' ||
    'waiting_for_accept' ||
    'placed' => DeliveryOrderStatus.waitingForAccept,
    'ACCEPTED' || 'accepted' => DeliveryOrderStatus.accepted,
    'packed' || 'PACKED' => DeliveryOrderStatus.packed,
    'PICKED_UP' || 'picked_up' => DeliveryOrderStatus.pickedUp,
    'OUT_FOR_DELIVERY' ||
    'out_for_delivery' => DeliveryOrderStatus.outForDelivery,
    'DELIVERED' || 'delivered' => DeliveryOrderStatus.delivered,
    'REJECTED' || 'rejected' => DeliveryOrderStatus.rejected,
    _ => DeliveryOrderStatus.waitingForAccept,
  };
}
