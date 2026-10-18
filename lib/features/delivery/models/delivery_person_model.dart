class DeliveryPersonModel {
  const DeliveryPersonModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleNumber,
    required this.status,
    required this.isOnline,
    required this.active,
    required this.completedOrders,
    required this.todayEarnings,
    this.vendorId = 'main',
    this.avatarUrl,
    this.panNumber = '',
    this.panCardUrl,
    this.licenseNumber = '',
    this.licenseCardUrl,
    this.aadhaarNumber = '',
    this.aadhaarCardUrl,
    this.initialPaymentStatus = 'NOT_PAID',
    this.isPaymentRequired = true,
    this.initialPaymentAmount = 0.0,
    this.initialPaymentCompletedAt,
    this.initialPaymentMethod,
    this.initialPaymentReference,
    this.initialPaymentSource,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicleNumber;
  final String status;
  final bool isOnline;
  final bool active;
  final int completedOrders;
  final double todayEarnings;
  final String vendorId;
  final String? avatarUrl;
  final String panNumber;
  final String? panCardUrl;
  final String licenseNumber;
  final String? licenseCardUrl;
  final String aadhaarNumber;
  final String? aadhaarCardUrl;
  final String initialPaymentStatus;
  final bool isPaymentRequired;
  final double initialPaymentAmount;
  final DateTime? initialPaymentCompletedAt;
  final String? initialPaymentMethod;
  final String? initialPaymentReference;
  final String? initialPaymentSource;

  bool get isInitialPaymentPaid =>
      initialPaymentStatus.trim().toUpperCase() == 'PAID';
  bool get isInitialPaymentPending => !isInitialPaymentPaid;

  factory DeliveryPersonModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'offline';
    final initialPaymentStatus =
        json['initialPaymentStatus'] as String? ?? 'NOT_PAID';
    final isPaymentRequired =
        json['isPaymentRequired'] as bool? ??
        (initialPaymentStatus.trim().toUpperCase() != 'PAID');
    final rawCompletedAt = json['initialPaymentCompletedAt'] as String?;

    return DeliveryPersonModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Delivery Person',
      phone: json['phone'] as String? ?? '',
      vehicleNumber:
          json['vehicleNumber'] as String? ??
          json['vehicle_number'] as String? ??
          '',
      status: status,
      isOnline: json['isOnline'] as bool? ?? (status.toLowerCase() == 'online'),
      active: json['active'] as bool? ?? true,
      completedOrders:
          (json['completedOrders'] as num? ??
                  json['todayCompletedOrders'] as num? ??
                  0)
              .toInt(),
      todayEarnings: (json['todayEarnings'] as num? ?? 0).toDouble(),
      vendorId: json['vendorId'] as String? ?? 'main',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar'] as String?,
      panNumber: json['panNumber'] as String? ?? '',
      panCardUrl: json['panCardUrl'] as String?,
      licenseNumber: json['licenseNumber'] as String? ?? '',
      licenseCardUrl: json['licenseCardUrl'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String? ?? '',
      aadhaarCardUrl: json['aadhaarCardUrl'] as String?,
      initialPaymentStatus: initialPaymentStatus,
      isPaymentRequired: isPaymentRequired,
      initialPaymentAmount: (json['initialPaymentAmount'] as num? ?? 0)
          .toDouble(),
      initialPaymentCompletedAt: rawCompletedAt != null
          ? DateTime.tryParse(rawCompletedAt)
          : null,
      initialPaymentMethod: json['initialPaymentMethod'] as String?,
      initialPaymentReference: json['initialPaymentReference'] as String?,
      initialPaymentSource: json['initialPaymentSource'] as String?,
    );
  }

  DeliveryPersonModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? vehicleNumber,
    String? status,
    bool? isOnline,
    bool? active,
    int? completedOrders,
    double? todayEarnings,
    String? vendorId,
    String? avatarUrl,
    String? panNumber,
    String? panCardUrl,
    String? licenseNumber,
    String? licenseCardUrl,
    String? aadhaarNumber,
    String? aadhaarCardUrl,
    String? initialPaymentStatus,
    bool? isPaymentRequired,
    double? initialPaymentAmount,
    DateTime? initialPaymentCompletedAt,
    String? initialPaymentMethod,
    String? initialPaymentReference,
    String? initialPaymentSource,
  }) {
    return DeliveryPersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      active: active ?? this.active,
      completedOrders: completedOrders ?? this.completedOrders,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      vendorId: vendorId ?? this.vendorId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      panNumber: panNumber ?? this.panNumber,
      panCardUrl: panCardUrl ?? this.panCardUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseCardUrl: licenseCardUrl ?? this.licenseCardUrl,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      aadhaarCardUrl: aadhaarCardUrl ?? this.aadhaarCardUrl,
      initialPaymentStatus: initialPaymentStatus ?? this.initialPaymentStatus,
      isPaymentRequired: isPaymentRequired ?? this.isPaymentRequired,
      initialPaymentAmount: initialPaymentAmount ?? this.initialPaymentAmount,
      initialPaymentCompletedAt:
          initialPaymentCompletedAt ?? this.initialPaymentCompletedAt,
      initialPaymentMethod: initialPaymentMethod ?? this.initialPaymentMethod,
      initialPaymentReference:
          initialPaymentReference ?? this.initialPaymentReference,
      initialPaymentSource: initialPaymentSource ?? this.initialPaymentSource,
    );
  }
}
