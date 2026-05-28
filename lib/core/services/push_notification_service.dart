import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized in the background isolate.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerCurrentToken();
    _messaging.onTokenRefresh.listen(
      FirebaseService.instance.saveNotificationToken,
    );
    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _initialized = true;
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }
    await FirebaseService.instance.saveNotificationToken(token);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString();
    if (type == 'device_offline') {
      final deviceName = message.data['deviceName']?.toString().trim();
      if (deviceName != null && deviceName.isNotEmpty) {
        await NotificationService.instance.showDeviceOfflineAlert([deviceName]);
        return;
      }
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || title.trim().isEmpty) {
      return;
    }
    if (body == null || body.trim().isEmpty) {
      return;
    }

    await NotificationService.instance.showRemoteAlert(
      title: title,
      body: body,
      id: message.messageId.hashCode,
    );
  }
}
