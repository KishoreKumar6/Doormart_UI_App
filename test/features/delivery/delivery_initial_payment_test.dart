import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doormartdelivery/features/delivery/models/delivery_person_model.dart';
import 'package:doormartdelivery/features/delivery/providers/delivery_provider.dart';
import 'package:doormartdelivery/features/delivery/services/delivery_api_service.dart';
import 'package:doormartdelivery/features/delivery/services/delivery_socket_service.dart';
import 'package:doormartdelivery/services/api_service.dart';

DeliveryPersonModel createTestPartner({
  String id = 'del_test_123',
  String name = 'Test Partner',
  String phone = '9876543210',
  String vehicleNumber = 'TN01AB1234',
  String status = 'active',
  bool isOnline = false,
  bool active = true,
  int completedOrders = 0,
  double todayEarnings = 0.0,
  String initialPaymentStatus = 'NOT_PAID',
  bool? isPaymentRequired,
  double initialPaymentAmount = 500.0,
  DateTime? initialPaymentCompletedAt,
  String? initialPaymentMethod,
  String? initialPaymentReference,
  String? initialPaymentSource,
}) {
  return DeliveryPersonModel(
    id: id,
    name: name,
    phone: phone,
    vehicleNumber: vehicleNumber,
    status: status,
    isOnline: isOnline,
    active: active,
    completedOrders: completedOrders,
    todayEarnings: todayEarnings,
    initialPaymentStatus: initialPaymentStatus,
    isPaymentRequired: isPaymentRequired ?? (initialPaymentStatus != 'PAID'),
    initialPaymentAmount: initialPaymentAmount,
    initialPaymentCompletedAt: initialPaymentCompletedAt,
    initialPaymentMethod: initialPaymentMethod,
    initialPaymentReference: initialPaymentReference,
    initialPaymentSource: initialPaymentSource,
  );
}

class FakeDeliveryApiService extends DeliveryApiService {
  FakeDeliveryApiService({
    this.initiateResponse,
    this.verifyResponse,
    this.statusResponse,
    this.profileResponse,
    this.goOnlinePerson,
    this.goOfflinePerson,
  });

  Map<String, dynamic>? initiateResponse;
  Map<String, dynamic>? verifyResponse;
  Map<String, dynamic>? statusResponse;
  Map<String, dynamic>? profileResponse;
  DeliveryPersonModel? goOnlinePerson;
  DeliveryPersonModel? goOfflinePerson;

  @override
  Future<Map<String, dynamic>> initiateInitialPayment({String? token}) async {
    return initiateResponse ??
        {
          'success': true,
          'paymentSessionId': 'session_mock_123',
          'orderId': 'cf_order_mock_123',
          'amount': 500.0,
          'cfOrderId': 'cf_123',
          'environment': 'TEST',
        };
  }

  @override
  Future<Map<String, dynamic>> verifyInitialPayment({
    required String orderId,
    String? token,
  }) async {
    return verifyResponse ??
        {
          'success': true,
          'verified': true,
          'initialPaymentStatus': 'PAID',
          'amount': 500.0,
          'completedAt': '2026-10-06T12:00:00.000Z',
          'paymentMethod': 'UPI',
          'referenceId': 'ref_mock_123',
        };
  }

  @override
  Future<Map<String, dynamic>> fetchInitialPaymentStatus({
    String? token,
  }) async {
    return statusResponse ??
        {
          'initialPaymentStatus': 'PAID',
          'isPaymentRequired': false,
          'initialPaymentAmount': 500.0,
          'amount': 500.0,
        };
  }

  @override
  Future<Map<String, dynamic>> fetchProfile({String? token}) async {
    return profileResponse ??
        {
          'user': {
            '_id': 'user_123',
            'name': 'Test Partner',
            'phone': '9876543210',
            'role': 'delivery_person',
            'initialPaymentStatus': 'PAID',
          },
          'deliveryPerson': {
            '_id': 'del_123',
            'name': 'Test Partner',
            'phone': '9876543210',
            'isOnline': false,
            'active': true,
            'initialPaymentStatus': 'PAID',
          },
        };
  }

