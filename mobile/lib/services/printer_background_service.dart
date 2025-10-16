import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:parking/utils/globals.dart';
import 'printer_service.dart';

class PrinterBackgroundService {
  static bool _isRunning = false;

  // Inicializar servicio de fondo
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'printer_service',
        channelName: 'Servicio de Impresora',
        channelDescription: 'Mantiene la conexión con la impresora térmica',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // Iniciar servicio cuando se conecta la impresora
  static Future<bool> startService(String printerName) async {
    if (_isRunning) {
      loggerGlobal.w('Servicio ya está corriendo');
      return true;
    }

    await initialize();

    // Verificar permisos
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Verificar permisos de notificación (Android 13+)
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();

    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Iniciar servicio
    ServiceRequestResult result = await FlutterForegroundTask.startService(
      serviceId: 1000,
      notificationTitle: '🖨️ Impresora Conectada',
      notificationText: '$printerName - Conexión activa',
      callback: startCallback,
    );

    // Verificar si fue exitoso usando pattern matching
    _isRunning = switch (result) {
      ServiceRequestSuccess() => true,
      ServiceRequestFailure() => false,
    };

    if (_isRunning) {
      loggerGlobal.d('Servicio de fondo iniciado exitosamente');
    } else {
      if (result case ServiceRequestFailure(:final error)) {
        loggerGlobal.e('Error al iniciar servicio: $error');
      }
    }

    return _isRunning;
  }

  // Detener servicio cuando se desconecta
  static Future<bool> stopService() async {
    if (!_isRunning) return true;

    ServiceRequestResult result = await FlutterForegroundTask.stopService();

    // Verificar resultado
    bool stopped = switch (result) {
      ServiceRequestSuccess() => true,
      ServiceRequestFailure() => false,
    };

    if (stopped) {
      _isRunning = false;
      loggerGlobal.d('Servicio de fondo detenido');
    }

    return stopped;
  }

  // Actualizar notificación
  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  static bool get isRunning => _isRunning;
}

// Callback que se ejecuta en segundo plano
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PrinterTaskHandler());
}

// Manejador de tareas en segundo plano
class PrinterTaskHandler extends TaskHandler {
  int _checkCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    loggerGlobal.d('Tarea de impresora iniciada');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    _checkCount++;

    try {
      // Verificar conexión cada 5 segundos
      bool isConnected = await PrinterService.checkConnection();

      if (!isConnected) {
        loggerGlobal.w('Conexión perdida, deteniendo servicio');
        await PrinterService.disconnect();
        await FlutterForegroundTask.stopService();
        return;
      }

      // Actualizar notificación cada minuto (12 ciclos * 5 segundos = 60 segundos)
      if (_checkCount % 12 == 0) {
        final now = DateTime.now();
        await FlutterForegroundTask.updateService(
          notificationText:
              'Conexión activa - ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (e) {
      loggerGlobal.e('Error en verificación de conexión: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool killProcess) async {
    loggerGlobal.d('Tarea de impresora detenida (killProcess: $killProcess)');
  }

  @override
  void onNotificationButtonPressed(String id) {
    loggerGlobal.d('Botón de notificación presionado: $id');
  }

  @override
  void onNotificationPressed() {
    loggerGlobal.d('Notificación presionada');
    FlutterForegroundTask.launchApp('/Ingreso');
  }
}
