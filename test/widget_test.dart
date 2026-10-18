import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter environment sanity check', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('DoorMart Delivery Fleet'))),
    );

    expect(find.text('DoorMart Delivery Fleet'), findsOneWidget);
  });
}
