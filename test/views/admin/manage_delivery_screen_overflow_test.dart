import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:doormartdelivery/models/user_model.dart';
import 'package:doormartdelivery/providers/app_state.dart';
import 'package:doormartdelivery/views/admin/manage_delivery_screen.dart';

class FakeAppState extends ChangeNotifier implements AppState {
  FakeAppState({this.partners, this.deliveryDocs});

  List<UserModel>? partners;
  List<Map<String, dynamic>>? deliveryDocs;

  @override
  Future<List<UserModel>> adminUsers() async {
    return partners ??
        [
          UserModel(
            id: '67039281a1b2c3d4e5f6a7b8',
            name: 'Kishore Delivery Partner',
            phone: '9876543210',
            email:
                'verylongdeliverypartneremailaddress@examplecompanydomain.com',
            role: 'delivery_person',
            approvalStatus: 'approved',
            status: 'active',
            avatarUrl: '',
          ),
          UserModel(
            id: '67039281a1b2c3d4e5f6a7b9',
            name: 'Pending Partner',
            phone: '9876543211',
            email: 'pending.partner@example.com',
            role: 'delivery_person',
            approvalStatus: 'pending',
            status: 'active',
            avatarUrl: '',
          ),
        ];
  }

  @override
  Future<List<Map<String, dynamic>>> adminDeliveryPartners() async {
    return deliveryDocs ??
        [
          {
            '_id': 'del_doc_123',
            'user': {'_id': '67039281a1b2c3d4e5f6a7b8', 'status': 'online'},
            'initialPaymentStatus': 'PAID',
            'initialPaymentAmount': 500,
            'initialPaymentReference': 'cf_pay_ref_9876543210987654321',
            'initialPaymentCompletedAt': '2026-10-10T10:30:00.000Z',
          },
          {
            '_id': 'del_doc_124',
            'user': {'_id': '67039281a1b2c3d4e5f6a7b9', 'status': 'offline'},
            'initialPaymentStatus': 'NOT_PAID',
            'initialPaymentAmount': 500,
          },
        ];
  }

  @override
  Future<num> getDeliveryInitialPaymentSetting() async {
    return 500;
  }

  @override
  Future<List<Map<String, dynamic>>> adminDeliveryStatusDetails(
    String id,
  ) async {
    return [];
  }

  @override
  String get logoutRouteName => '/login';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ManageDeliveryScreen - Responsive Screen Layout Tests', () {
    const widths = [320.0, 360.0, 390.0, 412.0, 600.0, 800.0, 1200.0];

    for (final width in widths) {
      testWidgets('Zero RenderFlex overflow on ${width}px screen width', (
        tester,
      ) async {
        final fakeAppState = FakeAppState();

        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppState>.value(
              value: fakeAppState,
              child: const ManageDeliveryScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'RenderFlex overflow occurred on width: ${width}px',
        );

        expect(find.text('Delivery Partners'), findsOneWidget);
        expect(find.text('Kishore Delivery Partner'), findsOneWidget);
        expect(find.text('Pending Partner'), findsOneWidget);
        expect(find.text('Initial Fee Paid'), findsOneWidget);
        expect(find.text('Initial Fee Required'), findsOneWidget);
        expect(find.text('Payment Completed'), findsOneWidget);
        expect(find.text('Mark as Paid'), findsOneWidget);
      });
    }

    testWidgets(
      'Payment Status Dialog (Paid) opens without overflow on 360x800',
      (tester) async {
        final fakeAppState = FakeAppState();

        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppState>.value(
              value: fakeAppState,
              child: const ManageDeliveryScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final paymentBtn = find.text('Payment Completed');
        await tester.scrollUntilVisible(
          paymentBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(paymentBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Initial Payment Details'), findsOneWidget);
        expect(find.text('Reference / ID: '), findsOneWidget);
      },
    );

    testWidgets(
      'Payment Status Dialog (Unpaid) opens without overflow on 360x800',
      (tester) async {
        final fakeAppState = FakeAppState();

        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppState>.value(
              value: fakeAppState,
              child: const ManageDeliveryScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final markPaidBtn = find.text('Mark as Paid');
        await tester.scrollUntilVisible(
          markPaidBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(markPaidBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Mark Initial Payment as Paid'), findsOneWidget);
      },
    );

    testWidgets('Global Fee Setting Dialog opens without overflow on 360x800', (
      tester,
    ) async {
      final fakeAppState = FakeAppState();

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: fakeAppState,
            child: const ManageDeliveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final editBtn = find.widgetWithText(OutlinedButton, 'Edit');
      await tester.scrollUntilVisible(
        editBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Initial Payment Amount'), findsOneWidget);
    });

    testWidgets(
      'Add Partner FAB is clickable and opens dialog without overflow',
      (tester) async {
        final fakeAppState = FakeAppState();

        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppState>.value(
              value: fakeAppState,
              child: const ManageDeliveryScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);

        await tester.tap(fab);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add Delivery Partner'), findsOneWidget);
      },
    );
  });
}
