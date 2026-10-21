import 'product_model.dart';

enum OrderStatus {
  placed,
  accepted,
  packed,
  assigned,
  deliveryAccepted,
  pickedUp,
  outForDelivery,
  delivered,
  cancelled,
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.products,
    required this.quantities,
    required this.paymentMethod,
    required this.total,
    required this.status,
    required this.createdAt,
    this.vendorId = 'main',
    this.scheduledFor,
    this.address = '',
    this.customerName = '',
    this.customerAddress = '',
    this.customerPhone = '',
    this.deliveryPersonId,
    this.deliveryPersonName,
    this.deliveryPersonPhone,
    this.deliveryAcceptedAt,
    this.acceptedAt,
    this.deliveredAt,
    this.deliveryOtp,
    this.completionReason = '',
    this.deliveryFee = 0.0,
    this.gstAmount = 0.0,
    this.vendorStoreName = '',
  });

  final String id;
  final List<ProductModel> products;
  final List<int> quantities;
  final String paymentMethod;
  final double total;
  final double deliveryFee;
  final double gstAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String vendorId;
  final DateTime? scheduledFor;
  final String address;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String? deliveryPersonId;
  final String? deliveryPersonName;
  final String? deliveryPersonPhone;
  final DateTime? deliveryAcceptedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final String? deliveryOtp;
  final String completionReason;
  final String vendorStoreName;

  String get displayOrderId {
    final source = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (source.isEmpty) return 'DMD-000-000';

    final tail = source.length >= 6
        ? source.substring(source.length - 6)
        : source.padLeft(6, '0');
    final first = tail.substring(0, 3);
    final second = tail.substring(3, 6);
    return 'DMD-$first-$second';
  }

  String get orderNumber => displayOrderId;

  String get deliveryOtpDisplay {
    if ((deliveryOtp ?? '').isNotEmpty) return deliveryOtp!;
    return id
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(
          id.replaceAll(RegExp(r'[^0-9]'), '').length >= 6
              ? id.replaceAll(RegExp(r'[^0-9]'), '').length - 6
              : 0,
        )
        .padLeft(6, '0');
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final productsJson = (json['products'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final deliveryPerson = json['deliveryPerson'];
    final assignedDeliveryPerson = json['assignedDeliveryPerson'];
    final rawDeliveryPerson = deliveryPerson is Map<String, dynamic>
        ? deliveryPerson
        : assignedDeliveryPerson is Map<String, dynamic>
        ? assignedDeliveryPerson
        : deliveryPerson ?? assignedDeliveryPerson;
    final deliveryPersonMap = rawDeliveryPerson is Map<String, dynamic>
        ? rawDeliveryPerson
        : null;
    final rawId = json['_id'] ?? json['id'] ?? '';
    final rawAddress = json['address'];
    final addressMap = rawAddress is Map
        ? Map<String, dynamic>.from(rawAddress)
        : null;
    final structuredAddress = _cleanAddressParts([
      addressMap?['line1'],
      addressMap?['area'],
      addressMap?['landmark'],
      addressMap?['city'],
      addressMap?['state'],
      addressMap?['pincode'],
    ]);
    final addressText = rawAddress is String
        ? rawAddress
        : addressMap != null
        ? _cleanAddressParts([
            addressMap['line1'],
            addressMap['city'],
            addressMap['pincode'],
          ])
        : '';

    return OrderModel(
      id: rawId?.toString() ?? '',
      products: productsJson
          .map(
            (item) => ProductModel(
              id:
                  item['productId']?.toString() ??
                  item['product']?.toString() ??
                  '',
              name: item['name']?.toString() ?? 'Product',
              category: item['category']?.toString() ?? 'Grocery',
              price: (item['price'] as num? ?? 0).toDouble(),
              cost: 0,
              stock: 0,
              imageUrl: item['imageUrl']?.toString() ?? '',
              unit: item['unit']?.toString() ?? 'item',
            ),
          )
          .toList(),
      quantities: productsJson
          .map((item) => (item['quantity'] as num? ?? 1).toInt())
          .toList(),
      paymentMethod:
          (json['paymentMethod'] ??
                  json['paymentType'] ??
                  json['paymentMode'] ??
                  'cod')
              .toString()
              .toLowerCase(),
      total: (json['total'] as num? ?? 0).toDouble(),
      status: _statusFromJson(json['status']?.toString()),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      vendorId: json['vendorId']?.toString() ?? 'main',
      scheduledFor: _parseDateTime(json['scheduledFor']),
      address: addressText,
      customerName: json['customerName']?.toString() ?? '',
      customerAddress: structuredAddress.isNotEmpty
          ? structuredAddress
          : json['customerAddress']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      deliveryPersonId: deliveryPersonMap == null
          ? rawDeliveryPerson?.toString()
          : deliveryPersonMap['_id']?.toString() ??
                deliveryPersonMap['id']?.toString(),
      deliveryPersonName: deliveryPersonMap?['name']?.toString(),
      deliveryPersonPhone:
          deliveryPersonMap?['phone']?.toString() ??
          json['deliveryPersonPhone']?.toString(),
      deliveryAcceptedAt: _parseDateTime(json['deliveryAcceptedAt']),
      acceptedAt: _parseDateTime(json['acceptedAt']),
      deliveredAt: _parseDateTime(json['deliveredAt']),
      deliveryOtp: json['deliveryOtp']?.toString(),
      completionReason: json['completionReason']?.toString() ?? '',
      deliveryFee:
          (json['deliveryFee'] as num? ?? json['delivery_fee'] as num? ?? 0)
              .toDouble(),
      gstAmount: (json['gstAmount'] as num? ?? json['gst_amount'] as num? ?? 0)
          .toDouble(),
      vendorStoreName: json['vendorStoreName']?.toString() ?? '',
    );
  }
}

String _cleanAddressParts(List<dynamic> values) {
  final result = <String>[];
  for (final value in values) {
    final parts =
        value
            ?.toString()
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty) ??
        const <String>[];
    for (final part in parts) {
      final normalized = part.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (!result.any(
        (existing) =>
            existing.toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
            normalized,
      )) {
        result.add(part);
      }
    }
  }
  return result.join(', ');
}

DateTime? _parseDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return parsed.toLocal();
}

OrderStatus _statusFromJson(String? status) {
  return switch (status) {
    'WAITING_FOR_ACCEPT' || 'placed' => OrderStatus.placed,
    'ACCEPTED' || 'accepted' => OrderStatus.accepted,
    'PACKED' || 'packed' => OrderStatus.packed,
    'ASSIGNED' || 'assigned' => OrderStatus.assigned,
    'DELIVERY_ACCEPTED' || 'delivery_accepted' => OrderStatus.deliveryAccepted,
    'PICKED_UP' || 'picked_up' => OrderStatus.pickedUp,
    'OUT_FOR_DELIVERY' || 'out_for_delivery' => OrderStatus.outForDelivery,
    'DELIVERED' || 'delivered' => OrderStatus.delivered,
    'CANCELLED' || 'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.placed,
  };
}