  @override
  Future<DeliveryPersonModel> goOnline(
    String deliveryPersonId, {
    String? token,
  }) async {
    return goOnlinePerson ??
        createTestPartner(
          id: deliveryPersonId,
          name: 'Online Partner',
          status: 'online',
          isOnline: true,
          active: true,
          initialPaymentStatus: 'PAID',
        );
  }

  @override
  Future<DeliveryPersonModel> goOffline(
    String deliveryPersonId, {
    String? token,
  }) async {
    return goOfflinePerson ??
        createTestPartner(
          id: deliveryPersonId,
          name: 'Offline Partner',
          status: 'offline',
          isOnline: false,
          active: true,
          initialPaymentStatus: 'PAID',
        );
  }
}

class FakeDeliverySocketService extends DeliverySocketService {
  @override
  bool get isConnected => false;

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
  }) {}

  @override
  void disconnect() {}

  @override
  void emitDeliveryOffline({required String deliveryPersonId}) {}
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(
      envString:
          'API_BASE_URL=http://localhost:5000/api\nAPI_URL=http://localhost:5000/api',
    );
  });

  group('DeliveryPersonModel - Data & Deserialization', () {
    test('Correctly deserializes PAID status', () {
      final json = {
        '_id': 'del_123',
        'name': 'Test Partner',
        'phone': '9876543210',
        'vehicleNumber': 'TN01AB1234',
        'status': 'active',
        'isOnline': false,
        'active': true,
        'initialPaymentStatus': 'PAID',
        'initialPaymentAmount': 500,
        'initialPaymentCompletedAt': '2026-10-06T10:00:00.000Z',
        'initialPaymentMethod': 'UPI',
        'initialPaymentReference': 'cf_order_999',
      };

      final model = DeliveryPersonModel.fromJson(json);

      expect(model.initialPaymentStatus, 'PAID');
      expect(model.isInitialPaymentPaid, isTrue);
      expect(model.isInitialPaymentPending, isFalse);
      expect(model.initialPaymentAmount, 500.0);
      expect(model.initialPaymentMethod, 'UPI');
      expect(model.initialPaymentReference, 'cf_order_999');
      expect(model.initialPaymentCompletedAt, isNotNull);
    });

    test('Correctly deserializes NOT_PAID status and requires payment', () {
      final json = {
        '_id': 'del_456',
        'name': 'Pending Partner',
        'phone': '9876543211',
        'status': 'active',
        'initialPaymentStatus': 'NOT_PAID',
        'initialPaymentAmount': 500,
      };

      final model = DeliveryPersonModel.fromJson(json);

      expect(model.initialPaymentStatus, 'NOT_PAID');
      expect(model.isInitialPaymentPaid, isFalse);
      expect(model.isInitialPaymentPending, isTrue);
      expect(model.isPaymentRequired, isTrue);
    });

    test('copyWith updates and preserves initial payment properties', () {
      final initial = createTestPartner(
        id: 'del_789',
        name: 'Copy Partner',
        phone: '9876543212',
        vehicleNumber: 'TN02CD5678',
        completedOrders: 5,
        todayEarnings: 250,
        initialPaymentStatus: 'NOT_PAID',
        initialPaymentAmount: 500,
      );

      final updated = initial.copyWith(
        initialPaymentStatus: 'PAID',
        initialPaymentCompletedAt: DateTime(2026, 10, 6),
      );

      expect(updated.initialPaymentStatus, 'PAID');
      expect(updated.isInitialPaymentPaid, isTrue);
      expect(updated.initialPaymentAmount, 500.0);
      expect(updated.completedOrders, 5);
      expect(updated.name, 'Copy Partner');
    });
  });

  group('ApiException - Initial Payment Error Code', () {
    test('Contains INITIAL_PAYMENT_REQUIRED error code', () {
      const exception = ApiException(
        'Initial payment is required before accessing delivery features.',
        403,
        code: 'INITIAL_PAYMENT_REQUIRED',
      );

      expect(exception.statusCode, 403);
      expect(exception.code, 'INITIAL_PAYMENT_REQUIRED');
      expect(exception.message, contains('Initial payment is required'));
    });
  });

  group('Complete 12 Business Scenarios - Initial Payment & Work Status', () {
    // ── Scenario 1: Approved + NOT_PAID + INACTIVE ────────────────────────
    test('Scenario 1: Approved + NOT_PAID + INACTIVE', () {
      final provider = DeliveryProvider(
        apiService: FakeDeliveryApiService(),
        socketService: FakeDeliverySocketService(),
      );
      provider.deliveryPerson = createTestPartner(
        id: 'del_001',
        name: 'Approved Unpaid Partner',
        initialPaymentStatus: 'NOT_PAID',
        isOnline: false,
      );
      provider.initialPaymentStatus = 'NOT_PAID';
      provider.online = false;

      expect(provider.isInitialPaymentPaid, isFalse);
      expect(provider.isInitialPaymentRequired, isTrue);
      expect(provider.online, isFalse, reason: 'Work Status must be INACTIVE');
    });

    // ── Scenario 2: Approved + PAID + INACTIVE ────────────────────────────
    test('Scenario 2: Approved + PAID + INACTIVE', () {
      final provider = DeliveryProvider(
        apiService: FakeDeliveryApiService(),
        socketService: FakeDeliverySocketService(),
      );
      provider.deliveryPerson = createTestPartner(
        id: 'del_002',
        name: 'Approved Paid Inactive Partner',
        initialPaymentStatus: 'PAID',
        isOnline: false,
      );
      provider.initialPaymentStatus = 'PAID';
      provider.online = false;

      expect(provider.isInitialPaymentPaid, isTrue);
      expect(provider.isInitialPaymentRequired, isFalse);
      expect(
        provider.online,
        isFalse,
        reason: 'Partner has not toggled Active yet',
      );
    });

    // ── Scenario 3: Approved + PAID + ACTIVE ──────────────────────────────
    test('Scenario 3: Approved + PAID + ACTIVE', () {
      final provider = DeliveryProvider(
        apiService: FakeDeliveryApiService(),
        socketService: FakeDeliverySocketService(),
      );
      provider.deliveryPerson = createTestPartner(
        id: 'del_003',
        name: 'Approved Paid Active Partner',
        initialPaymentStatus: 'PAID',
        isOnline: true,
      );
      provider.initialPaymentStatus = 'PAID';
      provider.online = true;

      expect(provider.isInitialPaymentPaid, isTrue);
      expect(provider.isInitialPaymentRequired, isFalse);
      expect(provider.online, isTrue, reason: 'Partner is currently working');
    });

    // ── Scenario 4: Attempt to become Active while NOT_PAID ────────────────
    test(
      'Scenario 4: Attempt to become Active while NOT_PAID blocks with 403',
      () async {
        final provider = DeliveryProvider(
          apiService: FakeDeliveryApiService(),
          socketService: FakeDeliverySocketService(),
        );
        provider.deliveryPerson = createTestPartner(
          id: 'del_004',
          name: 'Unpaid Attempting Partner',
          initialPaymentStatus: 'NOT_PAID',
          isOnline: false,
        );
        provider.initialPaymentStatus = 'NOT_PAID';
        provider.online = false;

        expect(
          () => provider.goOnline(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'INITIAL_PAYMENT_REQUIRED')
                .having((e) => e.statusCode, 'statusCode', 403),
          ),
        );
        expect(
          provider.online,
          isFalse,
          reason: 'Work Status must remain INACTIVE',
        );
      },
    );

    // ── Scenario 5: Payment initiation ────────────────────────────────────
    test('Scenario 5: Payment initiation returns session and order', () async {
      final fakeApi = FakeDeliveryApiService(
        initiateResponse: {
          'success': true,
          'paymentSessionId': 'session_test_555',
          'orderId': 'cf_order_555',
          'amount': 500.0,
          'cfOrderId': 'cf_555',
          'environment': 'TEST',
        },
      );
      final provider = DeliveryProvider(
        apiService: fakeApi,
        socketService: FakeDeliverySocketService(),
      );
      provider.authToken = 'mock_jwt_token';

      final res = await provider.initiateInitialPayment();

      expect(res['success'], isTrue);
      expect(res['paymentSessionId'], 'session_test_555');
      expect(res['orderId'], 'cf_order_555');
      expect(provider.initialPaymentAmount, 500.0);
    });

    // ── Scenario 6: Cashfree payment params ───────────────────────────────
    test(
      'Scenario 6: Cashfree payment params are verified and complete',
      () async {
        final fakeApi = FakeDeliveryApiService(
          initiateResponse: {
            'success': true,
            'paymentSessionId': 'cf_session_token_xyz',
            'orderId': 'doormart_order_xyz',
            'amount': 500.0,
            'environment': 'TEST',
          },
        );
        final provider = DeliveryProvider(
          apiService: fakeApi,
          socketService: FakeDeliverySocketService(),
        );
        provider.authToken = 'mock_jwt_token';

        final res = await provider.initiateInitialPayment();

        expect(res.containsKey('paymentSessionId'), isTrue);
        expect(res['paymentSessionId'], isNotEmpty);
        expect(res.containsKey('orderId'), isTrue);
        expect(res['orderId'], isNotEmpty);
        expect(res['amount'], 500.0);
        expect(res['environment'], 'TEST');
      },
    );

    // ── Scenario 7: Payment verification ──────────────────────────────────
    test('Scenario 7: Payment verification succeeds and marks PAID', () async {
      final fakeApi = FakeDeliveryApiService(
        verifyResponse: {
          'success': true,
          'verified': true,
          'initialPaymentStatus': 'PAID',
          'amount': 500.0,
          'completedAt': '2026-10-06T12:00:00.000Z',
          'paymentMethod': 'UPI',
        },
      );
      final provider = DeliveryProvider(
        apiService: fakeApi,
        socketService: FakeDeliverySocketService(),
      );
      provider.authToken = 'mock_jwt_token';
      provider.initialPaymentStatus = 'NOT_PAID';

      final verified = await provider.verifyInitialPayment('cf_order_555');

      expect(verified, isTrue);
      expect(provider.initialPaymentStatus, 'PAID');
      expect(provider.isInitialPaymentPaid, isTrue);
      expect(provider.isInitialPaymentRequired, isFalse);
    });

    // ── Scenario 8: Status remains INACTIVE after verification ─────────────
    test(
      'Scenario 8: Work status remains INACTIVE immediately after verification',
      () async {
        final fakeApi = FakeDeliveryApiService(
          verifyResponse: {
            'success': true,
            'verified': true,
            'initialPaymentStatus': 'PAID',
            'amount': 500.0,
          },
        );
        final provider = DeliveryProvider(
          apiService: fakeApi,
          socketService: FakeDeliverySocketService(),
        );
        provider.authToken = 'mock_jwt_token';
        provider.deliveryPerson = createTestPartner(
          id: 'del_008',
          name: 'Freshly Verified Partner',
          initialPaymentStatus: 'NOT_PAID',
          isOnline: false,
        );
        provider.online = false;

        final verified = await provider.verifyInitialPayment('order_888');

        expect(verified, isTrue);
        expect(provider.isInitialPaymentPaid, isTrue);
        // Crucial: Partner must remain Inactive until they choose to go online
        expect(
          provider.online,
          isFalse,
          reason: 'Partner must not automatically be forced online',
        );
        expect(provider.deliveryPerson?.isOnline, isFalse);
      },
    );

    // ── Scenario 9: Status refresh ────────────────────────────────────────
    test(
      'Scenario 9: Status refresh syncs initial payment status from server',
      () async {
        final fakeApi = FakeDeliveryApiService(
          statusResponse: {
            'initialPaymentStatus': 'PAID',
            'isPaymentRequired': false,
            'initialPaymentAmount': 500.0,
            'completedAt': '2026-10-06T10:00:00.000Z',
            'paymentMethod': 'CARD',
            'reference': 'cf_ref_999',
          },
        );
        final provider = DeliveryProvider(
          apiService: fakeApi,
          socketService: FakeDeliverySocketService(),
        );
        provider.authToken = 'mock_jwt_token';
        provider.initialPaymentStatus = 'NOT_PAID';

        await provider.syncInitialPaymentStatus();

        expect(provider.initialPaymentStatus, 'PAID');
        expect(provider.isInitialPaymentPaid, isTrue);
        expect(provider.initialPaymentMethod, 'CARD');
        expect(provider.initialPaymentReference, 'cf_ref_999');
      },
    );

    // ── Scenario 10: Becoming Active after payment ────────────────────────
    test(
      'Scenario 10: Partner becomes Active when toggling online after payment',
      () async {
        final fakeApi = FakeDeliveryApiService(
          goOnlinePerson: createTestPartner(
            id: 'del_010',
            name: 'Ready Partner',
            status: 'online',
            isOnline: true,
            active: true,
            initialPaymentStatus: 'PAID',
          ),
        );
        final provider = DeliveryProvider(
          apiService: fakeApi,
          socketService: FakeDeliverySocketService(),
        );
        provider.authToken = 'mock_jwt_token';
        provider.deliveryPerson = createTestPartner(
          id: 'del_010',
          name: 'Ready Partner',
          status: 'active',
          isOnline: false,
          active: true,
          initialPaymentStatus: 'PAID',
        );
        provider.initialPaymentStatus = 'PAID';
        provider.online = false;

        await provider.goOnline();

        expect(provider.online, isTrue, reason: 'Work Status is now ACTIVE');
        expect(provider.deliveryPerson?.isOnline, isTrue);
        expect(provider.isInitialPaymentPaid, isTrue);
      },
    );

    // ── Scenario 11: Becoming Inactive after work finishes ────────────────
    test(
      'Scenario 11: Becoming Inactive after work finishes preserves PAID status',
      () async {
        final fakeApi = FakeDeliveryApiService(
          goOfflinePerson: createTestPartner(
            id: 'del_011',
            name: 'Finishing Partner',
            status: 'offline',
            isOnline: false,
            active: true,
            initialPaymentStatus: 'PAID',
          ),
        );
        final provider = DeliveryProvider(
          apiService: fakeApi,
          socketService: FakeDeliverySocketService(),
        );
        provider.authToken = 'mock_jwt_token';
        provider.deliveryPerson = createTestPartner(
          id: 'del_011',
          name: 'Finishing Partner',
          status: 'online',
          isOnline: true,
          active: true,
          initialPaymentStatus: 'PAID',
        );
        provider.initialPaymentStatus = 'PAID';
        provider.online = true;

        await provider.goOffline();

        expect(provider.online, isFalse, reason: 'Work Status is now INACTIVE');
        expect(provider.deliveryPerson?.isOnline, isFalse);
        expect(
          provider.isInitialPaymentPaid,
          isTrue,
          reason: 'Must remain PAID',
        );
        expect(provider.initialPaymentStatus, 'PAID');
      },
    );

    // ── Scenario 12: Inactive partner does not lose PAID status ───────────
    test(
      'Scenario 12: Inactive partner does not lose PAID status across operations',
      () async {
        final fakeApi = FakeDeliveryApiService(
          statusResponse: {
            'initialPaymentStatus': 'PAID',
            'isPaymentRequired': false,
            'initialPaymentAmount': 500.0,
          },
        );
        final provider = DeliveryProvider(
          apiService: fakeApi,
          socketService: FakeDeliverySocketService(),
        );
        provider.authToken = 'mock_jwt_token';
        provider.deliveryPerson = createTestPartner(
          id: 'del_012',
          name: 'Persistent Paid Partner',
          status: 'active',
          isOnline: false,
          active: true,
          initialPaymentStatus: 'PAID',
        );
        provider.initialPaymentStatus = 'PAID';
        provider.online = false;

        // Repeated offline or sync checks must preserve PAID
        await provider.syncInitialPaymentStatus();
        expect(provider.isInitialPaymentPaid, isTrue);
        expect(provider.online, isFalse);

        await provider.goOffline();
        expect(provider.isInitialPaymentPaid, isTrue);
        expect(provider.online, isFalse);
        expect(provider.isInitialPaymentRequired, isFalse);
      },
    );
  });
}
