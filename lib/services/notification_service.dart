import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../components/app_navigator.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  String? _initialPayload;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    // La práctica está orientada a México. Si el dispositivo usa otra zona, cambia este ID
    // por el de la zona que corresponda (por ejemplo, America/Cancun o America/Tijuana).
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Las solicitudes de permiso se muestran después de montar MaterialApp,
    // desde requestPermissions(), para que no aparezcan antes de la primera pantalla.
    const ios = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _openCalendar(payload);
      },
    );

    // Si Android abre la app desde una notificación con la app cerrada, guardamos el payload
    // y navegamos cuando el primer frame ya tenga un Navigator montado.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload = launchDetails?.notificationResponse?.payload;
    }
  }

  Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> handleInitialPayload() async {
    final payload = _initialPayload;
    _initialPayload = null;
    if (payload != null && payload.isNotEmpty) _openCalendar(payload);
  }

  void _openCalendar(String payload) {
    final date = DateTime.tryParse(payload);
    if (date == null) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _initialPayload = payload;
    } else {
      navigator.pushNamed('/calendar', arguments: date);
    }
  }

  Future<bool> scheduleExpiry({
    required int lotId,
    required String productName,
    required DateTime expirationDate,
  }) async {
    // Construir la fecha directamente en la zona elegida evita corrimientos
    // si el dispositivo está configurado en una zona distinta.
    final scheduled = tz.TZDateTime(
      tz.local, expirationDate.year, expirationDate.month, expirationDate.day, 9,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.cancel(lotId);
      return false;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'alacena_caducidad',
        'Caducidad de productos',
        channelDescription: 'Avisos locales cuando un lote llega a su fecha de caducidad.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      lotId,
      'Producto que caduca hoy',
      '$productName tiene un lote que caduca hoy. Toca para revisar la alacena.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${expirationDate.year.toString().padLeft(4, '0')}-${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.day.toString().padLeft(2, '0')}',
    );
    return true;
  }

  Future<void> cancel(int notificationId) => _plugin.cancel(notificationId);

  /// Útil para comprobar el permiso durante la presentación de la práctica.
  Future<void> showTestNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'alacena_pruebas',
        'Pruebas de alacena',
        channelDescription: 'Notificaciones manuales para probar la configuración.',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _plugin.show(990001, 'Alacena lista', 'Las notificaciones locales están configuradas.', details,
        payload: DateTime.now().toIso8601String().substring(0, 10));
  }
}
