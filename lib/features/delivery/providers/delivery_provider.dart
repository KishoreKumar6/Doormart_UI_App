import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../../../services/api_service.dart';
import '../../../notifications/firebase_messaging_service.dart';
import '../../../models/user_model.dart';
import '../../../services/session_service.dart';
import '../../operations/services/location_service.dart';
import '../models/delivery_order_model.dart';
import '../models/delivery_person_model.dart';
import '../services/delivery_api_service.dart';
import '../services/delivery_socket_service.dart';

class DeliveryProvider extends ChangeNotifier {
  DeliveryProvider({
    DeliveryApiService? apiService,
    DeliverySocketService? socketService,
    FirebaseMessagingService? messagingService,
    LocationService? locationService,
  }) : apiService = apiService ?? DeliveryApiService(),
       socketService = socketService ?? DeliverySocketService(),
       locationService = locationService ?? LocationService(),
       _messagingService = messagingService ?? FirebaseMessagingService();

  final DeliveryApiService apiService;
  final DeliverySocketService socketService;
  final LocationService locationService;
  final FirebaseMessagingService _messagingService;

  bool loading = false;
  String? error;
  String? authToken;
  Map<String, dynamic>? authUser;
  DeliveryPersonModel? deliveryPerson;
  DeliveryOrderModel? activeOrder;
  final List<DeliveryOrderModel> pendingRequests = [];
  final List<DeliveryOrderModel> history = [];
  Map<String, dynamic> earningsStats = const {};
  List<Map<String, dynamic>> statusDetails = [];
  bool online = false;
  Timer? _requestRefreshTimer;
  Timer? _locationPublishTimer;
  Timer? _availabilityLocationTimer;
  static const _deliveryTokenKey = 'delivery_auth_token';
  static const _deliveryUserKey = 'delivery_auth_user';

  // Initial Payment state
  bool initialPaymentLoading = false;
  bool initialPaymentVerifying = false;
  String? initialPaymentError;
  double initialPaymentAmount = 500.0;
  String initialPaymentStatus = 'NOT_PAID';
  DateTime? initialPaymentCompletedAt;
  String? initialPaymentMethod;
  String? initialPaymentReference;
  String? initialPaymentSource;

  bool get isInitialPaymentPaid =>
      initialPaymentStatus.trim().toUpperCase() == 'PAID' ||
      (deliveryPerson?.isInitialPaymentPaid ?? false);

