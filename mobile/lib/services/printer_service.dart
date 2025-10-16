import 'dart:async';
import 'package:intl/intl.dart';
import 'package:parking/utils/globals.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'text_to_bitmap_service.dart';
import 'printer_background_service.dart';

class PrinterService {
  static bool isConnected = false;
  static String? connectedMacAddress;
  static String? connectedPrinterName;

  // Stream para notificar cambios de estado
  static final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  static Stream<bool> get connectionStateStream =>
      _connectionStateController.stream;

  // Verificar conexión real con el hardware
  static Future<bool> checkConnection() async {
    try {
      final connected = await PrintBluetoothThermal.connectionStatus;

      // Si el estado cambió, actualizar
      if (connected != isConnected) {
        isConnected = connected;
        _connectionStateController.add(connected);

        // Si se desconectó, limpiar todo
        if (!connected) {
          await PrinterBackgroundService.stopService();
          connectedMacAddress = null;
          connectedPrinterName = null;
        }
      }

      return connected;
    } catch (e) {
      loggerGlobal.e('Error al verificar conexión: $e');
      isConnected = false;
      _connectionStateController.add(false);
      return false;
    }
  }

  // Obtener impresoras disponibles
  static Future<List<BluetoothInfo>> getAvailablePrinters() async {
    try {
      List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;

      return devices.where((device) {
        String name = device.name.toLowerCase();
        return name.contains('print') ||
            name.contains('thermal') ||
            name.contains('pos') ||
            name.contains('woscale') ||
            name.contains('yhk') ||
            name.contains('bluetooth');
      }).toList();
    } catch (e) {
      loggerGlobal.e('Error al obtener impresoras: $e');
      return [];
    }
  }

