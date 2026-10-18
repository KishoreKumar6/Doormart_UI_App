import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../../core/constants.dart';

class DeliverySocketService {
  socket_io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

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
    disconnect();

    _socket = socket_io.io(
      AppConstants.socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['polling', 'websocket'])
          .enableAutoConnect()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      // Keep delivery login responsive even if the socket reconnects later.
      _socket!.emit('delivery_online', {
        'deliveryPersonId': deliveryPersonId,
        'deliveryPersonName': deliveryPersonName,
      });
      _socket!.emit('join_room', {
        'room': 'available_delivery_persons',
        'deliveryPersonId': deliveryPersonId,
      });
      _socket!.emit('join_room', {'room': 'available_delivery_persons'});
      onDeliveryOnline?.call();
    });

    _socket!.onConnectError((error) {
      // Do not throw; login should still succeed without live socket.
      // ignore: avoid_print
      print('[delivery_socket] connect error: $error');
    });
    _socket!.onError((error) {
      // ignore: avoid_print
      print('[delivery_socket] socket error: $error');
    });
    _socket!.onDisconnect((_) => onDeliveryOffline?.call());
    _socket!.on('new_order_request', onNewOrderRequest);
    _socket!.on('order:new', onNewOrderRequest);
    _socket!.on('order_taken', onOrderTaken);
    _socket!.on('order_assigned', onOrderAssigned);
    _socket!.on('order:packed', onOrderPacked);
    _socket!.on('order_packed', onOrderPacked);
    _socket!.on('order_picked_up', onOrderPickedUp);
    _socket!.on('order_out_for_delivery', onOrderOutForDelivery);
    _socket!.on('order:out_for_delivery', onOrderOutForDelivery);
    _socket!.on('order_delivered', onOrderDelivered);
  }

  void emitAcceptOrder({
    required String orderId,
    required String deliveryPersonId,
  }) {
    _socket?.emit('accept_order', {
      'orderId': orderId,
      'deliveryPersonId': deliveryPersonId,
    });
  }

  void emitDeliveryOffline({required String deliveryPersonId}) {
    _socket?.emit('delivery_offline', {'deliveryPersonId': deliveryPersonId});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
