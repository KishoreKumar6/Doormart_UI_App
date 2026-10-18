// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:js';

Future<Map<String, dynamic>> launchCashfreeWebCheckout({
  required String paymentSessionId,
  required String environment,
}) async {
  final completer = Completer<Map<String, dynamic>>();

  context['_cashfreeCheckoutCallback'] = (dynamic rawData) {
    try {
      if (rawData != null) {
        if (rawData is Map) {
          final mapped = Map<String, dynamic>.from(rawData);
          if (!completer.isCompleted) completer.complete(mapped);
          return;
        }
        final parsed = jsonDecode(rawData.toString());
        if (parsed is Map) {
          final mapped = Map<String, dynamic>.from(parsed);
          if (!completer.isCompleted) completer.complete(mapped);
          return;
        }
      }
    } catch (_) {}
    if (!completer.isCompleted) completer.complete({'completed': true});
  };

  try {
    context.callMethod('doCashfreeCheckout', [paymentSessionId, environment]);
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete({'error': e.toString()});
    }
  }

  // Safety timeout of 5 minutes while user completes checkout
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => {'timeout': true},
  );
}
