import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:doormartdelivery/features/delivery/models/delivery_person_model.dart';
import 'package:doormartdelivery/features/delivery/providers/delivery_provider.dart';
import 'package:doormartdelivery/features/delivery/screens/delivery_initial_payment_screen.dart';
import 'package:doormartdelivery/features/delivery/services/delivery_api_service.dart';
import 'package:doormartdelivery/features/delivery/services/delivery_socket_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class _FakeDeliveryApiService extends DeliveryApiService {}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString:
          'API_BASE_URL=http://localhost:5000/api\nAPI_URL=http://localhost:5000/api',
    );
  });

  group(
    'DeliveryInitialPaymentScreen - UI Responsiveness & Text Alignment on Mobile Screens',
    () {
      testWidgets(
        'Renders PAID view without RenderFlex overflow on 360x640 mobile screen',
        (tester) async {
          final fakeApi = _FakeDeliveryApiService();
          final provider = DeliveryProvider(
            apiService: fakeApi,
            socketService: DeliverySocketService(),
          );

          final paidPartner = DeliveryPersonModel(
            id: 'del_123',
            name: 'Test Partner',
            phone: '9087654321',
            vehicleNumber: 'TN01AB1234',
            status: 'active',
            isOnline: false,
            active: false,
            completedOrders: 0,
            todayEarnings: 0.0,
            initialPaymentStatus: 'PAID',
            isPaymentRequired: false,
            initialPaymentAmount: 500.0,
            initialPaymentCompletedAt: DateTime(2026, 10, 7, 11, 47),
            initialPaymentMethod: 'cashfree',
            initialPaymentReference: 'dp_1791350102102_a5826bbf',
          );

          provider.deliveryPerson = paidPartner;

          // Set mobile phone screen size: 360 x 640 (standard Android phone)
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: ChangeNotifierProvider<DeliveryProvider>.value(
                value: provider,
                child: const DeliveryInitialPaymentScreen(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Verify that no exceptions (such as RenderFlex overflow) were thrown
          expect(tester.takeException(), isNull);

          // Verify key titles and texts
          expect(find.text('Payment Verified & Authorized'), findsOneWidget);
          expect(find.text('Receipt Summary'), findsOneWidget);
          expect(find.text('Fee Amount'), findsOneWidget);
          expect(find.text('₹500'), findsOneWidget);
          expect(find.text('Payment Status'), findsOneWidget);
          expect(find.text('PAID'), findsOneWidget);
          expect(find.text('Cashfree Payments'), findsOneWidget);
          expect(find.text('dp_1791350102102_a5826bbf'), findsOneWidget);
          expect(find.text('Go to Delivery Dashboard'), findsOneWidget);
        },
      );

      testWidgets(
        'Renders PAID view without overflow on narrow 320x568 compact phone screen',
        (tester) async {
          final fakeApi = _FakeDeliveryApiService();
          final provider = DeliveryProvider(
            apiService: fakeApi,
            socketService: DeliverySocketService(),
          );

          final paidPartner = DeliveryPersonModel(
            id: 'del_123',
            name: 'Test Partner',
            phone: '9087654321',
            vehicleNumber: 'TN01AB1234',
            status: 'active',
            isOnline: false,
            active: false,
            completedOrders: 0,
            todayEarnings: 0.0,
            initialPaymentStatus: 'PAID',
            isPaymentRequired: false,
            initialPaymentAmount: 500.0,
            initialPaymentCompletedAt: DateTime(2026, 10, 7, 11, 47),
            initialPaymentMethod: 'cashfree',
            initialPaymentReference:
                'dp_1791350102102_a5826bbf_very_long_reference_id_hash',
          );

          provider.deliveryPerson = paidPartner;

          // Extremely compact phone screen: 320 x 568 (iPhone SE 1st gen)
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: ChangeNotifierProvider<DeliveryProvider>.value(
                value: provider,
                child: const DeliveryInitialPaymentScreen(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Zero overflow errors
          expect(tester.takeException(), isNull);
          expect(find.text('Receipt Summary'), findsOneWidget);
        },
      );

      testWidgets(
        'Renders UNPAID view without overflow on 360x640 phone screen',
        (tester) async {
          final fakeApi = _FakeDeliveryApiService();
          final provider = DeliveryProvider(
            apiService: fakeApi,
            socketService: DeliverySocketService(),
          );

          final unpaidPartner = DeliveryPersonModel(
            id: 'del_123',
            name: 'New Partner',
            phone: '9087654321',
            vehicleNumber: 'TN01AB1234',
            status: 'active',
            isOnline: false,
            active: false,
            completedOrders: 0,
            todayEarnings: 0.0,
            initialPaymentStatus: 'NOT_PAID',
            isPaymentRequired: true,
            initialPaymentAmount: 500.0,
          );

          provider.deliveryPerson = unpaidPartner;

          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: ChangeNotifierProvider<DeliveryProvider>.value(
                value: provider,
                child: const DeliveryInitialPaymentScreen(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('One-Time Activation Fee'), findsOneWidget);
          expect(find.text('Pay ₹500 Now'), findsOneWidget);
        },
      );
    },
  );
}
