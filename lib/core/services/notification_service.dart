import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

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
}
