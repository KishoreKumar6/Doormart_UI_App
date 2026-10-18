import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../firebase_options.dart';
import 'notification_payload.dart';
import 'notification_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService({ApiService? apiService})
    : apiService = apiService ?? ApiService();

  final ApiService apiService;
  bool _initialized = false;
  bool _tokenListenerRegistered = false;

  Future<void> initialize({
    required Future<void> Function(NotificationPayload payload) onTap,
  }) async {
    if (_initialized) return;

    debugPrint('[FCM] initialize started');

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('[FCM] permission request completed');

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await NotificationService.instance.initialize(
      onTap: (payload) => unawaited(onTap(payload)),
    );

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint(
        '[FCM] foreground message received id=${message.messageId} data=${message.data}',
      );
      final payload = _payloadFromMessage(message);
      if (payload != null) {
        await NotificationService.instance.showNotification(
          id: (payload.orderId.isNotEmpty ? payload.orderId : payload.title)
              .hashCode,
          payload: payload,
        );
        return;
      }

      final fallbackTitle = message.notification?.title ?? 'Notification';
      final fallbackBody = message.notification?.body ?? '';
      await NotificationService.instance.showNotification(
        id:
            message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch,
        payload: NotificationPayload(
          orderId: '',
          title: fallbackTitle,
          body: fallbackBody,
          type: message.data['type']?.toString() ?? 'ADMIN_NOTIFICATION',
          entityId: message.data['entityId']?.toString(),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = _payloadFromMessage(message);
      if (payload != null) {
        unawaited(onTap(payload));
      }
    });

    final initialMessage = await messaging.getInitialMessage();
    final initialPayload = initialMessage == null
        ? null
        : _payloadFromMessage(initialMessage);
    if (initialPayload != null) {
      await onTap(initialPayload);
    }

    _initialized = true;
    debugPrint('[FCM] initialize completed');
  }

  Future<String?> getToken() => FirebaseMessaging.instance.getToken();
  Future<String?> getTokenSafe() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      return null;
    }
  }

  Future<void> removeToken({required String token, required String authToken}) {
    return apiService.post(
      '/notifications/remove-token',
      token: authToken,
      body: {'fcmToken': token},
    );
  }

  Future<void> saveToken({required String token, required String authToken}) {
    return apiService.post(
      '/notifications/save-token',
      token: authToken,
      body: {
        'fcmToken': token,
        'deviceType': kIsWeb
            ? 'web'
            : Platform.isAndroid
            ? 'android'
            : Platform.isIOS
            ? 'ios'
            : 'web',
      },
    );
  }

  Future<void> registerTokenSync({required String authToken}) async {
    debugPrint('[FCM] registering device token');
    final token = await getToken();
    debugPrint(
      '[FCM] token available=${token != null && token.isNotEmpty} '
      'suffix=${token == null || token.isEmpty ? '' : token.substring(token.length - 8)}',
    );
    if (token != null && token.isNotEmpty) {
      try {
        await saveToken(token: token, authToken: authToken);
        debugPrint('[FCM] device token saved');
      } catch (error) {
        debugPrint('[FCM] device token save failed: $error');
        rethrow;
      }
    }

    if (_tokenListenerRegistered) return;
    _tokenListenerRegistered = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      unawaited(saveToken(token: newToken, authToken: authToken));
    });
  }

  NotificationPayload? _payloadFromMessage(RemoteMessage message) {
    final data = message.data;
    final orderId = data['orderId']?.toString();
    final title =
        data['title']?.toString() ?? message.notification?.title ?? '';
    final body = data['body']?.toString() ?? message.notification?.body ?? '';
    final type = data['type']?.toString() ?? 'ADMIN_NOTIFICATION';
    final entityId = data['entityId']?.toString();

    if ((orderId == null || orderId.isEmpty) && title.isEmpty && body.isEmpty)
      return null;

    return NotificationPayload(
      orderId: orderId ?? '',
      title: title.isEmpty ? 'Notification' : title,
      body: body,
      type: type,
      entityId: entityId,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
