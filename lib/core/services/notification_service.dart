import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const int _deviceOfflineNotificationId = 3;
  static const AndroidNotificationChannel _borosChannel =
      AndroidNotificationChannel(
        'boros_channel',
        'Peringatan Konsumsi',
        description: 'Notifikasi saat status Boros terdeteksi',
        importance: Importance.max,
      );
  static const AndroidNotificationChannel _waspadaChannel =
      AndroidNotificationChannel(
        'waspada_channel',
        'Peringatan Konsumsi',
        description: 'Notifikasi saat status Waspada terdeteksi',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _deviceOfflineChannel =
      AndroidNotificationChannel(
        'device_offline_channel',
        'Status Perangkat',
        description: 'Notifikasi saat perangkat dalam keadaan offline',
        importance: Importance.max,
      );
  static const AndroidNotificationChannel _remoteAlertChannel =
      AndroidNotificationChannel(
        'remote_alert_channel',
        'Remote Alerts',
        description: 'Notifikasi dari Firebase Cloud Messaging',
        importance: Importance.max,
      );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(_borosChannel);
    await androidPlugin?.createNotificationChannel(_waspadaChannel);
    await androidPlugin?.createNotificationChannel(_deviceOfflineChannel);
    await androidPlugin?.createNotificationChannel(_remoteAlertChannel);

    _initialized = true;
  }

  Future<void> showBorosAlert() async {
    const androidDetails = AndroidNotificationDetails(
      'boros_channel',
      'Peringatan Konsumsi',
      channelDescription: 'Notifikasi saat status Boros terdeteksi',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1,
      'Peringatan Konsumsi Tinggi',
      'Status KNN menunjukkan BOROS. Periksa beban listrik Anda.',
      details,
    );
  }

  Future<void> showWaspadaAlert() async {
    const androidDetails = AndroidNotificationDetails(
      'waspada_channel',
      'Peringatan Konsumsi',
      channelDescription: 'Notifikasi saat status Waspada terdeteksi',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      2,
      'Peringatan Konsumsi',
      'Status KNN menunjukkan WASPADA. Pantau konsumsi listrik Anda.',
      details,
    );
  }

  Future<void> showDeviceOfflineAlert(List<String> deviceNames) async {
    if (deviceNames.isEmpty) {
      return;
    }

    final sortedNames = List<String>.from(deviceNames)..sort();
    final title =
        sortedNames.length == 1
            ? 'Perangkat Offline'
            : '${sortedNames.length} Perangkat Offline';
    final body =
        sortedNames.length == 1
            ? '${sortedNames.first} dalam keadaan offline.'
            : '${sortedNames.join(', ')} dalam keadaan offline.';

    const androidDetails = AndroidNotificationDetails(
      'device_offline_channel',
      'Status Perangkat',
      channelDescription: 'Notifikasi saat perangkat dalam keadaan offline',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(_deviceOfflineNotificationId, title, body, details);
  }

  Future<void> clearDeviceOfflineAlert() async {
    await _plugin.cancel(_deviceOfflineNotificationId);
  }

  Future<void> showRemoteAlert({
    required String title,
    required String body,
    int id = 4,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'remote_alert_channel',
      'Remote Alerts',
      channelDescription: 'Notifikasi dari Firebase Cloud Messaging',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details);
  }
}
