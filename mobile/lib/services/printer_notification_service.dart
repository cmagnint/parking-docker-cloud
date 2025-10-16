import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parking/services/printer_service.dart';
import 'package:parking/utils/globals.dart';

class PrinterNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 1000;
  static bool _isInitialized = false;

  // Inicializar servicio de notificaciones
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  // Mostrar notificación persistente cuando está conectado
  static Future<void> showConnectedNotification(String printerName) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'printer_connection',
      'Conexión de Impresora',
      channelDescription: 'Mantiene la conexión activa con la impresora',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Notificación persistente
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction(
          'disconnect',
          'Desconectar',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      '🖨️ Impresora Conectada',
      '$printerName - Toca para desconectar',
      details,
    );
  }

  // Ocultar notificación cuando se desconecta
  static Future<void> hideNotification() async {
    await _notifications.cancel(_notificationId);
  }

  // Manejar tap en la notificación
  static void _onNotificationTap(NotificationResponse response) async {
    if (response.actionId == 'disconnect' || response.id == _notificationId) {
      await PrinterService.disconnect();
      await hideNotification();
      loggerGlobal.d('Impresora desconectada desde notificación');
    }
  }
}
