class AddressModel {
  const AddressModel({
    required this.id,
    required this.label,
    required this.line1,
    required this.city,
    required this.pincode,
    this.area = '',
    this.landmark = '',
    this.state = '',
    this.latitude,
    this.longitude,
  });
  final String id;
  final String label;
  final String line1;
  final String area;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;

  String get shortAddress => '$city, $pincode';

  String get fullAddress {
    final cleaned = <String>[];
    final parts = [line1, area, landmark, city, state, pincode]
        .expand((value) => value.split(','))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    for (final part in parts) {
      final key = part.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final duplicate = cleaned.any((existing) {
        final existingKey = existing.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        return existingKey == key ||
            existingKey.contains(key) ||
            key.contains(existingKey);
      });
      if (!duplicate) cleaned.add(part);
    }
    return cleaned.join(', ');
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Address',
      line1: json['line1'] as String? ?? '',
      area: json['area'] as String? ?? json['line2'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude:
          _asDouble(json['latitude'] ?? json['lat']) ??
          _asDouble(_locationValue(json['location'], 'latitude', 'lat')),
      longitude:
          _asDouble(json['longitude'] ?? json['lng']) ??
          _asDouble(_locationValue(json['location'], 'longitude', 'lng')),
    );
  }

  Map<String, dynamic> toLocationJson() {
    return {
      if (latitude != null && longitude != null)
        'location': {'latitude': latitude, 'longitude': longitude},
    };
  }

  static dynamic _locationValue(
    dynamic location,
    String primaryKey,
    String fallbackKey,
  ) {
    if (location is Map<String, dynamic>) {
      return location[primaryKey] ?? location[fallbackKey];
    }
    return null;
  }
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
