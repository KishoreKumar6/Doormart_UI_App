import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../core/constants.dart';
import '../core/role_access.dart';
import '../core/utils/network_image_url.dart';
import '../features/operations/services/location_service.dart';
import '../models/address_model.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../models/vendor_model.dart';
import '../notifications/firebase_messaging_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/session_service.dart';

class ReorderCartResult {
  const ReorderCartResult({
    required this.addedCount,
    required this.skippedCount,
  });

  final int addedCount;
  final int skippedCount;

  bool get hasAddedItems => addedCount > 0;
}

class DeliveryChargeBreakdown {
  const DeliveryChargeBreakdown({
    required this.vendorId,
    required this.storeName,
    required this.distanceKm,
    required this.fee,
  });

  final String vendorId;
  final String storeName;
  final double distanceKm;
  final double fee;
}

class CartLine {
  CartLine({
    required this.product,
    this.quantity = 1,
    this.unit,
    this.price,
    this.discountCost,
    this.stock,
  });

  final ProductModel product;
  int quantity;
  final String? unit;
  final double? price;
  final double? discountCost;
  final int? stock;

  String get selectedUnit {
    final value = (unit ?? product.unit).trim();
    return value.isEmpty ? product.unit : value;
  }

  ProductUnitVariant? get _matchedVariant {
    final normalized = selectedUnit.toLowerCase();
    for (final variant in product.unitVariants) {
      if (variant.unit.toLowerCase() == normalized) return variant;
    }
    return null;
  }

  double get unitPrice => price ?? _matchedVariant?.price ?? product.price;
  double get unitMrp =>
      discountCost ?? _matchedVariant?.discountCost ?? product.mrp;
  int get availableStock => stock ?? _matchedVariant?.stock ?? product.stock;
  double get total => unitPrice * quantity;
  String get key => '${product.id}::${selectedUnit.toLowerCase()}';

  Map<String, dynamic> toOrderJson() => {
    'productId': product.id,
    'name': product.name,
    'quantity': quantity,
    'price': unitPrice,
    'unit': selectedUnit,
    'discountCost': unitMrp,
  };
}

class AppState extends ChangeNotifier {
  AppState({ApiService? apiService, SocketService? socketService})
    : apiService = apiService ?? ApiService(),
      socketService = socketService ?? SocketService();

  final ApiService apiService;
  final SocketService socketService;
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final SessionService _sessionService = SessionService();
  bool initialized = false;
  bool loading = false;
  String? error;
  String? token;
  UserModel? user;
  VendorModel? vendor;
  List<ProductModel> products = [];
  List<CategoryModel> categoryCatalog = [];
  List<BannerModel> banners = [];
  List<ProductModel> favorites = [];
  List<ProductModel> buyAgainProducts = [];
  List<OrderModel> orders = [];
  // Preserves every vendor split from the latest checkout for confirmation UI.
  List<OrderModel> lastCheckoutOrders = [];
  List<OrderModel> adminOrders = [];
  List<AddressModel> savedAddresses = [];
  List<Map<String, dynamic>> supportTickets = [];
  final Map<String, List<ProductReviewModel>> _productReviewsById = {};
  Set<String> reviewedProductKeys = {};
  AddressModel? selectedAddress;
  Map<String, dynamic>? checkoutSummary;
  static const double fixedDeliveryRadiusKm = 10.0;
  static double nearbyRadiusKm = fixedDeliveryRadiusKm;
  double deliveryMaxRadiusKm = fixedDeliveryRadiusKm;
  Set<String> nearbyVendorIds = const {};
  bool nearbyVendorsLoading = false;
  bool nearbyLocationUnavailable = false;
  String nearbyLocationMessage = '';
  String nearbyStoresErrorMessage = '';
  DateTime? _nearbyVendorLoadedAt;
  final List<CartLine> cart = [];
  int _cartMutationToken = 0;
  int dashboardRefreshTick = 0;
  double deliveryChargeAmount = 35;
  bool distanceBasedDelivery = false;
  double deliveryBaseDistanceKm = 2;
  double deliveryBaseCharge = 35;
  double deliveryPerKmCharge = 8;
  double gstPercent = 0;
  bool freeDeliveryEnabled = false;
  double freeDeliveryThreshold = 0;
  bool shiftChargesEnabled = false;
  double dayDeliveryCharge = 35;
  double nightDeliveryCharge = 50;
  String dayShiftStart = '22:00';
  String dayShiftEnd = '06:00';

  double get subtotal => cart.fold(0, (sum, line) => sum + line.total);

  /// Distance from the selected customer address to the farthest store in the
  /// cart. Kept for compatibility with older checkout/API payloads.
  double? cartDistanceKm(AddressModel? address) {
    final latitude = address?.latitude;
    final longitude = address?.longitude;
    if (latitude == null || longitude == null) return null;

    final distances = cart
        .map((line) {
          final storeLatitude = line.product.supplierLatitude;
          final storeLongitude = line.product.supplierLongitude;
          if (storeLatitude == null || storeLongitude == null) return null;
          return Geolocator.distanceBetween(
                storeLatitude,
                storeLongitude,
                latitude,
                longitude,
              ) /
              1000;
        })
        .whereType<double>()
        .toList();
    if (distances.isEmpty) return null;
    return distances.reduce((a, b) => a > b ? a : b);
  }

  double? distanceBasedDeliveryFee(AddressModel? address) {
    if (!distanceBasedDelivery) return null;
    final breakdown = deliveryChargeBreakdown(address);
    if (breakdown.isEmpty) return null;
    return double.parse(
      breakdown
          .fold<double>(0, (sum, entry) => sum + entry.fee)
          .toStringAsFixed(2),
    );
  }

  /// Calculates delivery independently for every store in the cart.
  /// A multi-store cart creates separate deliveries, so each store's distance
  /// and any active night surcharge must be charged separately.
  List<DeliveryChargeBreakdown> deliveryChargeBreakdown(AddressModel? address) {
    if (!distanceBasedDelivery ||
        address?.latitude == null ||
        address?.longitude == null) {
      return const [];
    }

    final distancesByVendor = <String, double>{};
    final namesByVendor = <String, String>{};
    for (final line in cart) {
      final storeLatitude = line.product.supplierLatitude;
      final storeLongitude = line.product.supplierLongitude;
      if (storeLatitude == null || storeLongitude == null) continue;
      final vendorId = line.product.vendorId.trim().isEmpty
          ? 'main'
          : line.product.vendorId.trim();
      final distance =
          Geolocator.distanceBetween(
            storeLatitude,
            storeLongitude,
            address!.latitude!,
            address.longitude!,
          ) /
          1000;
      final previous = distancesByVendor[vendorId];
      distancesByVendor[vendorId] = previous == null || distance > previous
          ? distance
          : previous;
      namesByVendor[vendorId] = line.product.supplierName.trim().isNotEmpty
          ? line.product.supplierName.trim()
          : (vendorId == 'main' ? 'Main Store' : vendorId);
    }

    final nightActive = shiftChargesEnabled && _isNightShiftNow();
    return distancesByVendor.entries.map((entry) {
      final fee =
          (entry.value * deliveryBaseCharge) +
          (nightActive ? nightDeliveryCharge : 0);
      return DeliveryChargeBreakdown(
        vendorId: entry.key,
        storeName: namesByVendor[entry.key] ?? entry.key,
        distanceKm: entry.value,
        fee: double.parse(fee.toStringAsFixed(2)),
      );
    }).toList();
  }

  bool _isNightShiftNow() {
    final istNow = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final currentMinutes = istNow.hour * 60 + istNow.minute;
    final start = _parseTimeToMinutes(dayShiftStart, 22 * 60);
    final end = _parseTimeToMinutes(dayShiftEnd, 6 * 60);
    return start < end
        ? currentMinutes >= start && currentMinutes < end
        : currentMinutes >= start || currentMinutes < end;
  }

  bool get usesProductTax => cart.isNotEmpty;
  double get productGstAmount =>
      cart.fold(0, (sum, line) => sum + line.total * (line.product.tax / 100));
  double get gstAmount => cart.isEmpty
      ? 0
      : usesProductTax
      ? productGstAmount
      : subtotal * (gstPercent / 100);
  bool get isFreeDelivery {
    if (cart.isEmpty) return false;
    return freeDeliveryEnabled &&
        (freeDeliveryThreshold <= 0 || subtotal >= freeDeliveryThreshold);
  }

