import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocationService {
  static const _cachedLatitudeKey = 'cached_nearby_latitude';
  static const _cachedLongitudeKey = 'cached_nearby_longitude';
  static const _cachedAtKey = 'cached_nearby_location_at';
  static const _cacheDuration = Duration(minutes: 30);
  static ({double latitude, double longitude})? _lastNearbyLocation;

  static ({double latitude, double longitude})? get lastNearbyLocation =>
      _lastNearbyLocation;

  Future<({double latitude, double longitude})> currentLocation() async {
    return _readCurrentLocation(timeLimit: const Duration(seconds: 20));
  }

  Future<({double latitude, double longitude})> nearbyLocation() async {
    return _readCurrentLocation(timeLimit: const Duration(seconds: 20));
  }

  Future<({double latitude, double longitude})> _readCurrentLocation({
    required Duration timeLimit,
  }) async {
    // The web implementation always reports the service as enabled because
    // browsers do not expose a separate GPS-service switch. Checking it on
    // web can therefore incorrectly turn a browser permission issue into a
    // phone-GPS error.
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    // On web, requestPermission() internally calls getCurrentPosition().
    // Calling it after the Permissions API says "denied" can convert a
    // recoverable browser prompt into deniedForever. Let the browser API make
    // the request from getCurrentPosition instead.
    if (permission == LocationPermission.denied && !kIsWeb) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required');
    }

    final position = await _getCurrentPositionWithRetry(
      LocationSettings(
        // High accuracy is unreliable on some desktop browsers and can make
        // an already-allowed request time out. Android still uses high GPS
        // accuracy; web uses the browser's normal location provider.
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: timeLimit,
      ),
    );
    final latitude = position.latitude;
    final longitude = position.longitude;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw StateError('Location coordinates are invalid');
    }
    final location = (latitude: latitude, longitude: longitude);
    if (kDebugMode) {
      debugPrint(
        '[location] coordinates acquired (${kIsWeb ? 'web' : 'native'}); '
        'accuracy=${position.accuracy.toStringAsFixed(0)}m',
      );
    }
    await _cacheLocation(location);
    return location;
  }

  Future<({double latitude, double longitude})?> cachedNearbyLocation() async {
    if (_lastNearbyLocation != null) return _lastNearbyLocation;
    try {
      final preferences = await SharedPreferences.getInstance();
      final latitude = preferences.getDouble(_cachedLatitudeKey);
      final longitude = preferences.getDouble(_cachedLongitudeKey);
      final cachedAt = preferences.getInt(_cachedAtKey);
      if (latitude == null || longitude == null || cachedAt == null) {
        return null;
      }
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(cachedAt),
      );
      if (age.isNegative || age > _cacheDuration) return null;
      _lastNearbyLocation = (latitude: latitude, longitude: longitude);
      return _lastNearbyLocation;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheLocation(
    ({double latitude, double longitude}) location,
  ) async {
    _lastNearbyLocation = location;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_cachedLatitudeKey, location.latitude);
      await preferences.setDouble(_cachedLongitudeKey, location.longitude);
      await preferences.setInt(
        _cachedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // A cache failure must never prevent a valid GPS result from being used.
    }
  }

  Future<Position> _getCurrentPositionWithRetry(
    LocationSettings settings,
  ) async {
    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } catch (error) {
      final message = error.toString().toLowerCase();
      final locationStillUnknown =
          message.contains('kclerrorlocationunknown') ||
          message.contains('locationunknown') ||
          message.contains('location unknown') ||
          message.contains('position update is unavailable') ||
          message.contains('positionupdateexception');
      if (!locationStillUnknown) rethrow;

      // CoreLocation and browser GPS can report this briefly while acquiring
      // a fix. Give the provider one more chance before showing an error.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      return Geolocator.getCurrentPosition(locationSettings: settings);
    }
  }

  Future<String?> addressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async =>
      (await reverseGeocode(latitude: latitude, longitude: longitude))?.address;

  Future<({String address, String city, String state, String pincode})?>
  reverseGeocode({required double latitude, required double longitude}) async {
    if (kIsWeb) {
      final response = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '18',
          'addressdetails': '1',
        }),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['display_name']?.toString().trim();
      final raw = data['address'];
      final parts = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      if (address == null || address.isEmpty) return null;
      final areaParts =
          [
                parts['house_number'],
                parts['road'],
                parts['neighbourhood'],
                parts['suburb'],
                parts['quarter'],
                parts['residential'],
              ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toSet()
              .toList();
      return (
        address: areaParts.join(', '),
        city: (parts['city'] ?? parts['town'] ?? parts['village'] ?? '')
            .toString(),
        state: (parts['state'] ?? '').toString(),
        pincode: (parts['postcode'] ?? '').toString(),
      );
    }

    final placemarks = await Geocoding().placemarkFromCoordinates(
      latitude,
      longitude,
    );
    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    final addressParts = [place.name, place.street, place.subLocality]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList();
    if (addressParts.isEmpty) return null;
    return (
      address: addressParts.join(', '),
      city: (place.locality ?? place.subAdministrativeArea ?? '').trim(),
      state: (place.administrativeArea ?? '').trim(),
      pincode: (place.postalCode ?? '').trim(),
    );
  }
}
