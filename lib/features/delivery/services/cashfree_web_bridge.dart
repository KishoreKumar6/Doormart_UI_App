import 'cashfree_web_stub.dart'
    if (dart.library.js) 'cashfree_web_impl.dart'
    as impl;

Future<Map<String, dynamic>> launchCashfreeWebCheckout({
  required String paymentSessionId,
  required String environment,
}) => impl.launchCashfreeWebCheckout(
  paymentSessionId: paymentSessionId,
  environment: environment,
);
