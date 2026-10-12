import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import 'notification_payload.dart';
import '../core/constants/app_assets.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String channelId = 'doormart_alerts_v1';
  static const String channelName = 'Doormart Alerts';
  static const String channelDescription =
      'Sound alerts for orders and account notifications';
  static const String soundName = 'new_order';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(NotificationPayload payload)? _onTap;

  Future<void> initialize({
    required void Function(NotificationPayload payload) onTap,
  }) async {
    if (_initialized) {
      _onTap = onTap;
      return;
    }

    _onTap = onTap;

    const androidInit = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.deleteNotificationChannel(
      channelId: 'admin_notifications',
    );
    await androidImplementation?.deleteNotificationChannel(
      channelId: 'delivery_orders_v4',
    );
    await androidImplementation?.deleteNotificationChannel(
      channelId: 'delivery_orders_v2',
    );
    await androidImplementation?.deleteNotificationChannel(
      channelId: 'delivery_orders_v1',
    );
    await androidImplementation?.deleteNotificationChannel(
      channelId: 'delivery_orders_v3',
    );
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'delivery_orders_v5',
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundName),
      ),
    );
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundName),
      ),
    );

    _initialized = true;
  }

  Future<void> showDeliveryRequest({
    required String orderId,
    required String title,
    required String body,
  }) async {
    await showNotification(
      id: orderId.hashCode,
      payload: NotificationPayload(orderId: orderId, title: title, body: body),
    );
  }

  Future<void> showNotification({
    required int id,
    required NotificationPayload payload,
  }) async {
    final largeIcon = await _loadLargeIcon();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      enableVibration: true,
      icon: 'ic_notification',
      largeIcon: largeIcon,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: id,
      title: payload.title,
      body: payload.body,
      notificationDetails: details,
      payload: jsonEncode(payload.toMap()),
    );
  }

  Future<ByteArrayAndroidBitmap?> _loadLargeIcon() async {
    try {
      final data = await rootBundle.load(AppAssets.logo);
      return ByteArrayAndroidBitmap(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<void> handleNotificationTap(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final data = jsonDecode(payload);
    if (data is Map<String, dynamic>) {
      _onTap?.call(NotificationPayload.fromMap(data));
    }
  }

  void _handleResponse(NotificationResponse response) {
    unawaited(handleNotificationTap(response.payload));
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background tap callback required by flutter_local_notifications.
}