  // Conectar a impresora
  static Future<bool> connectToPrinter(
    String macAddress, {
    String printerName = 'Impresora Térmica',
  }) async {
    try {
      loggerGlobal.d('Intentando conectar a: $macAddress');

      final connected =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);

      if (connected) {
        isConnected = true;
        connectedMacAddress = macAddress;
        connectedPrinterName = printerName;

        // Emitir evento de conexión
        _connectionStateController.add(true);

        // Iniciar servicio de fondo
        bool serviceStarted =
            await PrinterBackgroundService.startService(printerName);

        if (!serviceStarted) {
          loggerGlobal.w('Servicio de fondo no pudo iniciarse');
        }

        loggerGlobal.d('Conectado exitosamente');
        return true;
      } else {
        loggerGlobal.w('No se pudo conectar a: $macAddress');
        return false;
      }
    } catch (e) {
      loggerGlobal.e('Error al conectar: $e');
      isConnected = false;
      _connectionStateController.add(false);
      connectedMacAddress = null;
      connectedPrinterName = null;
      return false;
    }
  }

  // Desconectar impresora
  static Future<void> disconnect() async {
    try {
      // Detener servicio de fondo primero
      await PrinterBackgroundService.stopService();

      // Luego desconectar Bluetooth
      await PrintBluetoothThermal.disconnect;

      isConnected = false;
      connectedMacAddress = null;
      connectedPrinterName = null;

      // Emitir evento de desconexión
      _connectionStateController.add(false);

      loggerGlobal.d('Impresora desconectada completamente');
    } catch (e) {
      loggerGlobal.e('Error al desconectar: $e');
    }
  }

  // Limpiar al cerrar la app
  static Future<void> dispose() async {
    await _connectionStateController.close();
  }

  // Imprimir ticket de entrada
  static Future<bool> printEntryTicket({
    required String patente,
    required DateTime horaEntrada,
    int? saldoPendiente,
  }) async {
    if (!isConnected) {
      loggerGlobal.w('Impresora no conectada');
      return false;
    }

    try {
      List<int> ticket = [];

      // Ticket con más espacio
      String ticketText = '';
      ticketText += 'TERRAPARKING\n';
      ticketText += '================\n';
      ticketText += 'ENTRADA\n';
      ticketText += '================\n';
      ticketText += 'PATENTE:\n';
      ticketText += '$patente\n';
      ticketText += '\n';
      ticketText += 'HORA:\n';
      ticketText += '${DateFormat('HH:mm dd/MM/yy').format(horaEntrada)}\n';

      if (saldoPendiente != null && saldoPendiente > 0) {
        ticketText += '\n';
        ticketText += 'SALDO PENDIENTE:\n';
        ticketText += '\$$saldoPendiente\n';
      }

      ticketText += '================\n';
      ticketText += '\n'; // Espacio extra
      ticketText += '\n';
      ticketText += '\n';
      ticketText += '\n'; // Más espacio para cortar
      ticketText += '\n';
      ticketText += '\n';

      // Fuente más grande: 18 en lugar de 14
      ticket.addAll(TextToBitmapService.textToRasterCommands(
        ticketText,
        fontSize: 18, // AUMENTADO
        align: TextAlign.center,
      ));

      // Más avance de papel: 8 líneas en lugar de 2
      ticket.addAll([0x1B, 0x64, 0x08]); // AUMENTADO

      bool success = await PrintBluetoothThermal.writeBytes(ticket);
      loggerGlobal.d('Ticket de entrada impreso: $success');
      return success;
    } catch (e) {
      loggerGlobal.e('Error al imprimir ticket de entrada: $e');
      return false;
    }
  }

  // Imprimir ticket de salida
  static Future<bool> printExitTicket({
    required String patente,
    required DateTime horaEntrada,
    required DateTime horaSalida,
    required int tarifa,
    required int totalPagado,
    int saldoAnterior = 0,
    int saldoRestante = 0,
  }) async {
    if (!isConnected) {
      loggerGlobal.w('Impresora no conectada');
      return false;
    }

    try {
      List<int> ticket = [];

      int minutos = horaSalida.difference(horaEntrada).inMinutes;

      // Ticket con más espacio
      String ticketText = '';
      ticketText += 'TERRAPARKING\n';
      ticketText += '================\n';
      ticketText += 'SALIDA\n';
      ticketText += '================\n';
      ticketText += 'PATENTE:\n';
      ticketText += '$patente\n';
      ticketText += '\n';
      ticketText += 'SALIDA:\n';
      ticketText += '${DateFormat('HH:mm dd/MM/yy').format(horaSalida)}\n';
      ticketText += '\n';
      ticketText += 'TIEMPO: $minutos min\n';
      ticketText += '================\n';
      ticketText += 'MONTO PAGADO:\n';
      ticketText += '\$$totalPagado\n';

      if (saldoRestante > 0) {
        ticketText += '\n';
        ticketText += 'SALDO PENDIENTE:\n';
        ticketText += '\$$saldoRestante\n';
      }

      ticketText += '================\n';
      ticketText += 'Gracias\n';
      ticketText += '\n'; // Espacio para cortar
      ticketText += '\n';
      ticketText += '\n';
      ticketText += '\n';
      ticketText += '\n';
      ticketText += '\n';

      // Fuente más grande: 18 en lugar de 14
      ticket.addAll(TextToBitmapService.textToRasterCommands(
        ticketText,
        fontSize: 18, // AUMENTADO
        align: TextAlign.center,
      ));

      // Más avance de papel: 8 líneas en lugar de 2
      ticket.addAll([0x1B, 0x64, 0x08]); // AUMENTADO

      bool success = await PrintBluetoothThermal.writeBytes(ticket);
      loggerGlobal.d('Ticket de salida impreso: $success');
      return success;
    } catch (e) {
      loggerGlobal.e('Error al imprimir ticket de salida: $e');
      return false;
    }
  }

  // Imprimir ticket de prueba
  // Imprimir ticket de prueba - CALIBRADO
  static Future<bool> printTestTicket() async {
    if (!isConnected) {
      loggerGlobal.w('Impresora no conectada');
      return false;
    }

    try {
      List<int> ticket = [];

      String ticketText = '';
      ticketText += 'TERRAPARKING\n';
      ticketText += '================\n';
      ticketText += 'PRUEBA OK\n';
      ticketText += '================\n';
      ticketText += '${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}\n';
      ticketText += '================\n';
      ticketText += '\n'; // Espacio extra
      ticketText += '\n';
      ticketText += '\n';
      ticketText += '\n'; // Más espacio para cortar
      ticketText += '\n';
      ticketText += '\n';

      ticket.addAll(TextToBitmapService.textToRasterCommands(
        ticketText,
        fontSize: 14,
        align: TextAlign.center,
      ));

      // Avanzar más papel para poder cortar (8 líneas)
      ticket.addAll([0x1B, 0x64, 0x08]);

      bool success = await PrintBluetoothThermal.writeBytes(ticket);
      loggerGlobal.d('Ticket de prueba impreso: $success');
      return success;
    } catch (e) {
      loggerGlobal.e('Error al imprimir ticket de prueba: $e');
      return false;
    }
  }
}
