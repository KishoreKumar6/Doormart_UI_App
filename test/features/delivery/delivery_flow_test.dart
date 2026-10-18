import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doormartdelivery/features/delivery/models/delivery_order_model.dart';
import 'package:doormartdelivery/features/delivery/models/delivery_person_model.dart';
import 'package:doormartdelivery/features/delivery/providers/delivery_provider.dart';
import 'package:doormartdelivery/features/delivery/services/delivery_api_service.dart';
import 'package:doormartdelivery/features/delivery/services/delivery_socket_service.dart';
import 'package:doormartdelivery/features/operations/services/location_service.dart';
import 'package:doormartdelivery/notifications/firebase_messaging_service.dart';
import 'package:doormartdelivery/services/api_service.dart';

DeliveryPersonModel testPartner({
  String id = 'del_test_123',
  String status = 'active',
  bool isOnline = false,
  bool active = true,
  String initialPaymentStatus = 'PAID',
}) {
  return DeliveryPersonModel(
    id: id,
    name: 'Test Partner',
    phone: '9876543210',
    vehicleNumber: 'TN01AB1234',
    status: status,
    isOnline: isOnline,
    active: active,
    completedOrders: 0,
    todayEarnings: 0,
    initialPaymentStatus: initialPaymentStatus,
    isPaymentRequired: initialPaymentStatus != 'PAID',
    initialPaymentAmount: 500.0,
  );
}

Map<String, dynamic> orderJson({
  String id = 'order_1',
  String status = 'ACCEPTED',
  String deliveryPersonId = 'del_test_123',
  String? deliveryOtp,
}) {
  return {
    '_id': id,
    'orderId': id,
    'customerName': 'Customer One',
    'customerPhone': '9000000000',
    'customerAddress': '1 Test Street, Chennai',
    'customerArea': 'Chennai',
    'items': [
      {'name': 'Milk', 'quantity': 2, 'price': 30},
    ],
    'totalAmount': 60,
    'paymentType': 'COD',
    'status': status,
    'createdAt': '2026-10-06T10:00:00.000Z',
    'deliveryPersonId': deliveryPersonId,
    'deliveryOtp': ?deliveryOtp,
  };
}

class FakeLocationService extends LocationService {
  int calls = 0;

  @override
  Future<({double latitude, double longitude})> currentLocation() async {
    calls++;
    return (latitude: 12.9716, longitude: 77.5946);
  }
}

class FakeMessagingService extends FirebaseMessagingService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<String?> getTokenSafe() async => null;

  @override
  Future<void> removeToken({
    required String token,
    required String authToken,
  }) async {}

  @override
  Future<void> saveToken({
    required String token,
    required String authToken,
  }) async {}

  @override
  Future<void> registerTokenSync({required String authToken}) async {}
}

class FakeSocketService extends DeliverySocketService {
  bool connected = false;
  int connectCalls = 0;
  int disconnectCalls = 0;
  final List<String> accepted = [];
  final List<String> offlineEmits = [];

  void Function(dynamic)? newOrderRequest;
  void Function(dynamic)? orderTaken;
  void Function(dynamic)? orderAssigned;
  void Function(dynamic)? orderPacked;
  void Function(dynamic)? orderPickedUp;
  void Function(dynamic)? orderOutForDelivery;
  void Function(dynamic)? orderDelivered;

  @override
  bool get isConnected => connected;

  @override
  void connect({
    required String deliveryPersonId,
    required String deliveryPersonName,
    required void Function(dynamic data) onNewOrderRequest,
    required void Function(dynamic data) onOrderTaken,
    required void Function(dynamic data) onOrderAssigned,
    required void Function(dynamic data) onOrderPacked,
    required void Function(dynamic data) onOrderPickedUp,
    required void Function(dynamic data) onOrderOutForDelivery,
    required void Function(dynamic data) onOrderDelivered,
    void Function()? onDeliveryOnline,
    void Function()? onDeliveryOffline,
  }) {
    connectCalls++;
    connected = true;
    newOrderRequest = onNewOrderRequest;
    orderTaken = onOrderTaken;
    orderAssigned = onOrderAssigned;
    orderPacked = onOrderPacked;
    orderPickedUp = onOrderPickedUp;
    orderOutForDelivery = onOrderOutForDelivery;
    orderDelivered = onOrderDelivered;
  }