  double get amountNeededForFreeDelivery =>
      (freeDeliveryEnabled &&
          freeDeliveryThreshold > 0 &&
          subtotal < freeDeliveryThreshold)
      ? (freeDeliveryThreshold - subtotal)
      : 0;
  static int _parseTimeToMinutes(String timeStr, int fallback) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (_) {}
    return fallback;
  }

  double get calculatedDeliveryFee {
    if (cart.isEmpty) return 0;
    final summaryFee =
        (checkoutSummary?['calculatedDeliveryFee'] as num?)?.toDouble() ??
        (checkoutSummary?['deliveryFee'] as num?)?.toDouble();
    if (summaryFee != null && summaryFee > 0) return summaryFee;
    if (shiftChargesEnabled) {
      return _isNightShiftNow()
          ? deliveryChargeAmount + nightDeliveryCharge
          : deliveryChargeAmount;
    }
    return deliveryChargeAmount;
  }

  double get effectiveDeliveryFee =>
      isFreeDelivery ? 0.0 : calculatedDeliveryFee;

  double get deliveryFee => effectiveDeliveryFee;
  double get total => subtotal + effectiveDeliveryFee + gstAmount;
  int get cartCount => cart.fold(0, (sum, line) => sum + line.quantity);
  int get favoritesCount => favorites.length;
  bool get hasNearbyVendorData => nearbyVendorIds.isNotEmpty;
  List<ProductModel> get nearbyProducts =>
      products.where(isProductNearUser).toList(growable: false);
  List<ProductModel> get nearbyFavorites =>
      favorites.where(isProductNearUser).toList(growable: false);
  List<CartLine> get unavailableCartLines => cart
      .where((line) => !isProductNearUser(line.product))
      .toList(growable: false);
  bool get hasUnavailableCartItems => unavailableCartLines.isNotEmpty;
  List<CartLine> get closedCartLines => cart
      .where((line) => storeStatusProduct(line.product).vendorIsOpen == false)
      .toList(growable: false);
  bool get hasClosedCartItems => closedCartLines.isNotEmpty;

  /// The most recently loaded copy of [product] that carries a definitive store
  /// open/closed status, preferring products already fetched for the home, list,
  /// wishlist and buy-again screens over a possibly stale cart/wishlist snapshot.
  ProductModel storeStatusProduct(ProductModel product) {
    final id = product.id;
    ProductModel? known;
    if (id.isNotEmpty) {
      for (final list in [products, favorites, buyAgainProducts]) {
        for (final candidate in list) {
          if (candidate.id == id && candidate.vendorIsOpen != null) {
            known = candidate;
            break;
          }
        }
        if (known != null) break;
      }
    }
    if (known == null) return product;
    // A definite "closed" from any source wins; otherwise keep the cart line's
    // own (possibly refreshed) value and only fall back to [known] when unknown.
    if (known.vendorIsOpen == false || product.vendorIsOpen == null) {
      return known;
    }
    return product;
  }

  bool get signedIn => token != null;
  String get logoutRouteName {
    switch (user?.role) {
      case UserRoles.vendor:
        return '/vendor/login';
      case UserRoles.superAdmin:
        return '/super-admin/login';
      case UserRoles.admin:
        return '/admin/login';
      case UserRoles.deliveryPerson:
        return '/delivery/login';
      case UserRoles.user:
      default:
        return '/login';
    }
  }

  bool isProductNearUser(ProductModel product) {
    final vendorId = product.vendorId.trim();
    if (vendorId.isEmpty) return false;
    if (vendorId == 'main') return true;
    return nearbyVendorIds.contains(vendorId);
  }

  Future<void> loadNearbyVendorIds({
    double? radiusKm,
    bool force = false,
  }) async {
    final effectiveRadiusKm = radiusKm ?? nearbyRadiusKm;
    if (!force &&
        _nearbyVendorLoadedAt != null &&
        DateTime.now().difference(_nearbyVendorLoadedAt!) <
            const Duration(minutes: 3)) {
      return;
    }

    nearbyVendorsLoading = true;
    nearbyLocationUnavailable = false;
    nearbyLocationMessage = '';
    nearbyStoresErrorMessage = '';
    notifyListeners();

    final location = await _resolveNearbyLocation();
    if (location == null) {
      nearbyVendorIds = const {};
      nearbyLocationUnavailable = true;
      nearbyLocationMessage = _nearbyLocationFailureMessage;
      nearbyVendorsLoading = false;
      _nearbyVendorLoadedAt = DateTime.now();
      notifyListeners();
      return;
    }

    try {
      final response = await apiService.get(
        '/vendors/nearby?latitude=${location.latitude}&longitude=${location.longitude}&radiusKm=$effectiveRadiusKm',
        token: token,
      );
      final vendors = response is List ? response : const [];
      nearbyVendorIds = vendors
          .whereType<Map<String, dynamic>>()
          .map((vendor) => vendor['vendorId']?.toString().trim() ?? '')
          .where((vendorId) => vendorId.isNotEmpty)
          .toSet();
      nearbyLocationUnavailable = false;
      nearbyLocationMessage = '';
      nearbyStoresErrorMessage = '';
      _nearbyVendorLoadedAt = DateTime.now();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[nearby] store API request failed: ${error.runtimeType}');
      }
      nearbyVendorIds = const {};
      nearbyLocationUnavailable = false;
      nearbyLocationMessage = '';
      nearbyStoresErrorMessage =
          'Nearby stores are temporarily unavailable. Please try again.';
      _nearbyVendorLoadedAt = DateTime.now();
    } finally {
      nearbyVendorsLoading = false;
      notifyListeners();
    }
  }

  String _nearbyLocationFailureMessage =
      'Turn on location and allow location permission to see nearby stores.';

  Future<({double latitude, double longitude})?>
  _resolveNearbyLocation() async {
    try {
      final gpsLocation = await LocationService().nearbyLocation().timeout(
        const Duration(seconds: 25),
      );
      if (kDebugMode) {
        debugPrint('[nearby] location source=gps; coordinates acquired');
      }
      return (latitude: gpsLocation.latitude, longitude: gpsLocation.longitude);
    } catch (error) {
      final cachedLocation = await LocationService().cachedNearbyLocation();
      if (cachedLocation != null) {
        if (kDebugMode) {
          debugPrint(
            '[nearby] GPS unavailable; using cached location: ${error.runtimeType}',
          );
        }
        return cachedLocation;
      }
      final message = error.toString();
      _nearbyLocationFailureMessage = message.contains('services are disabled')
          ? 'Turn on phone location/GPS to see nearby stores.'
          : message.contains('permission')
          ? (kIsWeb
                ? 'Click the location icon in the browser address bar, choose Allow, then tap Try again.'
                : 'Allow location permission to see nearby stores.')
          : 'Turn on location and allow permission to see nearby stores.';
      if (kDebugMode) {
        debugPrint('[nearby] GPS unavailable: ${error.runtimeType}');
      }
      return null;
    }
  }

  Future<void> bootstrap() async {
    try {
      token = await _sessionService.getToken();
      user = await _sessionService.getSavedUser();
      await Future.wait([
        loadProducts(),
        loadCategories(),
        loadBanners(),
        loadCheckoutSettings(),
      ]);
      if (token != null && user?.role == UserRoles.user) {
        await _restoreSession();
        await loadReviewedProductKeys();
        unawaited(loadNearbyVendorIds());
      }
      if (token != null && user?.role == UserRoles.vendor) {
        await _refreshCurrentProfileSafely();
      }
      if (token != null) {
        _connectSocket();
        try {
          await _syncDeliveryToken();
        } catch (e) {
          debugPrint('FCM token sync skipped during bootstrap: $e');
        }
        if (user?.role == UserRoles.user) {
          await loadFavorites();
          await loadBuyAgainProducts();
        }
        if ((user?.role == UserRoles.admin ||
                user?.role == UserRoles.vendor ||
                user?.role == UserRoles.superAdmin) &&
            (user?.approvalStatus ?? 'approved') == 'approved' &&
            (user?.isActive ?? true)) {
          await loadAdminOrders();
        }
      }
    } catch (error) {
      debugPrint('App bootstrap continued after recoverable error: $error');
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> loginWithPassword({
    String? email,
    String? phone,
    required String password,
    bool silent = false,
  }) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final data =
          await apiService.post(
                '/auth/login',
                body: {
                  if (phone != null && phone.isNotEmpty) 'phone': phone,
                  if (email != null && email.isNotEmpty) 'email': email,
                  'password': password,
                },
              )
              as Map<String, dynamic>;
      token = data['token'] as String;
      user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      vendor = null;
      await _sessionService.saveSession(token: token!, user: user!);
      await _refreshCurrentProfileSafely();
      await _loadPostAuthData();
      _connectSocket();
      try {
        await _syncDeliveryToken();
      } catch (e) {
        debugPrint('FCM token sync skipped after login: $e');
      }
      if ((user?.role == UserRoles.admin ||
              user?.role == UserRoles.vendor ||
              user?.role == UserRoles.superAdmin) &&
          (user?.approvalStatus ?? 'approved') == 'approved' &&
          (user?.isActive ?? true)) {
        await loadAdminOrders();
      }
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> loginVendor({
    String? email,
    String? phone,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data =
          await apiService.post(
                '/auth/vendor/login',
                body: {
                  if (phone != null && phone.isNotEmpty) 'phone': phone,
                  if (email != null && email.isNotEmpty) 'email': email,
                  'password': password,
                },
              )
              as Map<String, dynamic>;
      token = data['token'] as String;
      user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final vendorJson = data['vendor'];
      vendor = vendorJson is Map<String, dynamic>
          ? VendorModel.fromJson(vendorJson)
          : null;
      await _sessionService.saveSession(token: token!, user: user!);
      if (user?.approvalStatus == 'approved' && user?.isActive == true) {
        await _refreshCurrentProfileSafely();
        await _loadPostAuthData();
        _connectSocket();
        try {
          await _syncDeliveryToken();
        } catch (e) {
          debugPrint('FCM token sync skipped after vendor login: $e');
        }
        if (user?.role == UserRoles.admin ||
            user?.role == UserRoles.vendor ||
            user?.role == UserRoles.superAdmin) {
          await loadAdminOrders();
        }
      }
      error = null;
      return data;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<VendorModel> registerVendor({
    required String ownerName,
    required String storeBusinessName,
    required String mobileNumber,
    required String emailAddress,
    required String password,
    required String confirmPassword,
    required String businessType,
    required String gstNumber,
    required String panNumber,
    required String storeAddress,
    required String pickupAddress,
    required String city,
    required String state,
    required String pincode,
    required String bankAccountHolderName,
    required String bankAccountNumber,
    required String ifscCode,
    String storeLogo = '',
    String gstCertificate = '',
    String panCard = '',
    String cancelledCheque = '',
    String shopImageUrl = '',
    List<VendorBusinessHour> businessHours = const [],
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    final data =
        await apiService.post(
              '/auth/vendor/register',
              body: {
                'ownerName': ownerName,
                'storeBusinessName': storeBusinessName,
                'mobileNumber': mobileNumber,
                'emailAddress': emailAddress,
                'password': password,
                'confirmPassword': confirmPassword,
                'businessType': businessType,
                'gstNumber': gstNumber,
                'panNumber': panNumber,
                'storeAddress': storeAddress,
                'pickupAddress': pickupAddress,
                'city': city,
                'state': state,
                'pincode': pincode,
                'bankAccountHolderName': bankAccountHolderName,
                'bankAccountNumber': bankAccountNumber,
                'ifscCode': ifscCode,
                'storeLogo': storeLogo,
                'gstCertificateUrl': gstCertificate,
                'panCardUrl': panCard,
                'cancelledChequeUrl': cancelledCheque,
                'shopImageUrl': shopImageUrl,
                if (businessHours.isNotEmpty)
                  'businessHours': businessHours
                      .map((hour) => hour.toJson())
                      .toList(),
                if (pickupLatitude != null && pickupLongitude != null)
                  'pickupLocation': {
                    'latitude': pickupLatitude,
                    'longitude': pickupLongitude,
                  },
              },
            )
            as Map<String, dynamic>;
    final vendorJson = data['vendor'] as Map<String, dynamic>;
    vendor = VendorModel.fromJson(vendorJson);
    return vendor!;
  }

  Future<void> refreshVendorStatus() async {
    await refreshProfile();
    final current = user;
    if (current?.role == UserRoles.vendor) {
      vendor = VendorModel(
        id: current?.vendorId ?? 'main',
        name: current?.name ?? 'Vendor',
        vendorId: current?.vendorId ?? 'main',
        ownerName: current?.name ?? 'Vendor',
        phone: current?.phone ?? '',
        email: current?.email,
        approvalStatus: current?.approvalStatus ?? 'pending',
        isActive: current?.isActive ?? true,
        rejectionReason: current?.rejectionReason ?? '',
        approvedBy: current?.approvedBy,
        approvedAt: current?.approvedAt,
      );
      notifyListeners();
    }
  }

  Future<void> sendOtp({required String email}) async {
    await apiService.post('/auth/send-otp', body: {'email': email});
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
    bool silent = false,
  }) async {
    await _run(() async {
      final data =
          await apiService.post(
                '/auth/verify-otp',
                body: {'email': email, 'otp': otp},
              )
              as Map<String, dynamic>;
      token = data['token'] as String;
      user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _sessionService.saveSession(token: token!, user: user!);
      await _refreshCurrentProfileSafely();
      await _loadPostAuthData();
      _connectSocket();
      if ((user?.role == UserRoles.admin ||
              user?.role == UserRoles.vendor ||
              user?.role == UserRoles.superAdmin) &&
          (user?.approvalStatus ?? 'approved') == 'approved' &&
          (user?.isActive ?? true)) {
        await loadAdminOrders();
      }
    }, silent: silent);
  }

  Future<void> sendPasswordResetOtp({required String identifier}) async {
    await apiService.post(
      '/auth/forgot-password',
      body: {'identifier': identifier},
    );
  }

  Future<void> resetPasswordWithOtp({
    required String identifier,
    required String otp,
    required String password,
  }) async {
    await apiService.post(
      '/auth/reset-password',
      body: {'identifier': identifier, 'otp': otp, 'password': password},
    );
  }

  Future<void> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? addressLabel,
    String? addressLine1,
    String? city,
    String? pincode,
  }) async {
    final data =
        await apiService.post(
              '/auth/register',
              body: {
                'name': name,
                'phone': phone,
                if (email != null && email.isNotEmpty) 'email': email,
                'password': password,
              },
            )
            as Map<String, dynamic>;
    token = data['token'] as String?;
    final userJson = data['user'] as Map<String, dynamic>;
    user = UserModel.fromJson(userJson);
    if (token != null) {
      await _sessionService.saveSession(token: token!, user: user!);
    }
    notifyListeners();
    _connectSocket();
    try {
      await _syncDeliveryToken();
    } catch (e) {
      debugPrint('FCM token sync skipped after register: $e');
    }

    if ((addressLine1 ?? '').isNotEmpty &&
        (city ?? '').isNotEmpty &&
        (pincode ?? '').isNotEmpty) {
      try {
        await apiService.post(
          '/addresses',
          token: token,
          body: {
            'label': addressLabel ?? 'Home',
            'line1': addressLine1,
            'city': city,
            'pincode': pincode,
          },
        );
        await loadAddresses();
      } catch (e) {
        debugPrint('Address save skipped after register: $e');
      }
    }
  }

  Future<void> refreshProfile() async {
    if (token == null) return;
    final data =
        await apiService.get('/auth/me', token: token) as Map<String, dynamic>;
    final currentUser = data['user'];
    if (currentUser is Map<String, dynamic>) {
      user = UserModel.fromJson(currentUser);
      await _sessionService.saveSession(token: token!, user: user!);
      if (user?.role == UserRoles.vendor) {
        try {
          final vendorData =
              await apiService.get('/auth/vendor/profile', token: token)
                  as Map<String, dynamic>;
          final vendorJson = vendorData['vendor'];
          if (vendorJson is Map<String, dynamic>) {
            vendor = VendorModel.fromJson(vendorJson);
          } else {
            vendor = VendorModel(
              id: user?.vendorId ?? 'main',
              name: user?.name ?? 'Vendor',
              vendorId: user?.vendorId ?? 'main',
              ownerName: user?.name ?? 'Vendor',
              phone: user?.phone ?? '',
              email: user?.email,
              approvalStatus: user?.approvalStatus ?? 'pending',
              isActive: user?.isActive ?? true,
              rejectionReason: user?.rejectionReason ?? '',
              approvedBy: user?.approvedBy,
              approvedAt: user?.approvedAt,
            );
          }
        } catch (e) {
          debugPrint('Vendor profile refresh skipped: $e');
          vendor = VendorModel(
            id: user?.vendorId ?? 'main',
            name: user?.name ?? 'Vendor',
            vendorId: user?.vendorId ?? 'main',
            ownerName: user?.name ?? 'Vendor',
            phone: user?.phone ?? '',
            email: user?.email,
            approvalStatus: user?.approvalStatus ?? 'pending',
            isActive: user?.isActive ?? true,
            rejectionReason: user?.rejectionReason ?? '',
            approvedBy: user?.approvedBy,
            approvedAt: user?.approvedAt,
          );
        }
      }
      notifyListeners();
    }
  }

  Future<VendorModel> updateVendorPickupAddress({
    required String pickupAddress,
    String? city,
    String? state,
    String? pincode,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    if (token == null || user?.role != UserRoles.vendor) {
      throw StateError('Vendor login required');
    }
    final data =
        await apiService.put(
              '/auth/vendor/pickup-address',
              token: token,
              body: {
                'pickupAddress': pickupAddress,
                if (city != null) 'city': city.trim(),
                if (state != null) 'state': state.trim(),
                if (pincode != null) 'pincode': pincode.trim(),
                'pickupLocation':
                    pickupLatitude != null && pickupLongitude != null
                    ? {'latitude': pickupLatitude, 'longitude': pickupLongitude}
                    : null,
              },
            )
            as Map<String, dynamic>;
    final vendorJson = data['vendor'];
    if (vendorJson is Map<String, dynamic>) {
      vendor = VendorModel.fromJson(vendorJson);
      notifyListeners();
      return vendor!;
    }
    await refreshProfile();
    if (vendor == null) {
      throw StateError('Unable to refresh vendor profile');
    }
    return vendor!;
  }

  Future<VendorModel> updateVendorShopImage(String shopImageUrl) async {
    if (token == null || user?.role != UserRoles.vendor) {
      throw StateError('Vendor login required');
    }
    final data =
        await apiService.put(
              '/auth/vendor/shop-image',
              token: token,
              body: {'shopImageUrl': shopImageUrl.trim()},
            )
            as Map<String, dynamic>;
    final vendorJson = data['vendor'];
    if (vendorJson is Map<String, dynamic>) {
      vendor = VendorModel.fromJson(vendorJson);
      notifyListeners();
      return vendor!;
    }
    await refreshProfile();
    if (vendor == null) {
      throw StateError('Unable to refresh vendor profile');
    }
    return vendor!;
  }

  Future<VendorModel> updateVendorBusinessHours(
    List<VendorBusinessHour> businessHours,
  ) async {
    if (token == null || user?.role != UserRoles.vendor) {
      throw StateError('Vendor login required');
    }
    final data =
        await apiService.put(
              '/auth/vendor/business-hours',
              token: token,
              body: {
                'businessHours': businessHours
                    .map((hour) => hour.toJson())
                    .toList(),
              },
            )
            as Map<String, dynamic>;
    final vendorJson = data['vendor'];
    if (vendorJson is Map<String, dynamic>) {
      vendor = VendorModel.fromJson(vendorJson);
      notifyListeners();
      return vendor!;
    }
    await refreshProfile();
    if (vendor == null) {
      throw StateError('Unable to refresh vendor profile');
    }
    return vendor!;
  }

  Future<void> _refreshCurrentProfileSafely() async {
    if (token == null) return;
    if (user?.role == UserRoles.deliveryPerson) return;
    try {
      await refreshProfile();
    } catch (e) {
      debugPrint('Profile refresh skipped: $e');
    }
  }

  Future<void> _loadPostAuthData() async {
    final role = user?.role;
    if (role == UserRoles.user) {
      await Future.wait([
        _safeCall(loadCart),
        _safeCall(loadAddresses),
        _safeCall(loadFavorites),
        _safeCall(loadOrders),
        _safeCall(loadBuyAgainProducts),
      ]);
      await loadReviewedProductKeys();
      return;
    }
    if (role == UserRoles.deliveryPerson) {
      return;
    }
    if (role == UserRoles.admin ||
        role == UserRoles.vendor ||
        role == UserRoles.superAdmin) {
      if (user?.approvalStatus != 'approved' || user?.isActive != true) {
        return;
      }
      await Future.wait([
        _safeCall(loadOrders),
        _safeCall(loadFavorites),
        _safeCall(loadProducts),
      ]);
      return;
    }
    await Future.wait([
      _safeCall(loadOrders),
      _safeCall(loadCart),
      _safeCall(loadAddresses),
      _safeCall(loadFavorites),
    ]);
  }

  Future<void> loadSupportTickets() async {
    if (token == null) return;
    try {
      final data =
          await apiService.get('/support/tickets', token: token)
              as List<dynamic>;
      supportTickets = data.whereType<Map<String, dynamic>>().toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Support tickets skipped: $e');
    }
  }

  Future<void> loadReviewedProductKeys() async {
    final currentUserId = user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      reviewedProductKeys = {};
      return;
    }
    try {
      final data = await apiService.get('/reviews/mine', token: token);
      final reviews = data is List ? data : const [];
      reviewedProductKeys = reviews
          .whereType<Map<String, dynamic>>()
          .map(
            (review) => _reviewKey(
              review['orderId']?.toString() ??
                  review['order']?.toString() ??
                  '',
              review['productId']?.toString() ??
                  review['product']?.toString() ??
                  '',
            ),
          )
          .where((key) => key != '::')
          .toSet();
      await _sessionService.saveReviewedProductKeys(
        keys: reviewedProductKeys,
        userId: currentUserId,
      );
    } catch (e) {
      debugPrint('Review sync skipped: $e');
      reviewedProductKeys = await _sessionService.getReviewedProductKeys(
        userId: currentUserId,
      );
    }
    notifyListeners();
  }

  Future<List<ProductReviewModel>> loadProductReviews(
    String productId, {
    bool refresh = false,
  }) async {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty) return const [];
    if (!refresh) {
      final cached = _productReviewsById[normalizedProductId];
      if (cached != null) return cached;
    }

    try {
      final data = await apiService.get(
        '/products/$normalizedProductId/reviews',
      );
      final reviews = data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(ProductReviewModel.fromJson)
                .toList()
          : const <ProductReviewModel>[];
      _productReviewsById[normalizedProductId] = reviews;
      return reviews;
    } catch (error) {
      debugPrint('Product reviews load skipped: $error');
      return _productReviewsById[normalizedProductId] ?? const [];
    }
  }

  bool hasReviewedProduct({
    required String orderId,
    required String productId,
  }) {
    return reviewedProductKeys.contains(_reviewKey(orderId, productId));
  }

  Future<void> submitProductReview({
    required String orderId,
    required String productId,
    required double rating,
    String comment = '',
    bool notify = true,
  }) async {
    if (token == null || user?.role != UserRoles.user) {
      throw StateError('Customer login required');
    }

    final reviewKey = _reviewKey(orderId, productId);
    if (reviewedProductKeys.contains(reviewKey)) return;

    final payload = <String, dynamic>{
      'orderId': orderId,
      'productId': productId,
      'rating': rating,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
    };

    await apiService.post('/reviews', token: token, body: payload);

    // The server has accepted the rating. Update the in-memory state before
    // persisting the local cache so a storage hiccup cannot show a false
    // submission error after the review was already saved.
    reviewedProductKeys.add(reviewKey);
    if (notify) {
      notifyListeners();
    }
    try {
      await _sessionService.addReviewedProductKey(
        key: reviewKey,
        userId: user?.id,
      );
    } catch (error) {
      debugPrint('Review cache persistence skipped: $error');
    }
  }

  /// Publishes the review state after the review dialog has been dismissed.
  void notifyReviewSubmitted() {
    notifyListeners();
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String issueType,
    required String description,
    String orderId = '',
    String imageUrl = '',
  }) async {
    if (token == null) throw StateError('Please login first');
    final data =
        await apiService.post(
              '/support/tickets',
              token: token,
              body: {
                'subject': subject,
                'issueType': issueType,
                'description': description,
                'orderId': orderId,
                'imageUrl': imageUrl,
              },
            )
            as Map<String, dynamic>;
    await loadSupportTickets();
    return data;
  }

  Future<void> _safeCall(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Post-auth load skipped: $e');
    }
  }

  Future<void> logout() async {
    final currentToken = await _messagingService.getTokenSafe();
    if (token != null && currentToken != null && currentToken.isNotEmpty) {
      try {
        await _messagingService.removeToken(
          token: currentToken,
          authToken: token!,
        );
      } catch (e) {
        debugPrint('FCM token removal skipped during logout: $e');
      }
    }
    token = null;
    user = null;
    vendor = null;
    orders = [];
    adminOrders = [];
    buyAgainProducts = [];
    savedAddresses = [];
    selectedAddress = null;
    reviewedProductKeys = {};
    _productReviewsById.clear();
    cart.clear();
    favorites = [];
    socketService.disconnect();
    await _sessionService.clearSession();
    notifyListeners();
  }

  String _reviewKey(String orderId, String productId) {
    return '${orderId.trim()}::${productId.trim()}';
  }

  Future<void> _syncDeliveryToken() async {
    if (token == null) return;
    await _messagingService.registerTokenSync(authToken: token!);
  }

  bool isFavorite(ProductModel product) =>
      favorites.any((item) => item.id == product.id);

  void _setFavoriteState(ProductModel product, bool favorite) {
    if (favorite) {
      if (favorites.any((item) => item.id == product.id)) return;
      favorites = [product, ...favorites];
      return;
    }
    favorites = favorites.where((item) => item.id != product.id).toList();
  }

  List<CartLine> _cloneCart() => cart
      .map(
        (line) => CartLine(
          product: line.product,
          quantity: line.quantity,
          unit: line.unit,
          price: line.price,
          discountCost: line.discountCost,
          stock: line.stock,
        ),
      )
      .toList();

  ProductUnitVariant _variantFor(ProductModel product, String unit) {
    final normalized = unit.trim().toLowerCase();
    for (final variant in product.unitVariants) {
      if (variant.unit.toLowerCase() == normalized) return variant;
    }
    return ProductUnitVariant(
      unit: unit.trim().isEmpty ? product.unit : unit.trim(),
      price: product.price,
      discountCost: product.mrp,
      stock: product.stock,
    );
  }

  void _setCartQuantity(
    ProductModel product,
    int quantity, {
    String? unit,
    double? price,
    double? discountCost,
    int? stock,
  }) {
    final selectedUnit = (unit ?? product.unit).trim();
    final key = '${product.id}::${selectedUnit.toLowerCase()}';
    final index = cart.indexWhere((line) => line.key == key);
    if (quantity <= 0) {
      if (index != -1) {
        cart.removeAt(index);
        checkoutSummary = null;
      }
      return;
    }
    if (index == -1) {
      cart.add(
        CartLine(
          product: product,
          quantity: quantity,
          unit: selectedUnit,
          price: price,
          discountCost: discountCost,
          stock: stock,
        ),
      );
      checkoutSummary = null;
      return;
    }
    if (cart[index].quantity != quantity) {
      checkoutSummary = null;
    }
    cart[index].quantity = quantity;
  }

  int _nextCartMutationToken() => ++_cartMutationToken;

  void _restoreCartSnapshot(List<CartLine> snapshot) {
    cart
      ..clear()
      ..addAll(snapshot);
    checkoutSummary = null;
    notifyListeners();
  }

  Future<void> _syncCartMutation({
    required int mutationToken,
    required List<CartLine> snapshot,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (e) {
      if (mutationToken == _cartMutationToken) {
        _restoreCartSnapshot(snapshot);
        error = e.toString();
      } else {
        debugPrint('Cart sync failed after newer cart changes: $e');
      }
    }
  }

  Future<void> toggleFavorite(ProductModel product) async {
    if (token == null) throw StateError('Please login first');
    final wasFavorite = isFavorite(product);
    final snapshot = List<ProductModel>.from(favorites);
    _setFavoriteState(product, !wasFavorite);
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      if (wasFavorite) {
        await apiService.delete('/wishlist/remove/${product.id}', token: token);
      } else {
        await apiService.post(
          '/wishlist/add',
          token: token,
          body: {'productId': product.id},
        );
      }
      await loadFavorites();
      debugPrint(
        '[perf][wishlist:${wasFavorite ? "remove" : "add"}][api] ${sw.elapsedMilliseconds}ms',
      );
    } catch (e) {
      favorites = snapshot;
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeFavorite(String productId) async {
    if (token == null) throw StateError('Please login first');
    final snapshot = List<ProductModel>.from(favorites);
    favorites.removeWhere((item) => item.id == productId);
    notifyListeners();
    try {
      await apiService.delete('/wishlist/remove/$productId', token: token);
    } catch (e) {
      favorites = snapshot;
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  String get defaultDashboardRoute {
    if (user?.role == UserRoles.deliveryPerson &&
        (user?.approvalStatus ?? 'approved').toLowerCase() != 'approved') {
      return '/delivery/status';
    }
    return RoleAccess.dashboardForRole(user?.role);
  }

  bool canAccessRoute(String routeName) {
    final approvalStatus = (user?.approvalStatus ?? 'approved').toLowerCase();
    if (routeName == '/delivery') {
      return user?.role == UserRoles.deliveryPerson &&
          approvalStatus == 'approved';
    }
    if (routeName == '/delivery/login' ||
        routeName == '/delivery/register' ||
        routeName == '/delivery/status' ||
        routeName == '/delivery/payment') {
      return true;
    }
    return RoleAccess.canAccessRoute(user?.role, routeName);
  }

  Future<void> loadProducts({String? category, String? search}) async {
    await _run(() async {
      final query = <String>[
        if (category != null && category != 'All') 'category=$category',
        if (search != null && search.isNotEmpty) 'search=$search',
      ].join('&');
      final path = '/products${query.isEmpty ? '' : '?$query'}';
      final loadedProducts = await _loadProductsWithRetry(path, token: token);
      if (user?.role == UserRoles.vendor || user?.role == UserRoles.admin) {
        final activeVendorId = (vendor?.vendorId ?? user?.vendorId ?? '')
            .trim();
        products = activeVendorId.isEmpty
            ? loadedProducts
            : loadedProducts
                  .where((product) => product.vendorId.trim() == activeVendorId)
                  .toList();
      } else {
        products = loadedProducts;
      }
    });
  }

  Future<List<ProductModel>> _loadProductsWithRetry(
    String path, {
    String? token,
  }) async {
    Future<List<ProductModel>> fetchOnce() async {
      final data =
          await apiService
                  .get(path, token: token)
                  .timeout(const Duration(seconds: 8))
              as List<dynamic>;
      return data
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList();
    }

    try {
      return await fetchOnce();
    } catch (firstError) {
      debugPrint('Product load retry after error: $firstError');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return await fetchOnce();
    }
  }

  Future<void> loadCategories() async {
    try {
      final data =
          await apiService
                  .get('/categories')
                  .timeout(const Duration(seconds: 8))
              as List<dynamic>;
      categoryCatalog = data
          .cast<Map<String, dynamic>>()
          .map(CategoryModel.fromJson)
          .toList();
      notifyListeners();
    } catch (error) {
      debugPrint('Category load skipped: $error');
    }
  }

  Future<void> loadBanners() async {
    try {
      final data =
          await apiService.get('/banners').timeout(const Duration(seconds: 8))
              as List<dynamic>;
      banners = data
          .cast<Map<String, dynamic>>()
          .where((item) => item['active'] != false)
          .map(BannerModel.fromJson)
          .toList();
      notifyListeners();
    } catch (error) {
      debugPrint('Banner load skipped: $error');
    }
  }

  Future<void> createCategory({
    required String name,
    String description = '',
    String imageUrl = '',
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    await apiService.post(
      '/categories',
      token: token,
      body: {'name': name, 'description': description, 'imageUrl': imageUrl},
    );
    await loadCategories();
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    String description = '',
    String imageUrl = '',
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    await apiService.put(
      '/categories/$categoryId',
      token: token,
      body: {'name': name, 'description': description, 'imageUrl': imageUrl},
    );
    await loadCategories();
  }

  Future<void> deleteCategory(String categoryId) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    await apiService.delete('/categories/$categoryId', token: token);
    await loadCategories();
  }

  Future<String> uploadCategoryImage(
    String filePath, {
    Uint8List? bytes,
    String? fileName,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }

    final data =
        await apiService.uploadImage(
              '/categories/upload-image',
              token: token,
              filePath: filePath,
              bytes: bytes,
              fileName: fileName,
              fieldName: 'image',
            )
            as Map<String, dynamic>;

    return NetworkImageUrl.normalize(data['url'] as String?);
  }

  Future<String> uploadProductImage(
    String filePath, {
    Uint8List? bytes,
    String? fileName,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin &&
            user?.role != UserRoles.vendor &&
            user?.role != UserRoles.superAdmin)) {
      throw StateError('Vendor or admin login required');
    }

    final data =
        await apiService.uploadImage(
              '/products/upload-image',
              token: token,
              filePath: filePath,
              bytes: bytes,
              fileName: fileName,
              fieldName: 'image',
            )
            as Map<String, dynamic>;

    return NetworkImageUrl.normalize(data['url'] as String?);
  }

  Future<ProductModel> createProduct({
    required String name,
    required String category,
    required double price,
    required double cost,
    required double mrp,
    required int stock,
    required String unit,
    required double rating,
    String description = '',
    String dashboardSection = 'daily_essentials',
    String imageUrl = '',
    double tax = 0,
    String? vendorId,
    List<Map<String, dynamic>>? unitVariants,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin &&
            user?.role != UserRoles.vendor &&
            user?.role != UserRoles.superAdmin)) {
      throw StateError('Vendor or admin login required');
    }

    final data =
        await apiService.post(
              '/products',
              token: token,
              body: {
                'name': name,
                'category': category,
                'price': price,
                'cost': cost,
                'mrp': mrp,
                'stock': stock,
                'unit': unit,
                'rating': rating,
                'description': description,
                'dashboardSection': dashboardSection,
                'imageUrl': imageUrl,
                'tax': tax,
                if (vendorId != null && vendorId.trim().isNotEmpty)
                  'vendorId': vendorId.trim(),
                if (unitVariants != null && unitVariants.isNotEmpty)
                  'unitVariants': unitVariants,
              },
            )
            as Map<String, dynamic>;

    final product = ProductModel.fromJson(data);
    products.insert(0, product);
    notifyListeners();
    await loadProducts();
    return product;
  }

  Future<ProductModel> updateProduct({
    required String productId,
    required String name,
    required String category,
    required double price,
    required double cost,
    required double mrp,
    required int stock,
    required String unit,
    required double rating,
    String description = '',
    String dashboardSection = 'daily_essentials',
    String imageUrl = '',
    double tax = 0,
    String? vendorId,
    List<Map<String, dynamic>>? unitVariants,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin &&
            user?.role != UserRoles.vendor &&
            user?.role != UserRoles.superAdmin)) {
      throw StateError('Vendor or admin login required');
    }

    final data =
        await apiService.put(
              '/products/$productId',
              token: token,
              body: {
                'name': name,
                'category': category,
                'price': price,
                'cost': cost,
                'mrp': mrp,
                'stock': stock,
                'unit': unit,
                'rating': rating,
                'description': description,
                'dashboardSection': dashboardSection,
                'imageUrl': imageUrl,
                'tax': tax,
                if (vendorId != null && vendorId.trim().isNotEmpty)
                  'vendorId': vendorId.trim(),
                if (unitVariants != null && unitVariants.isNotEmpty)
                  'unitVariants': unitVariants,
              },
            )
            as Map<String, dynamic>;

    final product = ProductModel.fromJson(data);
    final index = products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      products.insert(0, product);
    } else {
      products[index] = product;
    }
    notifyListeners();
    await loadProducts();
    return product;
  }

  Future<void> deleteProduct(String productId) async {
    if (token == null ||
        (user?.role != UserRoles.admin &&
            user?.role != UserRoles.vendor &&
            user?.role != UserRoles.superAdmin)) {
      throw StateError('Vendor or admin login required');
    }

    await apiService.delete('/products/$productId', token: token);
    products.removeWhere((product) => product.id == productId);
    notifyListeners();
    await loadProducts();
  }

  Future<void> loadOrders() async {
    if (token == null) return;
    final data =
        await apiService.get('/orders/mine', token: token) as List<dynamic>;
    orders = data
        .cast<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList();
    notifyListeners();
  }

  Future<void> loadBuyAgainProducts() async {
    if (token == null || user?.role != UserRoles.user) {
      buyAgainProducts = [];
      notifyListeners();
      return;
    }

    try {
      final data =
          await apiService
                  .get('/orders/buy-again', token: token)
                  .timeout(const Duration(seconds: 8))
              as List<dynamic>;
      buyAgainProducts = data
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList();
      notifyListeners();
    } catch (error) {
      debugPrint('Buy again products load skipped: $error');
    }
  }

  Future<void> loadFavorites() async {
    if (token == null) {
      favorites = [];
      notifyListeners();
      return;
    }

    final data =
        await apiService.get('/wishlist', token: token) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const []);
    favorites = items
        .map((item) => item is Map<String, dynamic> ? item['product'] : null)
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
    notifyListeners();
  }

  Future<bool> addToCart(
    ProductModel product, {
    int quantity = 1,
    String? unit,
    double? price,
    double? discountCost,
    int? stock,
  }) async {
    return _syncAddToCart(
      product,
      quantity: quantity,
      unit: unit,
      price: price,
      discountCost: discountCost,
      stock: stock,
    );
  }

  Future<ReorderCartResult> addOrderToCart(OrderModel order) async {
    if (token == null) {
      error = 'Please login first';
      notifyListeners();
      return const ReorderCartResult(addedCount: 0, skippedCount: 0);
    }

    final items = <({ProductModel product, int quantity})>[];
    for (var i = 0; i < order.products.length; i++) {
      final product = order.products[i];
      final productId = product.id.trim();
      if (productId.isEmpty) continue;
      final quantity = i < order.quantities.length ? order.quantities[i] : 1;
      items.add((product: product, quantity: quantity <= 0 ? 1 : quantity));
    }

    if (items.isEmpty) {
      error = 'No items available to reorder';
      notifyListeners();
      return const ReorderCartResult(addedCount: 0, skippedCount: 0);
    }

    final snapshot = _cloneCart();
    final mutationToken = _nextCartMutationToken();
    for (final item in items) {
      _setCartQuantity(
        item.product,
        (cart
                .firstWhere(
                  (line) =>
                      line.key ==
                      '${item.product.id}::${item.product.unit.trim().toLowerCase()}',
                  orElse: () => CartLine(
                    product: item.product,
                    quantity: 0,
                    unit: item.product.unit,
                  ),
                )
                .quantity) +
            item.quantity,
        unit: item.product.unit,
      );
    }
    error = null;
    notifyListeners();

    var addedCount = 0;
    var skippedCount = 0;
    try {
      for (final item in items) {
        try {
          await apiService.post(
            '/cart/add',
            token: token,
            body: {
              'productId': item.product.id,
              'quantity': item.quantity,
              if (item.product.unit.trim().isNotEmpty)
                'unit': item.product.unit.trim(),
            },
          );
          addedCount++;
        } catch (e) {
          skippedCount++;
          debugPrint('Reorder item skipped: $e');
        }
      }
      await loadCart();
      if (addedCount == 0 && skippedCount > 0) {
        error = 'Previous order items are currently unavailable';
        _restoreCartSnapshot(snapshot);
      }
      return ReorderCartResult(
        addedCount: addedCount,
        skippedCount: skippedCount,
      );
    } catch (e) {
      if (mutationToken == _cartMutationToken) {
        _restoreCartSnapshot(snapshot);
      }
      error = e.toString();
      notifyListeners();
      return ReorderCartResult(addedCount: 0, skippedCount: items.length);
    }
  }

  Future<bool> decrement(ProductModel product, {String? unit}) async {
    return _syncDecrement(product, unit: unit);
  }

  Future<bool> changeCartUnit(
    ProductModel product, {
    required String fromUnit,
    required String toUnit,
  }) async {
    if (token == null) {
      error = 'Please login first';
      notifyListeners();
      return false;
    }

    final sourceUnit = fromUnit.trim();
    final targetUnit = toUnit.trim();
    if (sourceUnit.toLowerCase() == targetUnit.toLowerCase()) {
      return true;
    }

    final current = cart.firstWhere(
      (line) => line.key == '${product.id}::${sourceUnit.toLowerCase()}',
      orElse: () => CartLine(product: product, quantity: 0, unit: sourceUnit),
    );
    if (current.quantity <= 0) return false;

    final snapshot = _cloneCart();
    final mutationToken = _nextCartMutationToken();
    final variant = _variantFor(product, targetUnit);
    final currentTarget = cart.firstWhere(
      (line) => line.key == '${product.id}::${targetUnit.toLowerCase()}',
      orElse: () => CartLine(product: product, quantity: 0, unit: targetUnit),
    );
    if (variant.stock > 0 &&
        currentTarget.quantity + current.quantity > variant.stock) {
      error =
          'Only ${variant.stock} ${targetUnit.isEmpty ? product.unit : targetUnit} available';
      notifyListeners();
      return false;
    }
    final movedQuantity = variant.stock > 0 && current.quantity > variant.stock
        ? variant.stock
        : current.quantity;
    final nextQuantity = currentTarget.quantity + movedQuantity;

    _setCartQuantity(product, 0, unit: sourceUnit);
    _setCartQuantity(
      product,
      nextQuantity,
      unit: targetUnit,
      price: variant.price,
      discountCost: variant.discountCost,
      stock: variant.stock,
    );
    error = null;
    notifyListeners();

    unawaited(
      _syncCartMutation(
        mutationToken: mutationToken,
        snapshot: snapshot,
        action: () async {
          await apiService.delete(
            '/cart/remove/${product.id}?unit=${Uri.encodeComponent(sourceUnit)}',
            token: token,
          );
          await apiService.post(
            '/cart/add',
            token: token,
            body: {
              'productId': product.id,
              'quantity': movedQuantity,
              if (targetUnit.isNotEmpty) 'unit': targetUnit,
              if (variant.price > 0) 'price': variant.price,
              if (variant.discountCost > 0)
                'discountCost': variant.discountCost,
              if (variant.stock > 0) 'stock': variant.stock,
            },
          );
        },
      ),
    );
    return true;
  }

  Future<bool> clearCart() async {
    return _syncClearCart();
  }

  Future<OrderModel> checkout({
    required AddressModel address,
    String paymentMethod = 'razorpay',
    String? paymentId,
    DateTime? scheduledFor,
  }) async {
    if (token == null) throw StateError('Please login first');
    final data =
        await apiService.post(
              '/orders',
              token: token,
              body: {
                'products': cart.map((line) => line.toOrderJson()).toList(),
                'deliveryFee': deliveryFee,
                'gstPercent': gstPercent,
                'useProductTax': usesProductTax,
                if (cartDistanceKm(address) != null)
                  'distanceKm': cartDistanceKm(address),
                'address': {
                  'line1': address.line1,
                  'area': address.area,
                  'landmark': address.landmark,
                  'city': address.city,
                  'state': address.state,
                  'pincode': address.pincode,
                  'label': address.label,
                  'fullAddress': address.fullAddress,
                  ...address.toLocationJson(),
                },
                'paymentMethod': paymentMethod,
                if (paymentId != null) 'paymentId': paymentId,
                if (scheduledFor != null)
                  'scheduledFor': scheduledFor.toIso8601String(),
              },
            )
            as dynamic;
    final createdOrders = _extractCreatedOrders(data);
    if (createdOrders.isEmpty) {
      throw StateError('Order creation failed');
    }
    orders.insertAll(0, createdOrders.reversed.toList());
    lastCheckoutOrders = List<OrderModel>.unmodifiable(createdOrders);
    await clearCart();
    await loadBuyAgainProducts();
    return createdOrders.first;
  }

  List<OrderModel> _extractCreatedOrders(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final ordersJson = data['orders'];
      if (ordersJson is List && ordersJson.isNotEmpty) {
        return ordersJson
            .whereType<Map<String, dynamic>>()
            .map(OrderModel.fromJson)
            .toList();
      }

      final orderJson = data['order'];
      if (orderJson is Map<String, dynamic>) {
        return [OrderModel.fromJson(orderJson)];
      }

      if (data.containsKey('_id') || data.containsKey('id')) {
        return [OrderModel.fromJson(data)];
      }
    }

    return const [];
  }

  Future<Map<String, dynamic>> loadCheckoutSummary({
    AddressModel? address,
  }) async {
    if (token == null) throw StateError('Please login first');
    final data =
        await apiService.post(
              '/payments/checkout-summary',
              token: token,
              body: {
                'products': cart.map((line) => line.toOrderJson()).toList(),
                'deliveryFee': deliveryFee,
                'gstPercent': gstPercent,
                'useProductTax': usesProductTax,
                if (cartDistanceKm(address) != null)
                  'distanceKm': cartDistanceKm(address),
                if (address != null)
                  'address': {
                    'line1': address.line1,
                    'area': address.area,
                    'landmark': address.landmark,
                    'city': address.city,
                    'state': address.state,
                    'pincode': address.pincode,
                    'label': address.label,
                    'fullAddress': address.fullAddress,
                    ...address.toLocationJson(),
                  },
              },
            )
            as Map<String, dynamic>;
    if (data.containsKey('freeDeliveryThreshold')) {
      final t = _asDouble(data['freeDeliveryThreshold']);
      if (t > 0) freeDeliveryThreshold = t;
    }
    if (data.containsKey('freeDeliveryEnabled')) {
      freeDeliveryEnabled = _asBool(data['freeDeliveryEnabled']);
    }
    final feeFromData = (data['deliveryFee'] as num?)?.toDouble();
    // shiftCharge is only the optional surcharge. The backend deliveryFee is
    // the authoritative final fee and already includes distance and night
    // pricing when applicable.
    final effectiveRawFee = feeFromData ?? calculatedDeliveryFee;
    final qualifiesFree =
        isFreeDelivery ||
        data['isFreeDelivery'] == true ||
        (freeDeliveryEnabled &&
            (freeDeliveryThreshold <= 0 || subtotal >= freeDeliveryThreshold));

    data['calculatedDeliveryFee'] = effectiveRawFee;
    if (qualifiesFree) {
      data['deliveryFee'] = 0.0;
      data['effectiveDeliveryFee'] = 0.0;
      data['isFreeDelivery'] = true;
      final st = (data['subtotal'] as num?)?.toDouble() ?? subtotal;
      final gst = (data['gstAmount'] as num?)?.toDouble() ?? gstAmount;
      data['total'] = st + gst;
    } else {
      data['deliveryFee'] = effectiveRawFee;
      data['effectiveDeliveryFee'] = effectiveRawFee;
      data['isFreeDelivery'] = false;
      final st = (data['subtotal'] as num?)?.toDouble() ?? subtotal;
      final gst = (data['gstAmount'] as num?)?.toDouble() ?? gstAmount;
      data['total'] = st + effectiveRawFee + gst;
    }
    checkoutSummary = data;
    notifyListeners();
    return data;
  }

  Future<Map<String, dynamic>> adminDashboard() async {
    if (token == null ||
        (user?.role != UserRoles.admin &&
            user?.role != UserRoles.vendor &&
            user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    return await apiService.get('/admin/dashboard', token: token)
        as Map<String, dynamic>;
  }

  Future<void> loadCheckoutSettings() async {
    // 1. Try to load cached delivery settings from SharedPreferences first
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('free_delivery_enabled')) {
        freeDeliveryEnabled =
            prefs.getBool('free_delivery_enabled') ?? freeDeliveryEnabled;
      }
      if (prefs.containsKey('free_delivery_threshold')) {
        freeDeliveryThreshold =
            prefs.getDouble('free_delivery_threshold') ?? freeDeliveryThreshold;
      }
      if (prefs.containsKey('delivery_charge_amount')) {
        deliveryChargeAmount =
            prefs.getDouble('delivery_charge_amount') ?? deliveryChargeAmount;
      }
      if (prefs.containsKey('delivery_pricing_mode')) {
        distanceBasedDelivery =
            prefs.getString('delivery_pricing_mode') == 'distance';
      }
      if (prefs.containsKey('delivery_base_distance_km')) {
        deliveryBaseDistanceKm =
            prefs.getDouble('delivery_base_distance_km') ??
            deliveryBaseDistanceKm;
      }
      if (prefs.containsKey('delivery_base_charge')) {
        deliveryBaseCharge =
            prefs.getDouble('delivery_base_charge') ?? deliveryBaseCharge;
      }
      if (prefs.containsKey('delivery_per_km_charge')) {
        deliveryPerKmCharge =
            prefs.getDouble('delivery_per_km_charge') ?? deliveryPerKmCharge;
      }
      if (prefs.containsKey('delivery_max_radius_km')) {
        deliveryMaxRadiusKm =
            prefs.getDouble('delivery_max_radius_km') ?? deliveryMaxRadiusKm;
        nearbyRadiusKm = fixedDeliveryRadiusKm;
      }
      if (prefs.containsKey('gst_percent')) {
        gstPercent = prefs.getDouble('gst_percent') ?? gstPercent;
      }
      if (prefs.containsKey('shift_charges_enabled')) {
        shiftChargesEnabled =
            prefs.getBool('shift_charges_enabled') ?? shiftChargesEnabled;
      }
      if (prefs.containsKey('day_delivery_charge')) {
        dayDeliveryCharge =
            prefs.getDouble('day_delivery_charge') ?? dayDeliveryCharge;
      }
      if (prefs.containsKey('night_delivery_charge')) {
        nightDeliveryCharge =
            prefs.getDouble('night_delivery_charge') ?? nightDeliveryCharge;
      }
      if (prefs.containsKey('night_shift_start')) {
        dayShiftStart = prefs.getString('night_shift_start') ?? dayShiftStart;
      }
      if (prefs.containsKey('night_shift_end')) {
        dayShiftEnd = prefs.getString('night_shift_end') ?? dayShiftEnd;
      }
    } catch (e) {
      debugPrint('Local delivery settings load skipped: $e');
    }

    // 2. Fetch fresh settings from backend
    try {
      dynamic data;
      if (token != null &&
          (user?.role == UserRoles.superAdmin ||
              user?.role == UserRoles.admin)) {
        final endpoint = (user?.role == UserRoles.superAdmin)
            ? '/super-admin/settings'
            : '/admin/settings';
        try {
          data = await apiService.get(endpoint, token: token);
        } catch (_) {
          data = await apiService.get('/settings/public');
        }
      } else {
        data = await apiService.get('/settings/public');
      }

      if (data is List) {
        final map = {
          for (final item in data.whereType<Map<String, dynamic>>())
            (item['key'] ?? '').toString(): item['value'],
        };

        if (map.containsKey('delivery_charge_amount')) {
          deliveryChargeAmount = _asDouble(
            map['delivery_charge_amount'],
            fallback: deliveryChargeAmount,
          );
        }
        if (map.containsKey('delivery_pricing_mode')) {
          distanceBasedDelivery =
              (map['delivery_pricing_mode'] ?? '').toString().toLowerCase() ==
              'distance';
        }
        if (map.containsKey('delivery_base_distance_km')) {
          deliveryBaseDistanceKm = _asDouble(
            map['delivery_base_distance_km'],
            fallback: deliveryBaseDistanceKm,
          );
        }
        if (map.containsKey('delivery_base_charge')) {
          deliveryBaseCharge = _asDouble(
            map['delivery_base_charge'],
            fallback: deliveryChargeAmount,
          );
        }
        if (map.containsKey('delivery_per_km_charge')) {
          deliveryPerKmCharge = _asDouble(
            map['delivery_per_km_charge'],
            fallback: deliveryPerKmCharge,
          );
        }
        if (map.containsKey('delivery_max_radius_km')) {
          deliveryMaxRadiusKm = _asDouble(
            map['delivery_max_radius_km'],
            fallback: deliveryMaxRadiusKm,
          );
          nearbyRadiusKm = fixedDeliveryRadiusKm;
        }
        if (map.containsKey('gst_percent')) {
          gstPercent = _asDouble(map['gst_percent'], fallback: gstPercent);
        }

        if (map.containsKey('free_delivery_enabled')) {
          freeDeliveryEnabled = _asBool(
            map['free_delivery_enabled'],
            fallback: freeDeliveryEnabled,
          );
        }
        if (map.containsKey('free_delivery_threshold')) {
          freeDeliveryThreshold = _asDouble(
            map['free_delivery_threshold'],
            fallback: freeDeliveryThreshold,
          );
        }
        if (map.containsKey('shift_charges_enabled')) {
          shiftChargesEnabled = _asBool(
            map['shift_charges_enabled'],
            fallback: shiftChargesEnabled,
          );
        }
        if (map.containsKey('day_delivery_charge')) {
          dayDeliveryCharge = _asDouble(
            map['day_delivery_charge'],
            fallback: dayDeliveryCharge,
          );
        }
        if (map.containsKey('night_delivery_charge')) {
          nightDeliveryCharge = _asDouble(
            map['night_delivery_charge'],
            fallback: nightDeliveryCharge,
          );
        }
        if ((map.containsKey('night_shift_start') ||
                map.containsKey('day_shift_start')) &&
            (map['night_shift_start'] ?? map['day_shift_start']) != null) {
          dayShiftStart = (map['night_shift_start'] ?? map['day_shift_start'])
              .toString();
        }
        if ((map.containsKey('night_shift_end') ||
                map.containsKey('day_shift_end')) &&
            (map['night_shift_end'] ?? map['day_shift_end']) != null) {
          dayShiftEnd = (map['night_shift_end'] ?? map['day_shift_end'])
              .toString();
        }

        // Cache updated remote settings to SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('free_delivery_enabled', freeDeliveryEnabled);
          await prefs.setDouble(
            'free_delivery_threshold',
            freeDeliveryThreshold,
          );
          await prefs.setDouble('delivery_charge_amount', deliveryChargeAmount);
          await prefs.setString(
            'delivery_pricing_mode',
            distanceBasedDelivery ? 'distance' : 'fixed',
          );
          await prefs.setDouble(
            'delivery_base_distance_km',
            deliveryBaseDistanceKm,
          );
          await prefs.setDouble('delivery_base_charge', deliveryBaseCharge);
          await prefs.setDouble('delivery_per_km_charge', deliveryPerKmCharge);
          await prefs.setDouble('delivery_max_radius_km', deliveryMaxRadiusKm);
          await prefs.setDouble('gst_percent', gstPercent);
          await prefs.setBool('shift_charges_enabled', shiftChargesEnabled);
          await prefs.setDouble('day_delivery_charge', dayDeliveryCharge);
          await prefs.setDouble('night_delivery_charge', nightDeliveryCharge);
          await prefs.setString('day_shift_start', dayShiftStart);
          await prefs.setString('day_shift_end', dayShiftEnd);
          await prefs.setString('night_shift_start', dayShiftStart);
          await prefs.setString('night_shift_end', dayShiftEnd);
        } catch (_) {}
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Checkout settings load skipped: $e');
    }
  }

  Future<void> saveCheckoutSettings({
    required double deliveryChargeAmount,
    required double gstPercent,
    required bool distanceBasedDelivery,
    required double deliveryBaseDistanceKm,
    required double deliveryBaseCharge,
    required double deliveryPerKmCharge,
    double deliveryMaxRadiusKm = fixedDeliveryRadiusKm,
    bool? freeDeliveryEnabled,
    double? freeDeliveryThreshold,
    bool? shiftChargesEnabled,
    double? dayDeliveryCharge,
    double? nightDeliveryCharge,
    String? dayShiftStart,
    String? dayShiftEnd,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final effectiveFreeEnabled =
        freeDeliveryEnabled ?? this.freeDeliveryEnabled;
    final effectiveFreeThreshold =
        freeDeliveryThreshold ?? this.freeDeliveryThreshold;
    final effectiveShiftEnabled =
        shiftChargesEnabled ?? this.shiftChargesEnabled;
    final effectiveDayCharge = dayDeliveryCharge ?? this.dayDeliveryCharge;
    final effectiveNightCharge =
        nightDeliveryCharge ?? this.nightDeliveryCharge;
    final effectiveDayStart = dayShiftStart ?? this.dayShiftStart;
    final effectiveDayEnd = dayShiftEnd ?? this.dayShiftEnd;

    final targetEndpoint = (user?.role == UserRoles.superAdmin)
        ? '/super-admin/settings'
        : '/admin/settings';

    await apiService.put(
      targetEndpoint,
      token: token,
      body: {
        'delivery_charge_amount': deliveryChargeAmount,
        'delivery_pricing_mode': distanceBasedDelivery ? 'distance' : 'fixed',
        'delivery_base_distance_km': deliveryBaseDistanceKm,
        'delivery_base_charge': deliveryBaseCharge,
        'delivery_per_km_charge': deliveryPerKmCharge,
        'gst_percent': gstPercent,
        'free_delivery_enabled': effectiveFreeEnabled,
        'free_delivery_threshold': effectiveFreeThreshold,
        'shift_charges_enabled': effectiveShiftEnabled,
        'day_delivery_charge': effectiveDayCharge,
        'night_delivery_charge': effectiveNightCharge,
        'day_shift_start': effectiveDayStart,
        'day_shift_end': effectiveDayEnd,
        'night_shift_start': effectiveDayStart,
        'night_shift_end': effectiveDayEnd,
      },
    );
    this.deliveryChargeAmount = deliveryChargeAmount;
    this.distanceBasedDelivery = distanceBasedDelivery;
    this.deliveryBaseDistanceKm = deliveryBaseDistanceKm;
    this.deliveryBaseCharge = deliveryBaseCharge;
    this.deliveryPerKmCharge = deliveryPerKmCharge;
    this.deliveryMaxRadiusKm = deliveryMaxRadiusKm;
    nearbyRadiusKm = fixedDeliveryRadiusKm;
    this.gstPercent = gstPercent;
    this.freeDeliveryEnabled = effectiveFreeEnabled;
    this.freeDeliveryThreshold = effectiveFreeThreshold;
    this.shiftChargesEnabled = effectiveShiftEnabled;
    this.dayDeliveryCharge = effectiveDayCharge;
    this.nightDeliveryCharge = effectiveNightCharge;
    this.dayShiftStart = effectiveDayStart;
    this.dayShiftEnd = effectiveDayEnd;

    // Cache immediately to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('free_delivery_enabled', effectiveFreeEnabled);
      await prefs.setDouble('free_delivery_threshold', effectiveFreeThreshold);
      await prefs.setDouble('delivery_charge_amount', deliveryChargeAmount);
      await prefs.setString(
        'delivery_pricing_mode',
        distanceBasedDelivery ? 'distance' : 'fixed',
      );
      await prefs.setDouble(
        'delivery_base_distance_km',
        deliveryBaseDistanceKm,
      );
      await prefs.setDouble('delivery_base_charge', deliveryBaseCharge);
      await prefs.setDouble('delivery_per_km_charge', deliveryPerKmCharge);
      await prefs.setDouble('delivery_max_radius_km', deliveryMaxRadiusKm);
      await prefs.setDouble('gst_percent', gstPercent);
      await prefs.setBool('shift_charges_enabled', effectiveShiftEnabled);
      await prefs.setDouble('day_delivery_charge', effectiveDayCharge);
      await prefs.setDouble('night_delivery_charge', effectiveNightCharge);
      await prefs.setString('day_shift_start', effectiveDayStart);
      await prefs.setString('day_shift_end', effectiveDayEnd);
      await prefs.setString('night_shift_start', effectiveDayStart);
      await prefs.setString('night_shift_end', effectiveDayEnd);
    } catch (_) {}

    notifyListeners();
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final str = value.toString().trim().toLowerCase();
    if (str == 'true' || str == '1') return true;
    if (str == 'false' || str == '0') return false;
    return fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    return n ?? fallback;
  }

  Future<Map<String, dynamic>> superAdminAnalytics() async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super admin login required');
    }
    return await apiService.get('/super-admin/analytics', token: token)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> superAdminOrderAnalytics(String period) async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super admin login required');
    }
    return await apiService.get(
          '/super-admin/orders/analytics?period=$period',
          token: token,
        )
        as Map<String, dynamic>;
  }

  Future<List<dynamic>> categories() async {
    final data = await apiService.get('/categories') as List<dynamic>;
    categoryCatalog = data
        .cast<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
    notifyListeners();
    return data;
  }

  Future<List<OrderModel>> allOrdersForRole(String role) async {
    if (token == null || user?.role != role) {
      throw StateError('Login required');
    }
    final data = await apiService.get('/orders', token: token) as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(OrderModel.fromJson).toList();
  }

  Future<void> loadAdminOrders() async {
    if (token == null ||
        (user?.role != UserRoles.admin &&
            user?.role != UserRoles.superAdmin &&
            user?.role != UserRoles.vendor)) {
      return;
    }
    final data = await apiService.get('/orders', token: token) as List<dynamic>;
    final orders = data
        .cast<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList();
    if (user?.role == UserRoles.vendor) {
      final activeVendorId = (vendor?.vendorId ?? user?.vendorId ?? '').trim();
      adminOrders = activeVendorId.isEmpty
          ? orders
          : orders
                .where((order) => order.vendorId.trim() == activeVendorId)
                .toList();
    } else {
      adminOrders = orders;
    }
    notifyListeners();
  }

  void upsertAdminOrder(OrderModel order) {
    if (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin) {
      return;
    }

    final index = adminOrders.indexWhere((existing) => existing.id == order.id);
    if (index == -1) {
      adminOrders = [order, ...adminOrders];
    } else {
      final updated = [...adminOrders];
      updated[index] = order;
      adminOrders = updated;
    }
    notifyListeners();
  }

  Future<OrderModel> updateOrderStatus(
    String orderId,
    String status, {
    String? completionReason,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }

    final data =
        await apiService.patch(
              '/orders/$orderId/status',
              token: token,
              body: {
                'status': status,
                if (completionReason != null &&
                    completionReason.trim().isNotEmpty)
                  'completionReason': completionReason.trim(),
              },
            )
            as Map<String, dynamic>;

    return OrderModel.fromJson(data);
  }

  Future<List<UserModel>> adminUsers() async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.get('/admin/users', token: token) as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(UserModel.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> adminDeliveryPartners() async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.get('/admin/delivery', token: token) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminDeliveryStatusDetails(
    String deliveryPersonId,
  ) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final safeId = Uri.encodeComponent(deliveryPersonId.trim());
    final data =
        await apiService.get(
              '/delivery/status-details?deliveryPersonId=$safeId',
              token: token,
            )
            as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateDeliveryPaymentStatus({
    required String deliveryPersonId,
    required String status,
    num? amount,
    String? reference,
    String? notes,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final safeId = Uri.encodeComponent(deliveryPersonId.trim());
    final payload = <String, dynamic>{
      'status': status,
      if (amount != null) 'amount': amount,
      if (reference != null && reference.trim().isNotEmpty)
        'reference': reference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final data = await apiService.patch(
      '/admin/delivery/$safeId/payment-status',
      body: payload,
      token: token,
    );
    notifyListeners();
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<num> getDeliveryInitialPaymentSetting() async {
    if (token == null) return 500;
    try {
      final res = await apiService.get(
        '/admin/settings/delivery-initial-payment',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final amount = res['amount'] ?? res['value'];
        if (amount is num) return amount;
      }
      return 500;
    } catch (e) {
      debugPrint('[AppState] Failed to get initial payment setting: $e');
      return 500;
    }
  }

  Future<Map<String, dynamic>> updateDeliveryInitialPaymentSetting(
    num amount,
  ) async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super Admin login required');
    }
    final res = await apiService.patch(
      '/admin/settings/delivery-initial-payment',
      body: {'amount': amount},
      token: token,
    );
    notifyListeners();
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<UserModel> updateAdminUserRole(String userId, String role) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.put(
              '/admin/users/$userId',
              token: token,
              body: {'role': role},
            )
            as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<UserModel> updateAdminUser({
    required String userId,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    String? password,
    String? role,
    String? status,
    String? vendorId,
    String? panNumber,
    String? panCardUrl,
    String? licenseNumber,
    String? licenseCardUrl,
    String? aadhaarNumber,
    String? aadhaarCardUrl,
    String? vehicleNumber,
    String? approvalStatus,
    String? rejectionReason,
    double? latitude,
    double? longitude,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (password != null && password.isNotEmpty) 'password': password,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (vendorId != null && vendorId.isNotEmpty) 'vendorId': vendorId,
      if (panNumber != null) 'panNumber': panNumber,
      if (panCardUrl != null) 'panCardUrl': panCardUrl,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (licenseCardUrl != null) 'licenseCardUrl': licenseCardUrl,
      if (aadhaarNumber != null) 'aadhaarNumber': aadhaarNumber,
      if (aadhaarCardUrl != null) 'aadhaarCardUrl': aadhaarCardUrl,
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      if (approvalStatus != null) 'approvalStatus': approvalStatus,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (latitude != null && longitude != null)
        'currentLocation': {'latitude': latitude, 'longitude': longitude},
    };
    final data =
        await apiService.put('/admin/users/$userId', token: token, body: body)
            as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<UserModel> createAdminUser({
    required String name,
    required String phone,
    String email = '',
    String avatarUrl = '',
    String password = '',
    String role = UserRoles.deliveryPerson,
    String status = 'active',
    String? vendorId,
    String panNumber = '',
    String panCardUrl = '',
    String licenseNumber = '',
    String licenseCardUrl = '',
    String aadhaarNumber = '',
    String aadhaarCardUrl = '',
    String vehicleNumber = '',
    double? latitude,
    double? longitude,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.post(
              '/admin/users',
              token: token,
              body: {
                'name': name,
                'phone': phone,
                'email': email,
                'avatarUrl': avatarUrl,
                if (password.isNotEmpty) 'password': password,
                'role': role,
                'status': status,
                if (vendorId != null && vendorId.isNotEmpty)
                  'vendorId': vendorId,
                if (panNumber.isNotEmpty) 'panNumber': panNumber,
                if (panCardUrl.isNotEmpty) 'panCardUrl': panCardUrl,
                if (licenseNumber.isNotEmpty) 'licenseNumber': licenseNumber,
                if (licenseCardUrl.isNotEmpty) 'licenseCardUrl': licenseCardUrl,
                if (aadhaarNumber.isNotEmpty) 'aadhaarNumber': aadhaarNumber,
                if (aadhaarCardUrl.isNotEmpty) 'aadhaarCardUrl': aadhaarCardUrl,
                if (vehicleNumber.isNotEmpty) 'vehicleNumber': vehicleNumber,
                if (latitude != null && longitude != null)
                  'currentLocation': {
                    'latitude': latitude,
                    'longitude': longitude,
                  },
              },
            )
            as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<void> deleteAdminUser(String userId) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    await apiService.delete('/admin/users/$userId', token: token);
  }

  Future<List<VendorModel>> adminVendors() async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super admin login required');
    }
    final data =
        await apiService.get(
              '/super-admin/vendors?_ts=${DateTime.now().millisecondsSinceEpoch}',
              token: token,
            )
            as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(VendorModel.fromJson)
        .toList();
  }

  Future<VendorModel> createVendor({
    required String name,
    String vendorId = '',
    String ownerName = '',
    String phone = '',
    String email = '',
    String password = '',
    String confirmPassword = '',
    String businessType = '',
    String gstin = '',
    String panNumber = '',
    String address = '',
    String pickupAddress = '',
    String city = '',
    String state = '',
    String pincode = '',
    String bankAccountHolderName = '',
    String bankAccountNumber = '',
    String ifscCode = '',
    String logoUrl = '',
    String gstCertificateUrl = '',
    String panCardUrl = '',
    String cancelledChequeUrl = '',
    String shopImageUrl = '',
    List<VendorBusinessHour> businessHours = const [],
    double? pickupLatitude,
    double? pickupLongitude,
    double commissionPercent = 0,
    String status = 'active',
  }) async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super admin login required');
    }
    final data =
        await apiService.post(
              '/super-admin/vendors',
              token: token,
              body: {
                'name': name,
                'vendorId': vendorId.trim(),
                'ownerName': ownerName,
                'phone': phone,
                'email': email,
                'password': password,
                'confirmPassword': confirmPassword,
                'businessType': businessType,
                'gstin': gstin,
                'panNumber': panNumber,
                'address': address,
                'pickupAddress': pickupAddress,
                'city': city,
                'state': state,
                'pincode': pincode,
                'bankAccountHolderName': bankAccountHolderName,
                'bankAccountNumber': bankAccountNumber,
                'ifscCode': ifscCode,
                'logoUrl': logoUrl,
                'gstCertificateUrl': gstCertificateUrl,
                'panCardUrl': panCardUrl,
                'cancelledChequeUrl': cancelledChequeUrl,
                'shopImageUrl': shopImageUrl,
                if (businessHours.isNotEmpty)
                  'businessHours': businessHours
                      .map((hour) => hour.toJson())
                      .toList(),
                if (pickupLatitude != null && pickupLongitude != null)
                  'pickupLocation': {
                    'latitude': pickupLatitude,
                    'longitude': pickupLongitude,
                  },
                'commissionPercent': commissionPercent,
                'status': status,
              },
            )
            as Map<String, dynamic>;
    return VendorModel.fromJson(data);
  }

  Future<VendorModel> updateVendor({
    required String vendorId,
    String? name,
    String? ownerName,
    String? phone,
    String? email,
    String? businessType,
    String? gstin,
    String? panNumber,
    String? address,
    String? pickupAddress,
    String? city,
    String? state,
    String? pincode,
    String? bankAccountHolderName,
    String? bankAccountNumber,
    String? ifscCode,
    String? logoUrl,
    String? gstCertificateUrl,
    String? panCardUrl,
    String? cancelledChequeUrl,
    String? shopImageUrl,
    List<VendorBusinessHour>? businessHours,
    double? pickupLatitude,
    double? pickupLongitude,
    double? commissionPercent,
    String? status,
    String? approvalStatus,
    String? rejectionReason,
  }) async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super admin login required');
    }
    final data =
        await apiService.put(
              '/super-admin/vendors/$vendorId',
              token: token,
              body: {
                if (name != null) 'name': name,
                if (ownerName != null) 'ownerName': ownerName,
                if (phone != null) 'phone': phone,
                if (email != null) 'email': email,
                if (businessType != null) 'businessType': businessType,
                if (gstin != null) 'gstin': gstin,
                if (panNumber != null) 'panNumber': panNumber,
                if (address != null) 'address': address,
                if (pickupAddress != null) 'pickupAddress': pickupAddress,
                if (city != null) 'city': city,
                if (state != null) 'state': state,
                if (pincode != null) 'pincode': pincode,
                if (bankAccountHolderName != null)
                  'bankAccountHolderName': bankAccountHolderName,
                if (bankAccountNumber != null)
                  'bankAccountNumber': bankAccountNumber,
                if (ifscCode != null) 'ifscCode': ifscCode,
                if (logoUrl != null) 'logoUrl': logoUrl,
                if (gstCertificateUrl != null)
                  'gstCertificateUrl': gstCertificateUrl,
                if (panCardUrl != null) 'panCardUrl': panCardUrl,
                if (cancelledChequeUrl != null)
                  'cancelledChequeUrl': cancelledChequeUrl,
                if (shopImageUrl != null) 'shopImageUrl': shopImageUrl,
                if (businessHours != null)
                  'businessHours': businessHours
                      .map((hour) => hour.toJson())
                      .toList(),
                if (pickupLatitude != null && pickupLongitude != null)
                  'pickupLocation': {
                    'latitude': pickupLatitude,
                    'longitude': pickupLongitude,
                  },
                if (commissionPercent != null)
                  'commissionPercent': commissionPercent,
                if (status != null) 'status': status,
                if (approvalStatus != null) 'approvalStatus': approvalStatus,
                if (rejectionReason != null) 'rejectionReason': rejectionReason,
              },
            )
            as Map<String, dynamic>;
    return VendorModel.fromJson(data);
  }

  Future<void> deleteVendor(String vendorId) async {
    if (token == null || user?.role != UserRoles.superAdmin) {
      throw StateError('Super admin login required');
    }
    await apiService.delete('/super-admin/vendors/$vendorId', token: token);
  }

  Future<List<BannerModel>> adminBanners() async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.get('/admin/banners', token: token) as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(BannerModel.fromJson).toList();
  }

  Future<BannerModel> createBanner({
    required String title,
    required String imageUrl,
    bool active = true,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.post(
              '/admin/banners',
              token: token,
              body: {'title': title, 'imageUrl': imageUrl, 'active': active},
            )
            as Map<String, dynamic>;
    await loadBanners();
    return BannerModel.fromJson(data);
  }

  Future<BannerModel> updateBanner({
    required String bannerId,
    required String title,
    required String imageUrl,
    bool active = true,
  }) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    final data =
        await apiService.put(
              '/admin/banners/$bannerId',
              token: token,
              body: {'title': title, 'imageUrl': imageUrl, 'active': active},
            )
            as Map<String, dynamic>;
    await loadBanners();
    return BannerModel.fromJson(data);
  }

  Future<void> deleteBanner(String bannerId) async {
    if (token == null ||
        (user?.role != UserRoles.admin && user?.role != UserRoles.superAdmin)) {
      throw StateError('Admin login required');
    }
    await apiService.delete('/admin/banners/$bannerId', token: token);
    await loadBanners();
  }

  Future<List<OrderModel>> availableDeliveryOrders() async {
    if (token == null || user?.role != UserRoles.deliveryPerson) {
      throw StateError('Delivery login required');
    }
    final data =
        await apiService.get('/delivery/available-orders', token: token)
            as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(OrderModel.fromJson).toList();
  }

  Future<List<OrderModel>> deliveryOrderHistory() async {
    if (token == null || user?.role != UserRoles.deliveryPerson) {
      throw StateError('Delivery login required');
    }
    final data =
        await apiService.get('/delivery/history', token: token)
            as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(OrderModel.fromJson).toList();
  }

  Future<OrderModel> acceptDeliveryOrder(String orderId) async {
    if (token == null || user?.role != UserRoles.deliveryPerson) {
      throw StateError('Delivery login required');
    }
    final data =
        await apiService.post('/delivery/accept/$orderId', token: token)
            as Map<String, dynamic>;
    final order = OrderModel.fromJson(data);
    await loadOrders();
    return order;
  }

  Future<OrderModel> pickupDeliveryOrder(String orderId) async {
    if (token == null || user?.role != UserRoles.deliveryPerson) {
      throw StateError('Delivery login required');
    }
    final data =
        await apiService.post('/delivery/pickup/$orderId', token: token)
            as Map<String, dynamic>;
    final order = OrderModel.fromJson(data);
    await loadOrders();
    return order;
  }

  Future<OrderModel> deliverDeliveryOrder(String orderId) async {
    if (token == null || user?.role != UserRoles.deliveryPerson) {
      throw StateError('Delivery login required');
    }
    final data =
        await apiService.post('/delivery/delivered/$orderId', token: token)
            as Map<String, dynamic>;
    final order = OrderModel.fromJson(data);
    await loadOrders();
    return order;
  }

  Future<List<dynamic>> notificationsForRole(String role) async {
    if (token == null || user?.role != role) {
      throw StateError('Login required');
    }
    return await apiService.get('/notifications', token: token)
        as List<dynamic>;
  }

  Future<List<AddressModel>> addresses() async {
    if (token == null) throw StateError('Please login first');
    return await loadAddresses();
  }

  Future<List<AddressModel>> loadAddresses() async {
    if (token == null) return <AddressModel>[];
    final data =
        await apiService.get('/addresses', token: token) as List<dynamic>;
    savedAddresses = data
        .whereType<Map<String, dynamic>>()
        .map(AddressModel.fromJson)
        .toList();
    if (savedAddresses.isEmpty) {
      selectedAddress = null;
    } else if (selectedAddress == null ||
        !savedAddresses.any((address) => address.id == selectedAddress!.id)) {
      selectedAddress = savedAddresses.first;
    }
    notifyListeners();
    return savedAddresses;
  }

  Future<AddressModel> createAddress({
    required String label,
    required String line1,
    required String city,
    required String pincode,
    String area = '',
    String landmark = '',
    String state = '',
    double? latitude,
    double? longitude,
  }) async {
    if (token == null) throw StateError('Please login first');
    final data =
        await apiService.post(
              '/addresses',
              token: token,
              body: {
                'label': label,
                'line1': line1,
                'area': area,
                'landmark': landmark,
                'city': city,
                'state': state,
                'pincode': pincode,
                'location': latitude != null && longitude != null
                    ? {'latitude': latitude, 'longitude': longitude}
                    : null,
              },
            )
            as Map<String, dynamic>;
    final address = AddressModel.fromJson(data);
    await loadAddresses();
    return address;
  }

  Future<AddressModel> updateAddress({
    required String addressId,
    required String label,
    required String line1,
    required String city,
    required String pincode,
    String area = '',
    String landmark = '',
    String state = '',
    double? latitude,
    double? longitude,
  }) async {
    if (token == null) throw StateError('Please login first');
    final data =
        await apiService.put(
              '/addresses/$addressId',
              token: token,
              body: {
                'label': label,
                'line1': line1,
                'area': area,
                'landmark': landmark,
                'city': city,
                'state': state,
                'pincode': pincode,
                'location': latitude != null && longitude != null
                    ? {'latitude': latitude, 'longitude': longitude}
                    : null,
              },
            )
            as Map<String, dynamic>;
    final address = AddressModel.fromJson(data);
    await loadAddresses();
    return address;
  }

  Future<void> deleteAddress(String addressId) async {
    if (token == null) throw StateError('Please login first');
    await apiService.delete('/addresses/$addressId', token: token);
    await loadAddresses();
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (token == null) throw StateError('Please login first');
    await apiService.put('/addresses/default/$addressId', token: token);
    await loadAddresses();
  }

  Future<List<dynamic>> scheduledOrders() async {
    if (token == null) throw StateError('Please login first');
    return await apiService.get('/orders/scheduled', token: token)
        as List<dynamic>;
  }

  Future<Map<String, dynamic>> deliveryEarnings() async {
    if (token == null || user?.role != UserRoles.deliveryPerson) {
      throw StateError('Delivery login required');
    }
    return await apiService.get('/delivery/earnings', token: token)
        as Map<String, dynamic>;
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool silent = false,
  }) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      await action();
      error = null;
    } catch (exception) {
      if (!silent) error = exception.toString();
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreSession() async {
    if (token == null) return;
    try {
      final data =
          await apiService.get('/auth/me', token: token)
              as Map<String, dynamic>;
      final currentUser = data['user'];
      if (currentUser is Map<String, dynamic>) {
        user = UserModel.fromJson(currentUser);
        await _persistSession();
        await loadOrders();
        await loadCart();
        await loadAddresses();
        _connectSocket();
        if (user?.role == UserRoles.admin ||
            user?.role == UserRoles.superAdmin) {
          await loadProducts();
          await loadAdminOrders();
        }
      }
    } catch (_) {
      if (user?.role == UserRoles.user || user?.role == null) {
        token = null;
        user = null;
        await _sessionService.clearSession();
      }
    }
  }

  Future<void> _persistSession() async {
    if (token != null && user != null) {
      await _sessionService.saveSession(token: token!, user: user!);
    }
  }

  void _connectSocket() {
    if (token == null || socketService.connected) return;
    socketService.connect(
      token: token,
      userId: user?.id,
      onOrderCreated: (data) async {
        debugPrint('Socket order created event received; reloading orders.');
        dashboardRefreshTick++;
        if (data is Map<String, dynamic>) {
          final order = OrderModel.fromJson(data);
          if (user?.role == UserRoles.admin ||
              user?.role == UserRoles.superAdmin) {
            upsertAdminOrder(order);
          }
          if (user?.role == UserRoles.user) {
            final index = orders.indexWhere(
              (existing) => existing.id == order.id,
            );
            if (index == -1) {
              orders = [order, ...orders];
            } else {
              final updated = [...orders];
              updated[index] = order;
              orders = updated;
            }
            notifyListeners();
          }
        }
        await loadOrders();
        await loadAdminOrders();
      },
      onOrderAccepted: (_) async {
        debugPrint('Socket order accepted event received; reloading orders.');
        dashboardRefreshTick++;
        await loadOrders();
        await loadAdminOrders();
      },
      onOrderPickedUp: (_) async {
        debugPrint('Socket order picked up event received; reloading orders.');
        dashboardRefreshTick++;
        await loadOrders();
        await loadAdminOrders();
      },
      onOrderDelivered: (_) async {
        debugPrint('Socket order delivered event received; reloading orders.');
        dashboardRefreshTick++;
        final messenger = DoormartDeliveryApp.scaffoldMessengerKey.currentState;
        await loadOrders();
        await loadAdminOrders();
        if (messenger != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Order delivered successfully'),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
              ),
            );
        }
      },
      onStockUpdated: (_) async {
        debugPrint('Socket stock updated event received; reloading products.');
        dashboardRefreshTick++;
        await loadProducts();
        if (user?.role == UserRoles.admin ||
            user?.role == UserRoles.vendor ||
            user?.role == UserRoles.superAdmin) {
          await loadAdminOrders();
        }
        notifyListeners();
      },
    );
    if (user?.id.isNotEmpty == true) {
      debugPrint('Socket connecting for user room: user:${user!.id}');
    }
  }

  Future<void> loadCart() async {
    if (token == null) return;
    final data = await apiService.get('/cart', token: token);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? [])
        : <dynamic>[];
    cart
      ..clear()
      ..addAll(
        items.whereType<Map<String, dynamic>>().map((item) {
          final productJson = item['product'];
          if (productJson is! Map<String, dynamic>) {
            return null;
          }
          final quantity = item['quantity'];
          if (quantity is! num) {
            return null;
          }
          final unit = item['unit'] as String?;
          final price = (item['price'] as num?)?.toDouble();
          final discountCost = (item['discountCost'] as num?)?.toDouble();
          final stock = (item['stock'] as num?)?.toInt();
          return CartLine(
            product: ProductModel.fromJson(productJson),
            quantity: quantity.toInt(),
            unit: unit,
            price: price,
            discountCost: discountCost,
            stock: stock,
          );
        }).whereType<CartLine>(),
      );
    notifyListeners();
  }

  /// Refreshes only the store open/closed status of items already in the cart
  /// without replacing the local cart, so a store that closes after an item was
  /// added is reflected on the cart page (and freshly added items are kept).
  Future<void> refreshCartStoreStatus() async {
    if (token == null || cart.isEmpty) return;
    final Map<String, ProductModel> freshProducts = {};
    try {
      final data = await apiService.get('/cart', token: token);
      final items = data is Map<String, dynamic>
          ? (data['items'] as List<dynamic>? ?? [])
          : <dynamic>[];
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final productJson = item['product'];
        if (productJson is! Map<String, dynamic>) continue;
        final product = ProductModel.fromJson(productJson);
        if (product.id.isEmpty) continue;
        freshProducts[product.id] = product;
      }
    } catch (_) {
      return;
    }
    var changed = false;
    for (var i = 0; i < cart.length; i++) {
      final line = cart[i];
      final updated = freshProducts[line.product.id];
      if (updated == null || updated.vendorIsOpen == null) continue;
      if (updated.vendorIsOpen == line.product.vendorIsOpen &&
          updated.vendorTodayOpenTime == line.product.vendorTodayOpenTime &&
          updated.vendorTodayCloseTime == line.product.vendorTodayCloseTime) {
        continue;
      }
      cart[i] = CartLine(
        product: updated,
        quantity: line.quantity,
        unit: line.unit,
        price: line.price,
        discountCost: line.discountCost,
        stock: line.stock,
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<bool> _syncAddToCart(
    ProductModel product, {
    int quantity = 1,
    String? unit,
    double? price,
    double? discountCost,
    int? stock,
  }) async {
    if (token == null) {
      error = 'Please login first';
      notifyListeners();
      return false;
    }
    if (!isProductNearUser(product)) {
      error = 'This product is not available near your location';
      notifyListeners();
      return false;
    }
    if (product.vendorIsOpen == false) {
      error = 'This store is closed right now';
      notifyListeners();
      return false;
    }
    final snapshot = _cloneCart();
    final mutationToken = _nextCartMutationToken();
    final selectedUnit = (unit ?? product.unit).trim();
    _setCartQuantity(
      product,
      (cart
              .firstWhere(
                (line) =>
                    line.key == '${product.id}::${selectedUnit.toLowerCase()}',
                orElse: () => CartLine(
                  product: product,
                  quantity: 0,
                  unit: selectedUnit,
                  price: price,
                  discountCost: discountCost,
                  stock: stock,
                ),
              )
              .quantity) +
          quantity,
      unit: selectedUnit,
      price: price,
      discountCost: discountCost,
      stock: stock,
    );
    error = null;
    notifyListeners();
    unawaited(
      _syncCartMutation(
        mutationToken: mutationToken,
        snapshot: snapshot,
        action: () async {
          await apiService.post(
            '/cart/add',
            token: token,
            body: {
              'productId': product.id,
              'quantity': quantity,
              if (selectedUnit.isNotEmpty) 'unit': selectedUnit,
              if (price != null) 'price': price,
              if (discountCost != null) 'discountCost': discountCost,
              if (stock != null) 'stock': stock,
            },
          );
        },
      ),
    );
    return true;
  }

  Future<bool> _syncDecrement(ProductModel product, {String? unit}) async {
    if (token == null) {
      error = 'Please login first';
      notifyListeners();
      return false;
    }
    final selectedUnit = (unit ?? product.unit).trim();
    final current = cart.firstWhere(
      (line) => line.key == '${product.id}::${selectedUnit.toLowerCase()}',
      orElse: () => CartLine(product: product, quantity: 0, unit: selectedUnit),
    );
    final snapshot = _cloneCart();
    final mutationToken = _nextCartMutationToken();
    final nextQuantity = current.quantity <= 1 ? 0 : current.quantity - 1;
    _setCartQuantity(
      product,
      nextQuantity,
      unit: selectedUnit,
      price: current.price,
      discountCost: current.discountCost,
      stock: current.stock,
    );
    error = null;
    notifyListeners();
    unawaited(
      _syncCartMutation(
        mutationToken: mutationToken,
        snapshot: snapshot,
        action: () async {
          if (current.quantity <= 1) {
            await apiService.delete(
              '/cart/remove/${product.id}?unit=${Uri.encodeComponent(selectedUnit)}',
              token: token,
            );
            return;
          }
          await apiService.put(
            '/cart/update',
            token: token,
            body: {
              'productId': product.id,
              'quantity': nextQuantity,
              'unit': selectedUnit,
            },
          );
        },
      ),
    );
    return true;
  }

  Future<bool> _syncClearCart() async {
    if (token == null) {
      error = 'Please login first';
      notifyListeners();
      return false;
    }
    final snapshot = _cloneCart();
    final mutationToken = _nextCartMutationToken();
    cart.clear();
    checkoutSummary = null;
    error = null;
    notifyListeners();
    unawaited(
      _syncCartMutation(
        mutationToken: mutationToken,
        snapshot: snapshot,
        action: () async {
          await apiService.delete('/cart/clear', token: token);
        },
      ),
    );
    return true;
  }
}
