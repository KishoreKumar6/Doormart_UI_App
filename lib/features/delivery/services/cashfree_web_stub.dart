Future<Map<String, dynamic>> launchCashfreeWebCheckout({
  required String paymentSessionId,
  required String environment,
}) async {
  return {
    'success': false,
    'error': 'Web checkout not available on native platform',
  };
}