  bool get isInitialPaymentRequired => !isInitialPaymentPaid;

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken ??= prefs.getString(_deliveryTokenKey);
      if (authToken == null || authToken!.isEmpty) {
        final sessionToken = await SessionService().getToken();
        if (sessionToken != null && sessionToken.isNotEmpty) {
          authToken = sessionToken;
        }
      }
      final rawUser = prefs.getString(_deliveryUserKey);
      if (rawUser != null && rawUser.isNotEmpty) {
        authUser ??= Map<String, dynamic>.from(
          jsonDecode(rawUser) as Map<String, dynamic>,
        );
      }
      if (authUser == null) {
        final savedUser = await SessionService().getSavedUser();
        if (savedUser != null) {
          authUser = savedUser.toJson();
        }
      }
      if (deliveryPerson == null && authUser != null) {
        final u = UserModel.fromJson(authUser!);
        hydrateFromSession(token: authToken ?? '', user: u);
      }
      if (authToken != null && authToken!.isNotEmpty) {
        await syncOnlineState();
        await syncInitialPaymentStatus(notify: false);
      }
    } catch (e) {
      debugPrint('Delivery bootstrap skipped: $e');
    }
  }

  void hydrateFromSession({required String token, required UserModel user}) {
    authToken = token;
    authUser = user.toJson();
    final pStatus =
        (authUser?['initialPaymentStatus'] as String?) ?? 'NOT_PAID';
    final pAmount =
        (authUser?['initialPaymentAmount'] as num? ?? initialPaymentAmount)
            .toDouble();
    initialPaymentStatus = pStatus;
    if (pAmount > 0) {
      initialPaymentAmount = pAmount;
    }

    deliveryPerson =
        (deliveryPerson ??
                DeliveryPersonModel(
                  id: user.id,
                  name: user.name,
                  phone: user.phone,
                  vehicleNumber: '',
                  licenseNumber: '',
                  status: user.status,
                  isOnline: false,
                  active: true,
                  completedOrders: 0,
                  todayEarnings: 0,
                  avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                  licenseCardUrl: null,
                  initialPaymentStatus: pStatus,
                  isPaymentRequired: pStatus.trim().toUpperCase() != 'PAID',
                  initialPaymentAmount: initialPaymentAmount,
                ))
            .copyWith(
              id: user.id,
              name: user.name,
              phone: user.phone,
              status: user.status,
              initialPaymentStatus: pStatus,
              isPaymentRequired: pStatus.trim().toUpperCase() != 'PAID',
              initialPaymentAmount: initialPaymentAmount,
            );
    notifyListeners();
  }

  String? _resolveAvatarUrl({
    Map<String, dynamic>? user,
    Map<String, dynamic>? delivery,
  }) {
    final avatar = (delivery?['avatarUrl'] as String?)?.trim();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    final userAvatar = (user?['avatarUrl'] as String?)?.trim();
    if (userAvatar != null && userAvatar.isNotEmpty) return userAvatar;
    final savedAvatar = authUser?['avatarUrl']?.toString().trim();
    if (savedAvatar != null && savedAvatar.isNotEmpty) return savedAvatar;
    return deliveryPerson?.avatarUrl?.trim().isNotEmpty == true
        ? deliveryPerson!.avatarUrl
        : null;
  }

  String _resolveDisplayName({
    Map<String, dynamic>? user,
    Map<String, dynamic>? delivery,
  }) {
    final deliveryName = (delivery?['name'] as String?)?.trim();
    if (deliveryName != null && deliveryName.isNotEmpty) return deliveryName;
    final userName = (user?['name'] as String?)?.trim();
    if (userName != null && userName.isNotEmpty) return userName;
    final savedName = (authUser?['name']?.toString().trim() ?? '');
    if (savedName.isNotEmpty) return savedName;
    return deliveryPerson?.name.isNotEmpty == true
        ? deliveryPerson!.name
        : 'Delivery Person';
  }

  Future<bool> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final response = await _run(() async {
      return apiService.login(email: email, phone: phone, password: password);
    });

    final user = response['user'] as Map<String, dynamic>;
    final delivery = response['deliveryPerson'] as Map<String, dynamic>?;
    authToken = response['token'] as String?;
    authUser = user;
    final role = (user['role'] as String? ?? '').toLowerCase();
    final status = (user['status'] as String? ?? '').toLowerCase();
    if (role != UserRoles.deliveryPerson) {
      throw StateError('Access denied: not a delivery person.');
    }
    if (status != 'active') {
      throw StateError('Access denied: delivery person is inactive.');
    }
    final pStatus =
        delivery?['initialPaymentStatus'] as String? ??
        user['initialPaymentStatus'] as String? ??
        'NOT_PAID';
    final pAmount =
        (delivery?['initialPaymentAmount'] as num? ??
                user['initialPaymentAmount'] as num? ??
                500.0)
            .toDouble();
    initialPaymentStatus = pStatus;
    initialPaymentAmount = pAmount;
    final completedAtStr =
        delivery?['initialPaymentCompletedAt'] as String? ??
        user['initialPaymentCompletedAt'] as String?;
    initialPaymentCompletedAt = completedAtStr != null
        ? DateTime.tryParse(completedAtStr)
        : null;
    initialPaymentMethod =
        delivery?['initialPaymentMethod'] as String? ??
        user['initialPaymentMethod'] as String?;
    initialPaymentReference =
        delivery?['initialPaymentReference'] as String? ??
        user['initialPaymentReference'] as String?;
    initialPaymentSource =
        delivery?['initialPaymentSource'] as String? ??
        user['initialPaymentSource'] as String?;

    deliveryPerson = DeliveryPersonModel(
      id: user['_id'] as String? ?? user['id'] as String? ?? '',
      name: _resolveDisplayName(user: user, delivery: delivery),
      phone: user['phone'] as String? ?? '',
      vehicleNumber:
          delivery?['vehicleNumber'] as String? ??
          user['vehicleNumber'] as String? ??
          '',
      licenseNumber:
          delivery?['licenseNumber'] as String? ??
          user['licenseNumber'] as String? ??
          '',
      status: status,
      isOnline: false,
      active: (delivery?['active'] as bool?) ?? true,
      completedOrders: (user['completedOrders'] as num? ?? 0).toInt(),
      todayEarnings: (user['todayEarnings'] as num? ?? 0).toDouble(),
      avatarUrl: _resolveAvatarUrl(user: user, delivery: delivery),
      licenseCardUrl:
          delivery?['licenseCardUrl'] as String? ??
          user['licenseCardUrl'] as String?,
      initialPaymentStatus: pStatus,
      isPaymentRequired: pStatus.trim().toUpperCase() != 'PAID',
      initialPaymentAmount: pAmount,
      initialPaymentCompletedAt: initialPaymentCompletedAt,
      initialPaymentMethod: initialPaymentMethod,
      initialPaymentReference: initialPaymentReference,
      initialPaymentSource: initialPaymentSource,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deliveryTokenKey, authToken ?? '');
    await prefs.setString(_deliveryUserKey, jsonEncode(user));
    if (authToken != null && authToken!.isNotEmpty) {
      unawaited(_messagingService.registerTokenSync(authToken: authToken!));
    }
    return true;
  }

  Future<void> loadDashboard() async {
    if (deliveryPerson == null) return;
    try {
      await _run(() async {
        if (!isInitialPaymentRequired) {
          try {
            final available = await apiService
                .fetchAvailableOrders(
                  deliveryPersonId: deliveryPerson!.id,
                  token: authToken,
                )
                .timeout(const Duration(seconds: 8));
            pendingRequests
              ..clear()
              ..addAll(available);
          } on ApiException catch (e) {
            if (e.code == 'INITIAL_PAYMENT_REQUIRED' || e.statusCode == 403) {
              initialPaymentStatus = 'NOT_PAID';
              pendingRequests.clear();
            } else {
              rethrow;
            }
          }
        } else {
          pendingRequests.clear();
        }

        final fetchedActive = await apiService
            .fetchActiveOrder(
              deliveryPersonId: deliveryPerson!.id,
              token: authToken,
            )
            .timeout(const Duration(seconds: 8));
        if (fetchedActive != null) {
          activeOrder = _forceAccepted(fetchedActive);
        } else {
          activeOrder = null;
        }
        history
          ..clear()
          ..addAll(
            await apiService
                .fetchHistory(
                  deliveryPersonId: deliveryPerson!.id,
                  token: authToken,
                )
                .timeout(const Duration(seconds: 8)),
          );
        final earnings = await apiService
            .fetchEarnings(
              deliveryPersonId: deliveryPerson!.id,
              token: authToken,
            )
            .timeout(const Duration(seconds: 8));
        earningsStats = earnings;
        final totalEarnings =
            (earnings['total'] as num?)?.toDouble() ??
            history.fold<double>(
              0,
              (sum, order) => sum + (order.deliveryEarning ?? 45),
            );
        deliveryPerson = deliveryPerson!.copyWith(
          completedOrders:
              (earnings['completedOrders'] as num? ?? history.length).toInt(),
          todayEarnings: totalEarnings,
          initialPaymentStatus: initialPaymentStatus,
          isPaymentRequired: isInitialPaymentRequired,
          initialPaymentAmount: initialPaymentAmount,
          initialPaymentCompletedAt: initialPaymentCompletedAt,
          initialPaymentMethod: initialPaymentMethod,
          initialPaymentReference: initialPaymentReference,
          initialPaymentSource: initialPaymentSource,
        );
      });
      _syncLiveLocationTracking();
    } catch (e) {
      debugPrint('Delivery dashboard load skipped: $e');
    }
  }

  Future<String?> register({
    required String name,
    required String phone,
    String? email,
    String? avatarUrl,
    required String password,
    String? vehicleNumber,
    String? panNumber,
    String? panCardUrl,
    String? licenseNumber,
    String? licenseCardUrl,
    String? aadhaarNumber,
    String? aadhaarCardUrl,
  }) async {
    try {
      loading = true;
      error = null;
      notifyListeners();

      final response = await _run(() {
        return apiService.register(
          name: name,
          phone: phone,
          email: email,
          avatarUrl: avatarUrl,
          password: password,
          vehicleNumber: vehicleNumber,
          panNumber: panNumber,
          panCardUrl: panCardUrl,
          licenseNumber: licenseNumber,
          licenseCardUrl: licenseCardUrl,
          aadhaarNumber: aadhaarNumber,
          aadhaarCardUrl: aadhaarCardUrl,
        );
      });

      final user = response['user'] as Map<String, dynamic>;
      final delivery = response['deliveryPerson'] as Map<String, dynamic>?;
      authToken = response['token'] as String?;
      authUser = user;
      deliveryPerson = DeliveryPersonModel(
        id: user['_id'] as String? ?? user['id'] as String? ?? '',
        name: _resolveDisplayName(user: user, delivery: delivery),
        phone: user['phone'] as String? ?? phone,
        vehicleNumber:
            delivery?['vehicleNumber'] as String? ??
            vehicleNumber?.trim() ??
            '',
        status: (user['status'] as String? ?? 'active').toLowerCase(),
        isOnline: false,
        active: (delivery?['active'] as bool?) ?? false,
        completedOrders: (delivery?['completedOrders'] as num? ?? 0).toInt(),
        todayEarnings: (delivery?['todayEarnings'] as num? ?? 0).toDouble(),
        avatarUrl: _resolveAvatarUrl(user: user, delivery: delivery),
        panNumber: delivery?['panNumber'] as String? ?? panNumber?.trim() ?? '',
        panCardUrl: delivery?['panCardUrl'] as String? ?? panCardUrl,
        licenseNumber:
            delivery?['licenseNumber'] as String? ??
            licenseNumber?.trim() ??
            '',
        licenseCardUrl:
            delivery?['licenseCardUrl'] as String? ?? licenseCardUrl,
        aadhaarNumber:
            delivery?['aadhaarNumber'] as String? ??
            aadhaarNumber?.trim() ??
            '',
        aadhaarCardUrl:
            delivery?['aadhaarCardUrl'] as String? ?? aadhaarCardUrl,
      );

      final prefs = await SharedPreferences.getInstance();
      if (authToken != null && authToken!.isNotEmpty) {
        await prefs.setString(_deliveryTokenKey, authToken!);
      }
      await prefs.setString(_deliveryUserKey, jsonEncode(user));
      if (authToken != null && authToken!.isNotEmpty) {
        unawaited(_messagingService.registerTokenSync(authToken: authToken!));
      }
      return null;
    } catch (e) {
      error = e.toString();
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (authToken == null) return;
    final response = await apiService.fetchProfile(token: authToken);
    final user = response['user'] as Map<String, dynamic>?;
    final delivery = response['deliveryPerson'] as Map<String, dynamic>?;
    if (user == null) return;
    authUser = user;

    final pStatus =
        delivery?['initialPaymentStatus'] as String? ??
        user['initialPaymentStatus'] as String?;
    if (pStatus != null && pStatus.isNotEmpty) {
      initialPaymentStatus = pStatus;
    }
    final pAmount =
        (delivery?['initialPaymentAmount'] as num? ??
                user['initialPaymentAmount'] as num?)
            ?.toDouble();
    if (pAmount != null && pAmount > 0) {
      initialPaymentAmount = pAmount;
    }
    final completedAtStr =
        delivery?['initialPaymentCompletedAt'] as String? ??
        user['initialPaymentCompletedAt'] as String?;
    if (completedAtStr != null) {
      initialPaymentCompletedAt = DateTime.tryParse(completedAtStr);
    }
    initialPaymentMethod =
        delivery?['initialPaymentMethod'] as String? ??
        user['initialPaymentMethod'] as String? ??
        initialPaymentMethod;
    initialPaymentReference =
        delivery?['initialPaymentReference'] as String? ??
        user['initialPaymentReference'] as String? ??
        initialPaymentReference;
    initialPaymentSource =
        delivery?['initialPaymentSource'] as String? ??
        user['initialPaymentSource'] as String? ??
        initialPaymentSource;

    deliveryPerson =
        (deliveryPerson ?? DeliveryPersonModel.fromJson(delivery ?? user))
            .copyWith(
              id:
                  user['_id'] as String? ??
                  user['id'] as String? ??
                  deliveryPerson?.id ??
                  '',
              name: _resolveDisplayName(user: user, delivery: delivery),
              phone: user['phone'] as String? ?? deliveryPerson?.phone ?? '',
              vehicleNumber:
                  delivery?['vehicleNumber'] as String? ??
                  deliveryPerson?.vehicleNumber ??
                  '',
              status:
                  user['status'] as String? ??
                  deliveryPerson?.status ??
                  'active',
              isOnline:
                  delivery?['isOnline'] as bool? ??
                  deliveryPerson?.isOnline ??
                  false,
              active: deliveryPerson?.active ?? true,
              completedOrders: deliveryPerson?.completedOrders ?? 0,
              todayEarnings: deliveryPerson?.todayEarnings ?? 0,
              avatarUrl: _resolveAvatarUrl(user: user, delivery: delivery),
              licenseNumber:
                  delivery?['licenseNumber'] as String? ??
                  deliveryPerson?.licenseNumber ??
                  '',
              licenseCardUrl:
                  delivery?['licenseCardUrl'] as String? ??
                  deliveryPerson?.licenseCardUrl,
              initialPaymentStatus: initialPaymentStatus,
              isPaymentRequired: isInitialPaymentRequired,
              initialPaymentAmount: initialPaymentAmount,
              initialPaymentCompletedAt: initialPaymentCompletedAt,
              initialPaymentMethod: initialPaymentMethod,
              initialPaymentReference: initialPaymentReference,
              initialPaymentSource: initialPaymentSource,
            );
    notifyListeners();
  }

  Future<String?> updateProfile({String? phone, String? vehicleNumber}) async {
    if (deliveryPerson == null) return 'Login required';
    try {
      final response = await apiService.updateProfile(
        token: authToken,
        phone: phone,
        vehicleNumber: vehicleNumber,
      );
      final user = response['user'] as Map<String, dynamic>?;
      final delivery = response['deliveryPerson'] as Map<String, dynamic>?;
      if (user != null) {
        authUser = user;
      }
      deliveryPerson = deliveryPerson!.copyWith(
        id:
            user?['_id'] as String? ??
            user?['id'] as String? ??
            deliveryPerson!.id,
        name: user?['name'] as String? ?? deliveryPerson!.name,
        phone: user?['phone'] as String? ?? deliveryPerson!.phone,
        vehicleNumber:
            delivery?['vehicleNumber'] as String? ??
            deliveryPerson!.vehicleNumber,
        licenseNumber:
            delivery?['licenseNumber'] as String? ??
            deliveryPerson!.licenseNumber,
        status: user?['status'] as String? ?? deliveryPerson!.status,
        isOnline: delivery?['isOnline'] as bool? ?? deliveryPerson!.isOnline,
        active: deliveryPerson!.active,
        completedOrders: deliveryPerson!.completedOrders,
        todayEarnings: deliveryPerson!.todayEarnings,
        avatarUrl: deliveryPerson!.avatarUrl,
        licenseCardUrl: deliveryPerson!.licenseCardUrl,
      );
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> loadStatusDetails() async {
    if (deliveryPerson == null || authToken == null) return;
    statusDetails = await apiService.fetchStatusDetails(token: authToken);
    notifyListeners();
  }

  Future<void> syncOnlineState() async {
    if (authToken == null) return;
    try {
      final response = await apiService.fetchStatus(token: authToken);
      final delivery = response['deliveryPerson'] as Map<String, dynamic>?;
      final user = response['user'] as Map<String, dynamic>?;
      if (user != null) {
        authUser = user;
      }
      if (delivery != null) {
        deliveryPerson = DeliveryPersonModel.fromJson({
          ...delivery,
          if (delivery['name'] == null && user?['name'] != null)
            'name': user!['name'],
          if (delivery['phone'] == null && user?['phone'] != null)
            'phone': user!['phone'],
        });
      }
      final pStatus =
          delivery?['initialPaymentStatus'] as String? ??
          user?['initialPaymentStatus'] as String? ??
          response['initialPaymentStatus'] as String?;
      if (pStatus != null && pStatus.isNotEmpty) {
        initialPaymentStatus = pStatus;
      }
      final pAmount =
          (delivery?['initialPaymentAmount'] as num? ??
                  user?['initialPaymentAmount'] as num? ??
                  response['initialPaymentAmount'] as num?)
              ?.toDouble();
      if (pAmount != null && pAmount > 0) {
        initialPaymentAmount = pAmount;
      }
      if (deliveryPerson != null) {
        deliveryPerson = deliveryPerson!.copyWith(
          initialPaymentStatus: initialPaymentStatus,
          isPaymentRequired: isInitialPaymentRequired,
          initialPaymentAmount: initialPaymentAmount,
        );
      }
      online =
          deliveryPerson?.isOnline ?? (response['isOnline'] as bool?) ?? false;
      if (online && deliveryPerson != null && !socketService.isConnected) {
        _connectRealtimeChannel();
        _startRequestRefresh();
        _startAvailabilityLocationUpdates();
      } else if (!online) {
        socketService.disconnect();
        _stopRequestRefresh();
        _stopAvailabilityLocationUpdates();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Delivery status sync skipped: $e');
    }
  }

  Future<void> goOnline() async {
    if (deliveryPerson == null) {
      if (authUser != null) {
        hydrateFromSession(
          token: authToken ?? '',
          user: UserModel.fromJson(authUser!),
        );
      } else {
        throw const ApiException(
          'Delivery person account not loaded. Please log in again.',
          401,
          code: 'UNAUTHENTICATED',
        );
      }
    }
    if (isInitialPaymentRequired) {
      throw const ApiException(
        'Complete your one-time onboarding payment to start working and receive delivery orders.',
        403,
        code: 'INITIAL_PAYMENT_REQUIRED',
      );
    }
    await _run(() async {
      try {
        final person = await apiService.goOnline(
          deliveryPerson!.id,
          token: authToken,
        );
        deliveryPerson = deliveryPerson!.copyWith(
          name: person.name,
          phone: person.phone,
          vehicleNumber: person.vehicleNumber,
          licenseNumber: person.licenseNumber,
          status: person.status,
          isOnline: true,
          active: person.active,
          completedOrders: person.completedOrders,
          todayEarnings: person.todayEarnings,
          avatarUrl: person.avatarUrl,
          licenseCardUrl: person.licenseCardUrl,
          initialPaymentStatus: initialPaymentStatus,
          isPaymentRequired: isInitialPaymentRequired,
          initialPaymentAmount: initialPaymentAmount,
          initialPaymentCompletedAt: initialPaymentCompletedAt,
          initialPaymentMethod: initialPaymentMethod,
          initialPaymentReference: initialPaymentReference,
          initialPaymentSource: initialPaymentSource,
        );
        online = true;
        _connectRealtimeChannel();
        if (authToken != null && authToken!.isNotEmpty) {
          unawaited(
            _messagingService
                .registerTokenSync(authToken: authToken!)
                .catchError((e) {
                  debugPrint('FCM token registration skipped: $e');
                }),
          );
        }
        await loadDashboard();
        _startRequestRefresh();
        _startAvailabilityLocationUpdates();
      } on ApiException catch (e) {
        if (e.code == 'INITIAL_PAYMENT_REQUIRED' || e.statusCode == 403) {
          initialPaymentStatus = 'NOT_PAID';
          online = false;
          deliveryPerson = deliveryPerson?.copyWith(
            isOnline: false,
            initialPaymentStatus: 'NOT_PAID',
            isPaymentRequired: true,
          );
        }
        rethrow;
      }
    });
  }

  Future<void> goOffline() async {
    if (deliveryPerson == null) return;
    await _run(() async {
      await apiService.goOffline(deliveryPerson!.id, token: authToken);
      socketService.emitDeliveryOffline(deliveryPersonId: deliveryPerson!.id);
      socketService.disconnect();
      pendingRequests.clear();
      _stopRequestRefresh();
      _stopLiveLocationTracking();
      _stopAvailabilityLocationUpdates();
      online = false;
      deliveryPerson = deliveryPerson!.copyWith(isOnline: false);
    });
  }

  Future<String?> acceptOrder(DeliveryOrderModel order) async {
    if (deliveryPerson == null) return 'Login required';
    try {
      final accepted = await apiService.acceptOrder(
        orderId: order.id,
        deliveryPersonId: deliveryPerson!.id,
        token: authToken,
      );
      activeOrder = _forceAccepted(accepted);
      socketService.emitAcceptOrder(
        orderId: order.id,
        deliveryPersonId: deliveryPerson!.id,
      );
      pendingRequests.removeWhere((item) => item.id == order.id);
      await loadDashboard();
      activeOrder = _forceAccepted(activeOrder ?? accepted);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      if (e.code == 'INITIAL_PAYMENT_REQUIRED' || e.statusCode == 403) {
        initialPaymentStatus = 'NOT_PAID';
        online = false;
        notifyListeners();
        return 'Initial payment is required before accepting orders.';
      }
      if (e.statusCode == 409) {
        return 'Order already accepted by another delivery person.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  void removePendingOrder(String orderId) {
    pendingRequests.removeWhere((item) => item.id == orderId);
    notifyListeners();
  }

  Future<String?> rejectOrder(DeliveryOrderModel order) async {
    if (deliveryPerson == null) return 'Login required';
    try {
      await apiService.rejectOrder(
        orderId: order.id,
        deliveryPersonId: deliveryPerson!.id,
        token: authToken,
      );
      pendingRequests.removeWhere((item) => item.id == order.id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markPickedUp() async {
    if (deliveryPerson == null || activeOrder == null) return 'No active order';
    try {
      activeOrder = await apiService.markPickedUp(
        orderId: activeOrder!.id,
        deliveryPersonId: deliveryPerson!.id,
        token: authToken,
      );
      await loadDashboard();
      _syncLiveLocationTracking();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markOutForDelivery() async {
    if (deliveryPerson == null || activeOrder == null) return 'No active order';
    try {
      activeOrder = await apiService.markOutForDelivery(
        orderId: activeOrder!.id,
        deliveryPersonId: deliveryPerson!.id,
        token: authToken,
      );
      await loadDashboard();
      _syncLiveLocationTracking();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markDelivered(String otp) async {
    if (deliveryPerson == null || activeOrder == null) return 'No active order';
    try {
      activeOrder = await apiService.markDelivered(
        orderId: activeOrder!.id,
        deliveryPersonId: deliveryPerson!.id,
        otp: otp.trim(),
        token: authToken,
      );
      _stopLiveLocationTracking();
      await loadDashboard();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    try {
      await goOffline();
    } catch (e) {
      debugPrint('Delivery goOffline skipped during logout: $e');
    }

    try {
      final currentToken = await _messagingService.getToken();
      if (authToken != null &&
          currentToken != null &&
          currentToken.isNotEmpty) {
        await _messagingService.removeToken(
          token: currentToken,
          authToken: authToken!,
        );
      }
    } catch (e) {
      debugPrint('Delivery FCM token removal skipped during logout: $e');
    }

    deliveryPerson = null;
    activeOrder = null;
    history.clear();
    pendingRequests.clear();
    earningsStats = const {};
    authToken = null;
    authUser = null;
    online = false;
    initialPaymentLoading = false;
    initialPaymentVerifying = false;
    initialPaymentError = null;
    initialPaymentAmount = 500.0;
    initialPaymentStatus = 'NOT_PAID';
    initialPaymentCompletedAt = null;
    initialPaymentMethod = null;
    initialPaymentReference = null;
    initialPaymentSource = null;
    _stopRequestRefresh();
    _stopLiveLocationTracking();
    _stopAvailabilityLocationUpdates();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deliveryTokenKey);
      await prefs.remove(_deliveryUserKey);
    } catch (e) {
      debugPrint('Delivery shared prefs cleanup skipped during logout: $e');
    }

    try {
      await SessionService().clearSession();
    } catch (e) {
      debugPrint('Delivery session clear skipped during logout: $e');
    }

    notifyListeners();
  }

  void _handleNewOrderRequest(dynamic data) {
    final map = _normalize(data);
    if (map == null) return;
    if (_isMyOrder(map)) return;
    final order = DeliveryOrderModel.fromJson(map);
    if (order.status != DeliveryOrderStatus.waitingForAccept) return;
    if (pendingRequests.every((item) => item.id != order.id)) {
      pendingRequests.insert(0, order);
      notifyListeners();
    }
  }

  void _startRequestRefresh() {
    _requestRefreshTimer?.cancel();
    _requestRefreshTimer = Timer.periodic(const Duration(seconds: 8), (
      _,
    ) async {
      if (!online || deliveryPerson == null || isInitialPaymentRequired) return;
      try {
        final available = await apiService.fetchAvailableOrders(
          deliveryPersonId: deliveryPerson!.id,
          token: authToken,
        );
        final availableIds = available.map((item) => item.id).toSet();
        var changed = false;
        pendingRequests.removeWhere((item) {
          final shouldRemove = !availableIds.contains(item.id);
          if (shouldRemove) changed = true;
          return shouldRemove;
        });
        for (final order in available.reversed) {
          if (pendingRequests.every((item) => item.id != order.id)) {
            pendingRequests.insert(0, order);
            changed = true;
          }
        }
        if (changed) notifyListeners();
      } on ApiException catch (e) {
        if (e.code == 'INITIAL_PAYMENT_REQUIRED' || e.statusCode == 403) {
          initialPaymentStatus = 'NOT_PAID';
          pendingRequests.clear();
          online = false;
          notifyListeners();
        }
      } catch (_) {
        // Keep the live socket flow as the primary source; polling is only a fallback.
      }
    });
  }

  void _stopRequestRefresh() {
    _requestRefreshTimer?.cancel();
    _requestRefreshTimer = null;
  }

  void _startAvailabilityLocationUpdates() {
    _availabilityLocationTimer?.cancel();
    unawaited(_publishAvailabilityLocation());
    _availabilityLocationTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      unawaited(_publishAvailabilityLocation());
    });
  }

  void _stopAvailabilityLocationUpdates() {
    _availabilityLocationTimer?.cancel();
    _availabilityLocationTimer = null;
  }

  Future<void> _publishAvailabilityLocation() async {
    if (!online || authToken == null) return;
    try {
      final location = await locationService.currentLocation();
      await apiService.updateLiveLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        token: authToken,
      );
    } catch (e) {
      debugPrint('Delivery availability location update skipped: $e');
    }
  }

  bool get _hasTrackableActiveOrder =>
      activeOrder?.status == DeliveryOrderStatus.accepted ||
      activeOrder?.status == DeliveryOrderStatus.packed ||
      activeOrder?.status == DeliveryOrderStatus.pickedUp ||
      activeOrder?.status == DeliveryOrderStatus.outForDelivery;

  void _syncLiveLocationTracking() {
    if (!_hasTrackableActiveOrder) {
      _stopLiveLocationTracking();
      return;
    }
    if (_locationPublishTimer != null) return;
    unawaited(_publishLiveLocation());
    _locationPublishTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_publishLiveLocation());
    });
  }

  void _stopLiveLocationTracking() {
    _locationPublishTimer?.cancel();
    _locationPublishTimer = null;
  }

  Future<void> _publishLiveLocation() async {
    final order = activeOrder;
    if (order == null || !_hasTrackableActiveOrder || authToken == null) return;
    try {
      final location = await locationService.currentLocation();
      await apiService.updateLiveLocation(
        orderId: order.id,
        latitude: location.latitude,
        longitude: location.longitude,
        token: authToken,
      );
    } catch (e) {
      debugPrint('Live delivery location update skipped: $e');
    }
  }

  void _connectRealtimeChannel() {
    if (deliveryPerson == null) return;
    socketService.connect(
      deliveryPersonId: deliveryPerson!.id,
      deliveryPersonName: deliveryPerson!.name,
      onNewOrderRequest: _handleNewOrderRequest,
      onOrderTaken: _handleOrderTaken,
      onOrderAssigned: _handleOrderAssigned,
      onOrderPacked: _handleOrderPacked,
      onOrderPickedUp: _handleOrderPickedUp,
      onOrderOutForDelivery: _handleOrderOutForDelivery,
      onOrderDelivered: _handleOrderDelivered,
    );
  }

  void _handleOrderTaken(dynamic data) {
    final map = _normalize(data);
    final orderId = _extractOrderId(data) ?? map?['_id'] as String?;
    if (orderId == null) return;
    removePendingOrder(orderId);
  }

  bool _isMyOrder(Map<String, dynamic> order) {
    final myId = deliveryPerson?.id;
    if (myId == null || myId.isEmpty) return false;
    final assigned = order['assignedDeliveryPerson']?.toString() ?? '';
    if (assigned == myId) return true;
    final deliveryPersonId = order['deliveryPersonId']?.toString() ?? '';
    if (deliveryPersonId == myId) return true;
    final deliveryPersonField = order['deliveryPerson'];
    if (deliveryPersonField is Map<String, dynamic>) {
      final id =
          deliveryPersonField['_id']?.toString() ??
          deliveryPersonField['id']?.toString() ??
          '';
      if (id == myId) return true;
    } else if (deliveryPersonField != null &&
        deliveryPersonField.toString() == myId) {
      return true;
    }
    return false;
  }

  void _handleOrderAssigned(dynamic data) {
    final map = _normalize(data);
    if (map == null) return;
    final rawOrderId = map['_id']?.toString() ?? map['id']?.toString() ?? '';
    if (rawOrderId.isEmpty) return;
    if (!_isMyOrder(map)) return;
    activeOrder = _forceAccepted(DeliveryOrderModel.fromJson(map));
    pendingRequests.removeWhere((item) => item.id == activeOrder!.id);
    history.removeWhere((item) => item.id == activeOrder!.id);
    notifyListeners();
  }

  void _handleOrderPacked(dynamic data) {
    final map = _normalize(data);
    if (map == null) return;
    if (!_isMyOrder(map)) return;
    activeOrder = DeliveryOrderModel.fromJson(map);
    pendingRequests.removeWhere((item) => item.id == activeOrder!.id);
    history.removeWhere((item) => item.id == activeOrder!.id);
    notifyListeners();
  }

  void _handleOrderPickedUp(dynamic data) {
    final map = _normalize(data);
    if (map == null) return;
    if (!_isMyOrder(map)) return;
    activeOrder = DeliveryOrderModel.fromJson(map);
    _syncLiveLocationTracking();
    notifyListeners();
  }

  void _handleOrderOutForDelivery(dynamic data) {
    final map = _normalize(data);
    if (map == null) return;
    if (!_isMyOrder(map)) return;
    activeOrder = DeliveryOrderModel.fromJson(map);
    pendingRequests.removeWhere((item) => item.id == activeOrder!.id);
    _syncLiveLocationTracking();
    notifyListeners();
  }

  void _handleOrderDelivered(dynamic data) {
    final map = _normalize(data);
    if (map == null) return;
    if (!_isMyOrder(map)) return;
    final deliveredOrder = DeliveryOrderModel.fromJson(map);
    history.insert(0, deliveredOrder);
    if (activeOrder?.id == deliveredOrder.id) {
      activeOrder = null;
      _stopLiveLocationTracking();
    }
    notifyListeners();
  }

  Future<T> _run<T>(FutureOr<T> Function() fn) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await fn();
      return result;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _normalize(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['order'] is Map<String, dynamic>) {
        return data['order'] as Map<String, dynamic>;
      }
      return data;
    }
    return null;
  }

  DeliveryOrderModel _forceAccepted(DeliveryOrderModel order) {
    if (order.status == DeliveryOrderStatus.accepted ||
        order.status == DeliveryOrderStatus.packed ||
        order.status == DeliveryOrderStatus.pickedUp ||
        order.status == DeliveryOrderStatus.outForDelivery ||
        order.status == DeliveryOrderStatus.delivered) {
      return order;
    }
    return DeliveryOrderModel.fromJson({
      '_id': order.id,
      'orderId': order.orderId,
      'customerName': order.customerName,
      'customerPhone': order.customerPhone,
      'customerAddress': order.customerAddress,
      'customerArea': order.customerArea,
      'items': order.items
          .map(
            (item) => {
              'imageUrl': item.imageUrl,
              'name': item.name,
              'quantity': item.quantity,
              'price': item.unitPrice,
            },
          )
          .toList(),
      'totalAmount': order.totalAmount,
      // Keep the server-calculated per-vendor amounts when an incoming
      // waiting request is promoted to an active order. Rebuilding the
      // model without these fields makes the active card show the wrong GST
      // (or silently fall back to zero) for split orders.
      'deliveryFee': order.deliveryFee,
      'gstAmount': order.gstAmount,
      'paymentType': order.paymentType,
      'status': 'ACCEPTED',
      'createdAt': order.createdAt.toIso8601String(),
      'codAmount': order.codAmount,
      'deliveryEarning': order.deliveryEarning,
    });
  }

  String? _extractOrderId(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['orderId'] as String? ??
          data['id'] as String? ??
          (data['order'] is Map<String, dynamic>
              ? (data['order'] as Map<String, dynamic>)['_id'] as String?
              : null);
    }
    return null;
  }

  Future<void> syncInitialPaymentStatus({bool notify = true}) async {
    if (authToken == null) return;
    try {
      final res = await apiService.fetchInitialPaymentStatus(token: authToken);
      final status =
          res['initialPaymentStatus'] as String? ??
          (res['isPaymentRequired'] == false ? 'PAID' : 'NOT_PAID');
      initialPaymentStatus = status;
      if (res['initialPaymentAmount'] != null) {
        initialPaymentAmount = (res['initialPaymentAmount'] as num).toDouble();
      }
      if (res['completedAt'] != null) {
        initialPaymentCompletedAt = DateTime.tryParse(
          res['completedAt'].toString(),
        );
      } else if (res['initialPaymentCompletedAt'] != null) {
        initialPaymentCompletedAt = DateTime.tryParse(
          res['initialPaymentCompletedAt'].toString(),
        );
      }
      initialPaymentMethod =
          res['paymentMethod'] as String? ??
          res['initialPaymentMethod'] as String?;
      initialPaymentReference =
          res['reference'] as String? ??
          res['initialPaymentReference'] as String?;
      initialPaymentSource =
          res['source'] as String? ?? res['initialPaymentSource'] as String?;

      if (deliveryPerson != null) {
        deliveryPerson = deliveryPerson!.copyWith(
          initialPaymentStatus: initialPaymentStatus,
          isPaymentRequired: isInitialPaymentRequired,
          initialPaymentAmount: initialPaymentAmount,
          initialPaymentCompletedAt: initialPaymentCompletedAt,
          initialPaymentMethod: initialPaymentMethod,
          initialPaymentReference: initialPaymentReference,
          initialPaymentSource: initialPaymentSource,
        );
      }
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('syncInitialPaymentStatus skipped: $e');
    }
  }

  Future<Map<String, dynamic>> initiateInitialPayment() async {
    initialPaymentLoading = true;
    initialPaymentError = null;
    notifyListeners();
    try {
      final res = await apiService.initiateInitialPayment(token: authToken);
      if (res['amount'] != null) {
        initialPaymentAmount = (res['amount'] as num).toDouble();
      }
      return res;
    } on ApiException catch (e) {
      initialPaymentError = e.message;
      rethrow;
    } catch (e) {
      initialPaymentError = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      initialPaymentLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyInitialPayment(String orderId) async {
    initialPaymentVerifying = true;
    initialPaymentError = null;
    notifyListeners();
    try {
      final res = await apiService.verifyInitialPayment(
        orderId: orderId,
        token: authToken,
      );
      final verified =
          res['verified'] == true ||
          res['paymentStatus'] == 'PAID' ||
          res['paymentStatus'] == 'SUCCESS' ||
          res['initialPaymentStatus'] == 'PAID';
      if (verified) {
        initialPaymentStatus = 'PAID';
        if (res['amount'] != null) {
          initialPaymentAmount = (res['amount'] as num).toDouble();
        }
        initialPaymentCompletedAt = DateTime.now();
        if (deliveryPerson != null) {
          deliveryPerson = deliveryPerson!.copyWith(
            initialPaymentStatus: 'PAID',
            isPaymentRequired: false,
            initialPaymentAmount: initialPaymentAmount,
            initialPaymentCompletedAt: initialPaymentCompletedAt,
            isOnline: false,
          );
        }
        online = false;
        unawaited(refreshProfile());
      }
      return verified;
    } on ApiException catch (e) {
      initialPaymentError = e.message;
      return false;
    } catch (e) {
      initialPaymentError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      initialPaymentVerifying = false;
      notifyListeners();
    }
  }

  Future<bool> simulateSandboxPayment(String orderId) async {
    initialPaymentVerifying = true;
    initialPaymentError = null;
    notifyListeners();
    try {
      final res = await apiService.simulateSandboxPayment(
        orderId: orderId,
        token: authToken,
      );
      final verified =
          res['verified'] == true ||
          res['paymentStatus'] == 'PAID' ||
          res['initialPaymentStatus'] == 'PAID';
      if (verified) {
        initialPaymentStatus = 'PAID';
        if (res['amount'] != null) {
          initialPaymentAmount = (res['amount'] as num).toDouble();
        }
        initialPaymentCompletedAt = DateTime.now();
        if (deliveryPerson != null) {
          deliveryPerson = deliveryPerson!.copyWith(
            initialPaymentStatus: 'PAID',
            isPaymentRequired: false,
            initialPaymentAmount: initialPaymentAmount,
            initialPaymentCompletedAt: initialPaymentCompletedAt,
            isOnline: false,
          );
        }
        online = false;
        unawaited(refreshProfile());
      }
      return verified;
    } on ApiException catch (e) {
      initialPaymentError = e.message;
      return false;
    } catch (e) {
      initialPaymentError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      initialPaymentVerifying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopRequestRefresh();
    _stopLiveLocationTracking();
    _stopAvailabilityLocationUpdates();
    socketService.disconnect();
    super.dispose();
  }
}
