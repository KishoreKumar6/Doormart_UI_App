import '../../../services/api_service.dart';
import '../models/delivery_order_model.dart';
import '../models/delivery_person_model.dart';

class DeliveryApiService {
  DeliveryApiService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<Map<String, dynamic>> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = <String, dynamic>{'password': password};
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    final response =
        await _apiService.post('/delivery/login', body: body)
            as Map<String, dynamic>;
    final user = response['user'] as Map<String, dynamic>?;
    final deliveryPerson = response['deliveryPerson'] as Map<String, dynamic>?;
    if (user == null) {
      throw StateError('Invalid login response');
    }
    return {
      'user': user,
      'deliveryPerson': deliveryPerson,
      'token': response['token'],
    };
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? avatarUrl,
    String? vehicleNumber,
    String? panNumber,
    String? panCardUrl,
    String? licenseNumber,
    String? licenseCardUrl,
    String? aadhaarNumber,
    String? aadhaarCardUrl,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'password': password,
      'role': 'delivery_person',
    };
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email;
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      body['avatarUrl'] = avatarUrl.trim();
    }
    if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty) {
      body['vehicleNumber'] = vehicleNumber.trim();
    }
    if (panNumber != null && panNumber.trim().isNotEmpty) {
      body['panNumber'] = panNumber.trim();
    }
    if (panCardUrl != null && panCardUrl.trim().isNotEmpty) {
      body['panCardUrl'] = panCardUrl.trim();
    }
    if (licenseNumber != null && licenseNumber.trim().isNotEmpty) {
      body['licenseNumber'] = licenseNumber.trim();
    }
    if (licenseCardUrl != null && licenseCardUrl.trim().isNotEmpty) {
      body['licenseCardUrl'] = licenseCardUrl.trim();
    }
    if (aadhaarNumber != null && aadhaarNumber.trim().isNotEmpty) {
      body['aadhaarNumber'] = aadhaarNumber.trim();
    }
    if (aadhaarCardUrl != null && aadhaarCardUrl.trim().isNotEmpty) {
      body['aadhaarCardUrl'] = aadhaarCardUrl.trim();
    }
    final response =
        await _apiService.post('/auth/register', body: body)
            as Map<String, dynamic>;
    final user = response['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw StateError('Invalid registration response');
    }
    return {
      'user': user,
      'deliveryPerson': response['deliveryPerson'],
      'token': response['token'],
    };
  }

  Future<DeliveryPersonModel> goOnline(
    String deliveryPersonId, {
    String? token,
  }) async {
    final response =
        await _apiService.post(
              '/delivery/go-online',
              body: {'deliveryPersonId': deliveryPersonId},
              token: token,
            )
            as Map<String, dynamic>;
    return DeliveryPersonModel.fromJson(
      (response['deliveryPerson'] as Map<String, dynamic>?) ?? response,
    );
  }

  Future<DeliveryPersonModel> goOffline(
    String deliveryPersonId, {
    String? token,
  }) async {
    final response =
        await _apiService.post(
              '/delivery/go-offline',
              body: {'deliveryPersonId': deliveryPersonId},
              token: token,
            )
            as Map<String, dynamic>;
    return DeliveryPersonModel.fromJson(
      (response['deliveryPerson'] as Map<String, dynamic>?) ?? response,
    );
  }

  Future<Map<String, dynamic>> fetchProfile({String? token}) async {
    final response = await _apiService.get('/delivery/profile', token: token);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchStatus({String? token}) async {
    final response = await _apiService.get('/delivery/status', token: token);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> initiateInitialPayment({String? token}) async {
    final response = await _apiService.post(
      '/delivery/payment/initiate',
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyInitialPayment({
    required String orderId,
    String? token,
  }) async {
    final response = await _apiService.get(
      '/delivery/payment/verify/$orderId',
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> simulateSandboxPayment({
    required String orderId,
    String? token,
  }) async {
    final response = await _apiService.post(
      '/delivery/payment/simulate-sandbox',
      body: {'orderId': orderId},
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchInitialPaymentStatus({
    String? token,
  }) async {
    final response = await _apiService.get(
      '/delivery/payment/status',
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? token,
    String? phone,
    String? vehicleNumber,
  }) async {
    final body = <String, dynamic>{};
    if (phone != null) body['phone'] = phone;
    if (vehicleNumber != null) body['vehicleNumber'] = vehicleNumber;
    final response = await _apiService.put(
      '/delivery/profile',
      token: token,
      body: body,
    );
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchStatusDetails({String? token}) async {
    final response =
        await _apiService.get('/delivery/status-details', token: token)
            as List<dynamic>;
    return response.whereType<Map<String, dynamic>>().toList();
  }

  Future<DeliveryOrderModel?> fetchActiveOrder({
    required String deliveryPersonId,
    String? token,
  }) async {
    final response = await _apiService.get(
      '/delivery/active-order?deliveryPersonId=$deliveryPersonId',
      token: token,
    );
    if (response == null) return null;
    if (response is Map<String, dynamic> &&
        response['order'] is Map<String, dynamic>) {
      return DeliveryOrderModel.fromJson(
        response['order'] as Map<String, dynamic>,
      );
    }
    if (response is Map<String, dynamic>) {
      return DeliveryOrderModel.fromJson(response);
    }
    return null;
  }

  Future<List<DeliveryOrderModel>> fetchHistory({
    required String deliveryPersonId,
    String? token,
  }) async {
    final response =
        await _apiService.get(
              '/delivery/order-history?deliveryPersonId=$deliveryPersonId',
              token: token,
            )
            as List<dynamic>;
    return response
        .whereType<Map<String, dynamic>>()
        .map(DeliveryOrderModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchEarnings({
    required String deliveryPersonId,
    String? token,
  }) async {
    final response = await _apiService.get(
      '/delivery/earnings?deliveryPersonId=$deliveryPersonId',
      token: token,
    );
    return (response as Map<String, dynamic>);
  }

  Future<List<DeliveryOrderModel>> fetchAvailableOrders({
    required String deliveryPersonId,
    String? token,
  }) async {
    final response =
        await _apiService.get(
              '/delivery/orders?deliveryPersonId=$deliveryPersonId',
              token: token,
            )
            as List<dynamic>;
    return response
        .whereType<Map<String, dynamic>>()
        .map(DeliveryOrderModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchOrderById({
    required String orderId,
    String? token,
  }) async {
    final response = await _apiService.get(
      '/delivery/orders/$orderId',
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<DeliveryOrderModel> acceptOrder({
    required String orderId,
    required String deliveryPersonId,
    String? token,
  }) async {
    final response =
        await _apiService.post(
              '/delivery/orders/$orderId/accept',
              body: {'deliveryPersonId': deliveryPersonId},
              token: token,
            )
            as Map<String, dynamic>;
    return DeliveryOrderModel.fromJson(
      (response['order'] as Map<String, dynamic>?) ?? response,
    );
  }

  Future<void> rejectOrder({
    required String orderId,
    required String deliveryPersonId,
    String? token,
  }) async {
    await _apiService.post(
      '/delivery/orders/$orderId/reject',
      body: {'deliveryPersonId': deliveryPersonId},
      token: token,
    );
  }

  Future<DeliveryOrderModel> markPickedUp({
    required String orderId,
    required String deliveryPersonId,
    String? token,
  }) async {
    final response =
        await _apiService.post(
              '/delivery/orders/$orderId/picked-up',
              body: {'deliveryPersonId': deliveryPersonId},
              token: token,
            )
            as Map<String, dynamic>;
    return DeliveryOrderModel.fromJson(
      (response['order'] as Map<String, dynamic>?) ?? response,
    );
  }

  Future<DeliveryOrderModel> markDelivered({
    required String orderId,
    required String deliveryPersonId,
    required String otp,
    String? token,
  }) async {
    final response =
        await _apiService.post(
              '/delivery/orders/$orderId/delivered',
              body: {'deliveryPersonId': deliveryPersonId, 'otp': otp},
              token: token,
            )
            as Map<String, dynamic>;
    return DeliveryOrderModel.fromJson(
      (response['order'] as Map<String, dynamic>?) ?? response,
    );
  }

  Future<void> updateLiveLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    String? address,
    String? token,
  }) async {
    await _apiService.post(
      '/delivery/location',
      token: token,
      body: {
        'orderId': orderId,
        'latitude': latitude,
        'longitude': longitude,
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
      },
    );
  }
}