  @override
  void disconnect() {
    disconnectCalls++;
    connected = false;
  }

  @override
  void emitAcceptOrder({
    required String orderId,
    required String deliveryPersonId,
  }) {
    accepted.add(orderId);
  }

  @override
  void emitDeliveryOffline({required String deliveryPersonId}) {
    offlineEmits.add(deliveryPersonId);
  }
}

class FakeApiService extends DeliveryApiService {
  FakeApiService({
    this.loginResponse,
    this.loginError,
    this.activeOrder,
    this.availableOrders = const [],
    this.goOnlineError,
  });

  Map<String, dynamic>? loginResponse;
  Object? loginError;
  Map<String, dynamic>? activeOrder;
  List<Map<String, dynamic>> availableOrders;
  Object? goOnlineError;

  int availableOrdersCalls = 0;
  int activeOrderCalls = 0;
  int liveLocationCalls = 0;
  int onlineCalls = 0;
  final List<String> acceptedOrderIds = [];
  final List<String> rejectedOrderIds = [];
  final List<String> outForDeliveryCalls = [];

  @override
  Future<Map<String, dynamic>> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResponse!;
  }

  @override
  Future<DeliveryPersonModel> goOnline(
    String deliveryPersonId, {
    String? token,
  }) async {
    onlineCalls++;
    if (goOnlineError != null) throw goOnlineError!;
    return testPartner(id: deliveryPersonId, status: 'online', isOnline: true);
  }

  @override
  Future<DeliveryPersonModel> goOffline(
    String deliveryPersonId, {
    String? token,
  }) async {
    return testPartner(id: deliveryPersonId, status: 'offline');
  }

  @override
  Future<Map<String, dynamic>> fetchStatus({String? token}) async {
    return {
      'deliveryPerson': {
        '_id': 'del_test_123',
        'name': 'Test Partner',
        'phone': '9876543210',
        'isOnline': false,
        'active': true,
        'initialPaymentStatus': 'PAID',
      },
      'isOnline': false,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchInitialPaymentStatus({
    String? token,
  }) async {
    return {
      'initialPaymentStatus': 'PAID',
      'isPaymentRequired': false,
      'initialPaymentAmount': 500.0,
    };
  }

  @override
  Future<List<DeliveryOrderModel>> fetchAvailableOrders({
    required String deliveryPersonId,
    String? token,
  }) async {
    availableOrdersCalls++;
    return availableOrders.map(DeliveryOrderModel.fromJson).toList();
  }

  @override
  Future<DeliveryOrderModel?> fetchActiveOrder({
    required String deliveryPersonId,
    String? token,
  }) async {
    activeOrderCalls++;
    if (activeOrder == null) return null;
    return DeliveryOrderModel.fromJson(activeOrder!);
  }

  @override
  Future<List<DeliveryOrderModel>> fetchHistory({
    required String deliveryPersonId,
    String? token,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> fetchEarnings({
    required String deliveryPersonId,
    String? token,
  }) async {
    return {'total': 0, 'completedOrders': 0};
  }

  @override
  Future<DeliveryOrderModel> acceptOrder({
    required String orderId,
    required String deliveryPersonId,
    String? token,
  }) async {
    acceptedOrderIds.add(orderId);
    return DeliveryOrderModel.fromJson(
      orderJson(id: orderId, status: 'ACCEPTED'),
    );
  }

  @override
  Future<void> rejectOrder({
    required String orderId,
    required String deliveryPersonId,
    String? token,
  }) async {
    rejectedOrderIds.add(orderId);
  }

  @override
  Future<DeliveryOrderModel> markOutForDelivery({
    required String orderId,
    required String deliveryPersonId,
    String? token,
  }) async {
    outForDeliveryCalls.add(orderId);
    return DeliveryOrderModel.fromJson(
      orderJson(id: orderId, status: 'OUT_FOR_DELIVERY'),
    );
  }

  @override
  Future<void> updateLiveLocation({
    String? orderId,
    required double latitude,
    required double longitude,
    String? address,
    String? token,
  }) async {
    liveLocationCalls++;
  }
}

DeliveryProvider buildProvider({
  required FakeApiService api,
  FakeSocketService? socket,
  FakeLocationService? location,
}) {
  return DeliveryProvider(
    apiService: api,
    socketService: socket ?? FakeSocketService(),
    messagingService: FakeMessagingService(),
    locationService: location ?? FakeLocationService(),
  );
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(
      envString:
          'API_BASE_URL=http://localhost:5000/api\nAPI_URL=http://localhost:5000/api',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DeliveryProvider.login', () {
    test(
      'succeeds for an active delivery person and persists the session',
      () async {
        final api = FakeApiService(
          loginResponse: {
            'token': 'token_123',
            'user': {
              '_id': 'del_test_123',
              'name': 'Test Partner',
              'phone': '9876543210',
              'role': 'delivery_person',
              'status': 'active',
              'initialPaymentStatus': 'PAID',
            },
            'deliveryPerson': {
              '_id': 'del_test_123',
              'isOnline': false,
              'active': true,
              'initialPaymentStatus': 'PAID',
            },
          },
        );
        final provider = buildProvider(api: api);

        final ok = await provider.login(
          phone: '9876543210',
          password: 'secret',
        );

        expect(ok, isTrue);
        expect(provider.authToken, 'token_123');
        expect(provider.deliveryPerson?.id, 'del_test_123');
        expect(provider.isInitialPaymentPaid, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('delivery_auth_token'), 'token_123');
        expect(prefs.getString('delivery_auth_user'), isNotNull);
      },
    );

    test('rejects a non delivery-person role', () async {
      final api = FakeApiService(
        loginResponse: {
          'token': 'token_123',
          'user': {
            '_id': 'usr_1',
            'name': 'Shopper',
            'phone': '9876543210',
            'role': 'user',
            'status': 'active',
          },
        },
      );
      final provider = buildProvider(api: api);

      await expectLater(
        provider.login(phone: '9876543210', password: 'secret'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects an inactive delivery person', () async {
      final api = FakeApiService(
        loginResponse: {
          'token': 'token_123',
          'user': {
            '_id': 'del_test_123',
            'name': 'Test Partner',
            'phone': '9876543210',
            'role': 'delivery_person',
            'status': 'inactive',
          },
        },
      );
      final provider = buildProvider(api: api);

      await expectLater(
        provider.login(phone: '9876543210', password: 'secret'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('DeliveryProvider.bootstrap (session restore)', () {
    test('restores the saved token and user from shared preferences', () async {
      SharedPreferences.setMockInitialValues({
        'delivery_auth_token': 'saved_token',
        'delivery_auth_user':
            '{"_id":"del_test_123","name":"Test Partner","phone":"9876543210","role":"delivery_person","status":"active","initialPaymentStatus":"PAID"}',
      });
      final api = FakeApiService();
      final provider = buildProvider(api: api);

      await provider.bootstrap();

      expect(provider.authToken, 'saved_token');
      expect(provider.deliveryPerson?.id, 'del_test_123');
    });
  });

  group('DeliveryProvider.goOnline payment gate', () {
    test('blocks going online when the initial payment is required', () async {
      final api = FakeApiService();
      final provider = buildProvider(api: api);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner(initialPaymentStatus: 'NOT_PAID');

      await expectLater(
        provider.goOnline(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INITIAL_PAYMENT_REQUIRED',
          ),
        ),
      );
      expect(api.onlineCalls, 0);
      expect(provider.online, isFalse);
    });

    test('goes online and connects socket when paid', () async {
      final api = FakeApiService();
      final socket = FakeSocketService();
      final provider = buildProvider(api: api, socket: socket);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner(initialPaymentStatus: 'PAID');
      provider.initialPaymentStatus = 'PAID';

      await provider.goOnline();

      expect(provider.online, isTrue);
      expect(api.onlineCalls, 1);
      expect(socket.connectCalls, 1);
      expect(api.availableOrdersCalls, greaterThanOrEqualTo(1));

      provider.dispose();
    });

    testWidgets('polls available orders every 8s while online', (tester) async {
      final api = FakeApiService();
      final socket = FakeSocketService();
      final provider = buildProvider(api: api, socket: socket);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner(initialPaymentStatus: 'PAID');
      provider.initialPaymentStatus = 'PAID';

      await provider.goOnline();
      final afterOnline = api.availableOrdersCalls;

      await tester.pump(const Duration(seconds: 8));

      expect(api.availableOrdersCalls, greaterThan(afterOnline));
      provider.dispose();
    });
  });

  group('DeliveryProvider.accept / reject', () {
    test(
      'acceptOrder assigns the active order and notifies the socket',
      () async {
        final api = FakeApiService();
        final socket = FakeSocketService();
        final provider = buildProvider(api: api, socket: socket);
        provider.authToken = 't';
        provider.deliveryPerson = testPartner();

        final error = await provider.acceptOrder(
          DeliveryOrderModel.fromJson(orderJson(id: 'order_9')),
        );

        expect(error, isNull);
        expect(api.acceptedOrderIds, contains('order_9'));
        expect(socket.accepted, contains('order_9'));
        expect(provider.activeOrder?.id, 'order_9');
      },
    );

    test('rejectOrder removes the request and calls the API', () async {
      final api = FakeApiService();
      final provider = buildProvider(api: api);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner();
      provider.pendingRequests.add(
        DeliveryOrderModel.fromJson(orderJson(id: 'order_7')),
      );

      final error = await provider.rejectOrder(
        DeliveryOrderModel.fromJson(orderJson(id: 'order_7')),
      );

      expect(error, isNull);
      expect(api.rejectedOrderIds, contains('order_7'));
      expect(provider.pendingRequests, isEmpty);
    });
  });

  group('DeliveryProvider out-for-delivery transition', () {
    test(
      'markOutForDelivery calls the API and updates the active order',
      () async {
        final api = FakeApiService(
          activeOrder: orderJson(id: 'order_5', status: 'OUT_FOR_DELIVERY'),
        );
        final provider = buildProvider(api: api);
        provider.authToken = 't';
        provider.initialPaymentStatus = 'PAID';
        provider.deliveryPerson = testPartner();
        provider.activeOrder = DeliveryOrderModel.fromJson(
          orderJson(id: 'order_5', status: 'PICKED_UP'),
        );

        final error = await provider.markOutForDelivery();

        expect(error, isNull);
        expect(api.outForDeliveryCalls, contains('order_5'));
        expect(
          provider.activeOrder?.status,
          DeliveryOrderStatus.outForDelivery,
        );
        provider.dispose();
      },
    );

    test('socket order:out_for_delivery advances the active order', () async {
      final api = FakeApiService();
      final socket = FakeSocketService();
      final provider = buildProvider(api: api, socket: socket);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner();

      await provider.goOnline();
      socket.orderOutForDelivery!(
        orderJson(id: 'order_5', status: 'OUT_FOR_DELIVERY'),
      );

      expect(provider.activeOrder?.id, 'order_5');
      expect(provider.activeOrder?.status, DeliveryOrderStatus.outForDelivery);
      provider.dispose();
    });
  });

  group('DeliveryProvider live location tracking', () {
    test('publishes live location immediately for a picked-up order', () async {
      final api = FakeApiService(
        activeOrder: orderJson(id: 'order_5', status: 'PICKED_UP'),
      );
      final location = FakeLocationService();
      final provider = buildProvider(api: api, location: location);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner();

      await provider.loadDashboard();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(provider.activeOrder?.status, DeliveryOrderStatus.pickedUp);
      expect(api.liveLocationCalls, 1);

      provider.dispose();
    });

    testWidgets('publishes live location every 15s while an order is active', (
      tester,
    ) async {
      final api = FakeApiService(
        activeOrder: orderJson(id: 'order_5', status: 'PICKED_UP'),
      );
      final location = FakeLocationService();
      final provider = buildProvider(api: api, location: location);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner();

      await provider.goOnline();
      final afterOnline = api.liveLocationCalls;

      await tester.pump(const Duration(seconds: 15));

      expect(api.liveLocationCalls, greaterThan(afterOnline));
      expect(location.calls, greaterThan(afterOnline));
      provider.dispose();
    });

    test('socket order_delivered clears the active order', () async {
      final api = FakeApiService(
        activeOrder: orderJson(id: 'order_5', status: 'PICKED_UP'),
      );
      final socket = FakeSocketService();
      final provider = buildProvider(api: api, socket: socket);
      provider.authToken = 't';
      provider.deliveryPerson = testPartner();

      await provider.goOnline();
      socket.orderDelivered!(orderJson(id: 'order_5', status: 'DELIVERED'));

      expect(provider.activeOrder, isNull);
      expect(provider.history.first.id, 'order_5');

      provider.dispose();
    });
  });
}
