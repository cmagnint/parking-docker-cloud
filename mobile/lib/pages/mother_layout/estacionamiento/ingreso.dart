import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/services/printer_background_service.dart';
import 'package:parking/services/printer_service.dart'; // Nueva importación
import 'package:parking/utils/globals.dart';
import 'package:lottie/lottie.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart'; // Nueva importación

class RegistroVehiculoScreen extends StatefulWidget {
  const RegistroVehiculoScreen({super.key});

  @override
  RegistroVehiculoScreenState createState() => RegistroVehiculoScreenState();
}

Logger logger = Logger();

class Vehiculo {
  String patente;
  DateTime horaEntrada;
  DateTime? horaSalida;
  int saldoPendiente;

  Vehiculo(this.patente, this.horaEntrada, {this.saldoPendiente = 0});
}

class RegistroVehiculoScreenState extends State<RegistroVehiculoScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final TextEditingController _patenteController = TextEditingController();
  final TextEditingController _busquedaController = TextEditingController();
  List<Vehiculo> _vehiculos = [];
  List<Vehiculo> _vehiculosFiltrados = [];
  List<dynamic> correos = [];
  List<String> correosSeleccionados = [];
  Map<String, bool> correosCheckbox = {};
  bool _isProcessing = false;
  final bool _isLoading = false;
  late AnimationController _refreshAnimationController;
  bool _isTestingPrinter = false;
  StreamSubscription<bool>? _connectionSubscription;

  // Variables para la impresora
  bool _printerConnected = false;
  List<BluetoothInfo> _availablePrinters = [];

  @override
  void initState() {
    super.initState();

    // Agregar observer del ciclo de vida
    WidgetsBinding.instance.addObserver(this);

    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarRegistrosDelDia();
      pedirCorreos(userInfo.clienteId);
      _checkPrinterConnection(); // Verificar estado inicial
    });

    _busquedaController.addListener(_filtrarVehiculos);

    // Escuchar cambios de conexión del Stream
    _connectionSubscription =
        PrinterService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _printerConnected = connected;
        });

        loggerGlobal
            .d('Estado de conexión actualizado desde Stream: $connected');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remover observer
    _connectionSubscription?.cancel();
    _refreshAnimationController.dispose();
    _busquedaController.removeListener(_filtrarVehiculos);
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      loggerGlobal.d('App volvió del segundo plano, verificando conexión...');
      _checkPrinterConnection();
    } else if (state == AppLifecycleState.paused) {
      loggerGlobal.d('App fue a segundo plano');
    }
  }

  //--------------TESTING----------------------------------------------------------
  Future<void> _testPrinter() async {
    if (!_printerConnected) {
      _mostrarDialogoError('Primero conecta una impresora');
      return;
    }

    setState(() {
      _isTestingPrinter = true;
    });

    try {
      _showLoadingDialog(message: 'Imprimiendo ticket de prueba...');

      // Usar printTestTicket directamente
      bool success = await PrinterService.printTestTicket();

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        if (success) {
          _showTestResultDialog(
              'Ticket impreso correctamente.\nRevisa la impresora.');
        } else {
          _showTestResultDialog('Error al imprimir.\nVerifica la conexión.');
        }
      }
    } catch (e) {
      loggerGlobal.e('Error al probar impresora: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        _mostrarDialogoError('Error al imprimir: $e');
      }
    } finally {
      setState(() {
        _isTestingPrinter = false;
      });
    }
  }

  void _showTestResultDialog(String result) {
    bool isSuccess = result.contains('OK ✓');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Resultado del Test',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2F4858).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (!isSuccess) ...[
                  const Text(
                    'Sugerencias:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F4858),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Verifica que haya papel térmico\n'
                    '• Asegúrate que el papel esté colocado correctamente\n'
                    '• Limpia el cabezal de impresión\n'
                    '• Reinicia la impresora',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2F4858),
                    ),
                  ),
                ],
                if (isSuccess) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '¡La impresora está funcionando correctamente!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2F4858),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isSuccess)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _testPrinter(); // Intentar de nuevo
                },
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Color(0xFF00A085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSuccess ? Colors.green : const Color(0xFF2F4858),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Aceptar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Verificar conexión de impresora
  Future<void> _checkPrinterConnection() async {
    try {
      // Verificar estado real de la conexión
      bool realConnectionStatus = await PrinterService.checkConnection();

      // Verificar si el servicio de fondo está corriendo
      bool serviceRunning = PrinterBackgroundService.isRunning;

      loggerGlobal.d('Estado real de conexión: $realConnectionStatus');
      loggerGlobal.d('Servicio corriendo: $serviceRunning');

      // Si hay discrepancia, sincronizar
      if (realConnectionStatus &&
          !serviceRunning &&
          PrinterService.connectedPrinterName != null) {
        // Reconectar el servicio de fondo si la conexión Bluetooth existe
        await PrinterBackgroundService.startService(
            PrinterService.connectedPrinterName ?? 'Impresora Térmica');
        loggerGlobal.d('Servicio de fondo reiniciado');
      }

      setState(() {
        _printerConnected = realConnectionStatus;
      });

      loggerGlobal.d('Estado de conexión sincronizado: $_printerConnected');
    } catch (e) {
      loggerGlobal.e('Error al verificar conexión: $e');
      setState(() {
        _printerConnected = false;
      });
    }
  }

  // Buscar impresoras disponibles
  Future<void> _searchPrinters() async {
    try {
      _showLoadingDialog(message: 'Buscando impresoras...');
      List<BluetoothInfo> printers =
          await PrinterService.getAvailablePrinters();

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        if (printers.isNotEmpty) {
          setState(() {
            _availablePrinters = printers;
          });
          _showPrinterSelectionDialog();
        } else {
          _mostrarDialogoError(
              'No se encontraron impresoras compatibles. Asegúrate de que la impresora esté encendida y en modo de emparejamiento.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        _mostrarDialogoError('Error al buscar impresoras: $e');
      }
    }
  }

  // Mostrar diálogo de selección de impresora
  void _showPrinterSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.print,
                  color: Color(0xFF00B894),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Seleccionar Impresora',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availablePrinters.length,
              itemBuilder: (context, index) {
                final printer = _availablePrinters[index];
                return ListTile(
                  leading: const Icon(Icons.print, color: Color(0xFF00A085)),
                  title: Text(
                    printer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F4858),
                    ),
                  ),
                  subtitle: Text(
                    printer.macAdress,
                    style: const TextStyle(color: Color(0xFF2F4858)),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _connectToPrinter(printer.macAdress, printer.name);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Color(0xFF2F4858),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Conectar a impresora
  Future<void> _connectToPrinter(String macAddress, String printerName) async {
    try {
      _showLoadingDialog(message: 'Conectando a impresora...');

      bool connected = await PrinterService.connectToPrinter(
        macAddress,
        printerName: printerName,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        if (connected) {
          // El setState se maneja automáticamente por el Stream
          _mostrarDialogoExito('Impresora conectada exitosamente');

          // Verificar que el servicio esté corriendo
          await Future.delayed(const Duration(milliseconds: 500));
          await _checkPrinterConnection();
        } else {
          _mostrarDialogoError('No se pudo conectar a la impresora');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _mostrarDialogoError('Error al conectar: $e');
      }
    }
  }

  // Desconectar impresora
  Future<void> _disconnectPrinter() async {
    try {
      _showLoadingDialog(message: 'Desconectando impresora...');

      await PrinterService.disconnect();

      if (mounted) {
        Navigator.of(context).pop();
        // El setState se maneja automáticamente por el Stream
        _mostrarDialogoExito('Impresora desconectada');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _mostrarDialogoError('Error al desconectar: $e');
      }
    }
  }

  // Widget del indicador de impresora
  Widget _buildPrinterIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _printerConnected
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _printerConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _printerConnected ? Icons.print : Icons.print_disabled,
            color: _printerConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            _printerConnected ? 'Conectada' : 'Desconectada',
            style: TextStyle(
              color: _printerConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Widgets modernos (mantener los existentes)
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2F4858),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: const Color(0xFF2F4858).withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF00A085),
            size: 22,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: const Color(0xFF2F4858).withOpacity(0.2),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF00B894),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool isLoading = false,
    IconData? icon,
    double? fontSize,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Icon(
                icon ?? Icons.check,
                color: textColor,
                size: 20,
              ),
        label: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: fontSize ?? 14,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Vehiculo vehiculo, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFF00B894).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF00A085)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              vehiculo.patente,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF2F4858),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: const Color(0xFF2F4858).withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Entrada: ${DateFormat('HH:mm').format(vehiculo.horaEntrada)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2F4858).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                if (vehiculo.saldoPendiente > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Saldo: \$${vehiculo.saldoPendiente}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: const Color(0xFF00A085),
              size: 20,
            ),
            onTap: () => _mostrarDialogoSalida(vehiculo),
          ),
        ),
      ),
    );
  }

  Future<void> _registrarEntrada() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    var patente = _patenteController.text;
    if (patente.isEmpty) {
      _mostrarDialogoError('¡Debe ingresar una patente!');
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    if (_vehiculos.any((vehiculo) => vehiculo.patente == patente)) {
      _mostrarDialogoError('La patente sigue activa!');
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    var horaEntrada = DateTime.now();

    try {
      var response = await _apiService.post('registro_inicial/', {
        'patente': patente,
        'usuario_registrador': userInfo.rut,
      });
      loggerGlobal.d(response);

      int saldoPendiente = response['saldo_pendiente'] ?? 0;
      var vehiculo =
          Vehiculo(patente, horaEntrada, saldoPendiente: saldoPendiente);

      setState(() {
        _vehiculos.add(vehiculo);
        _filtrarVehiculos();
      });

      // Imprimir ticket de entrada si la impresora está conectada
      if (_printerConnected) {
        try {
          bool printed = await PrinterService.printEntryTicket(
            patente: patente,
            horaEntrada: horaEntrada,
            saldoPendiente: saldoPendiente > 0 ? saldoPendiente : null,
          );

          if (!printed) {
            loggerGlobal.w('No se pudo imprimir el ticket de entrada');
          }
        } catch (e) {
          loggerGlobal.e('Error al imprimir ticket de entrada: $e');
        }
      }

      if (response['tiene_saldo_pendiente']) {
        _mostrarDialogoSaldoPendiente(saldoPendiente);
      } else {
        _mostrarDialogoExito('Vehículo registrado exitosamente');
      }
    } catch (e) {
      loggerGlobal.d('Error detallado: ${e.toString()}');
      String errorMessage = 'Error en la solicitud';
      if (e is Exception) {
        final errorString = e.toString();
        if (errorString.contains('Error:')) {
          try {
            final startIndex = errorString.indexOf('{');
            final endIndex = errorString.lastIndexOf('}') + 1;
            final jsonString = errorString.substring(startIndex, endIndex);
            final errorJson = json.decode(jsonString);
            if (errorJson.containsKey('error')) {
              errorMessage = errorJson['error'];
            }
          } catch (jsonError) {
            loggerGlobal.d('Error al parsear JSON: $jsonError');
            errorMessage = errorString.split('Error: ')[1];
          }
        } else {
          errorMessage = errorString;
        }
      }
      _mostrarDialogoError(errorMessage);
    }

    _patenteController.clear();
    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _registrarSalida(
      Vehiculo vehiculo, int montoPagado, int saldoPendiente) async {
    var horaSalida = DateTime.now();

    try {
      var response = await _apiService.post('registro_final/', {
        'patente': vehiculo.patente,
        'usuario_registrador': userInfo.rut,
        'fecha_termino': horaSalida.toIso8601String(),
        'monto_pagado': montoPagado,
      });

      var data = response;

      setState(() {
        _vehiculos.removeWhere((v) => v.patente == vehiculo.patente);
        _filtrarVehiculos();
      });

      loggerGlobal.d(data);

      // Imprimir ticket de salida si la impresora está conectada
      if (_printerConnected) {
        try {
          bool printed = await PrinterService.printExitTicket(
            patente: vehiculo.patente,
            horaEntrada: vehiculo.horaEntrada,
            horaSalida: horaSalida,
            tarifa: data['tarifa']?.toInt() ?? 0,
            totalPagado: data['total_pagado']?.toInt() ?? 0,
            saldoAnterior: data['saldo_anterior']?.toInt() ?? 0,
            saldoRestante: data['saldo']?.toInt() ?? 0,
          );

          if (!printed) {
            loggerGlobal.w('No se pudo imprimir el ticket de salida');
          }
        } catch (e) {
          loggerGlobal.e('Error al imprimir ticket de salida: $e');
        }
      }

      if (mounted) {
        _mostrarDialogoResultado(context, data['tarifa'], data['total_pagado'],
            data['saldo_anterior']);
      }
    } catch (e) {
      loggerGlobal.e('Error al registrar salida: $e');
      _mostrarDialogoError('Error al registrar la salida: $e');
    }
  }

  // Resto de métodos (mantener todos los existentes)...
  void _mostrarDialogoSaldoPendiente(int saldo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Saldo Pendiente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          content: Text(
            'Este vehículo tiene un saldo pendiente de \$$saldo',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2F4858),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A085),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoExito(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00B894),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Éxito',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2F4858),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B894),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Aceptar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoError(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2F4858),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F4858),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Aceptar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoSalida(Vehiculo vehiculo) async {
    int minutosTranscurridos =
        _calcularMinutosTranscurridos(vehiculo.horaEntrada);
    int tiempoRedondeado =
        ((minutosTranscurridos / userInfo.tiempoParametro).ceil()) *
            userInfo.tiempoParametro;
    int monto = calcularMonto(tiempoRedondeado, minutosTranscurridos);
    int totalAPagar = monto + vehiculo.saldoPendiente;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        TextEditingController abonoController =
            TextEditingController(text: '0');
        bool isAbonoValid = false;
        bool isPagarTotalEnabled = true;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void updateButtonStates() {
              int? abonoValue = int.tryParse(abonoController.text);
              setDialogState(() {
                isAbonoValid = vehiculo.saldoPendiente == 0 &&
                    abonoValue != null &&
                    abonoValue > 0 &&
                    abonoValue < totalAPagar;
                isPagarTotalEnabled = abonoValue == null || abonoValue == 0;
              });
            }

            void limitAbonoInput() {
              int? abonoValue = int.tryParse(abonoController.text);
              if (abonoValue != null && abonoValue >= totalAPagar) {
                abonoController.text = (totalAPagar - 1).toString();
                abonoController.selection = TextSelection.fromPosition(
                  TextPosition(offset: abonoController.text.length),
                );
              }
              updateButtonStates();
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.exit_to_app,
                      color: Color(0xFF00B894),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Despachar vehículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F4858),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F4858).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildInfoRow('PATENTE:', vehiculo.patente),
                      _buildInfoRow('TIEMPO ESTACIONADO:',
                          '$minutosTranscurridos MINUTOS'),
                      _buildInfoRow(
                          'MONTO A PAGAR:', '\$${monto.toStringAsFixed(0)}'),
                      if (vehiculo.saldoPendiente > 0)
                        _buildInfoRow('SALDO PENDIENTE:',
                            '\$${vehiculo.saldoPendiente.toStringAsFixed(0)}',
                            isWarning: true),
                      const Divider(thickness: 2),
                      _buildInfoRow('TOTAL A PAGAR:',
                          '\$${totalAPagar.toStringAsFixed(0)}',
                          isTotal: true),
                      const SizedBox(height: 16),
                      if (vehiculo.saldoPendiente == 0)
                        TextField(
                          controller: abonoController,
                          decoration: InputDecoration(
                            labelText: 'Monto a abonar',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF00B894),
                                width: 2,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            limitAbonoInput();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                if (vehiculo.saldoPendiente == 0)
                  TextButton(
                    onPressed: isAbonoValid
                        ? () {
                            Navigator.of(context).pop();
                            _registrarSalida(
                              vehiculo,
                              int.parse(abonoController.text),
                              vehiculo.saldoPendiente,
                            );
                          }
                        : null,
                    child: Text(
                      'ABONAR',
                      style: TextStyle(
                        color: isAbonoValid
                            ? const Color(0xFF00A085)
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isPagarTotalEnabled
                      ? () {
                          Navigator.of(context).pop();
                          _registrarSalida(
                              vehiculo, totalAPagar, vehiculo.saldoPendiente);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'PAGAR TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(
                      color: Color(0xFF2F4858),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isTotal = false, bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isWarning ? Colors.red : const Color(0xFF2F4858),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w700,
              color: isTotal
                  ? const Color(0xFF00B894)
                  : isWarning
                      ? Colors.red
                      : const Color(0xFF2F4858),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoResultado(
      BuildContext context, var tarifa, var totalPagado, var saldoAnterior) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF00B894),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Registro de Salida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2F4858).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultRow('Tarifa:', '\$${tarifa.toStringAsFixed(0)}'),
                _buildResultRow(
                    'Saldo Anterior:', '\$${saldoAnterior.toStringAsFixed(0)}'),
                const Divider(),
                _buildResultRow(
                    'Total Pagado:', '\$${totalPagado.toStringAsFixed(0)}',
                    isTotal: true),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A085),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Aceptar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF2F4858),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w700,
              color:
                  isTotal ? const Color(0xFF00B894) : const Color(0xFF2F4858),
            ),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares (mantener todos los existentes)
  int _calcularMinutosTranscurridos(DateTime horaEntrada) {
    return DateTime.now().difference(horaEntrada).inMinutes;
  }

  int calcularMonto(int minutosRedondeados, int tiempotranscurrido) {
    int total = (minutosRedondeados / userInfo.tiempoParametro).round() *
        userInfo.valorParametro;
    if (tiempotranscurrido < userInfo.tiempoMinimo) {
      return (userInfo.montoMinimo);
    } else {
      return (total);
    }
  }

  void _filtrarVehiculos() {
    if (_busquedaController.text.isEmpty) {
      _vehiculosFiltrados = List.from(_vehiculos);
    } else {
      _vehiculosFiltrados = _vehiculos
          .where((vehiculo) => vehiculo.patente
              .toLowerCase()
              .contains(_busquedaController.text.toLowerCase()))
          .toList();
    }
  }

  Future<void> _cargarRegistrosDelDia() async {
    _showLoadingDialog();
    try {
      var codigoCliente = userInfo.clienteId;

      var jsonResponse = await _apiService.post('obtener_registros_del_dia/', {
        'codigo_cliente': codigoCliente,
      });

      loggerGlobal.d(jsonResponse);
      List<dynamic> registros = jsonResponse['datos'];
      var parametros = jsonResponse['parametros'];
      loggerGlobal.d(parametros);
      userInfo.tiempoParametro = parametros['intervalo_parametro'];
      userInfo.montoMinimo = parametros['monto_minimo'];
      userInfo.tiempoMinimo = parametros['intervalo_minimo'];
      userInfo.valorParametro = parametros['valor_parametro'];
      loggerGlobal.d(userInfo.tiempoParametro);

      setState(() {
        _vehiculos = registros
            .map((registro) => Vehiculo(
                  registro['patente'],
                  _convertirHoraLocal(DateTime.parse(registro['hora_inicio'])),
                  saldoPendiente: registro['saldo_pendiente'] ?? 0,
                ))
            .toList();
        _filtrarVehiculos();
      });
    } catch (e) {
      loggerGlobal.e('Error al cargar registros del día: $e');
      _mostrarDialogoError('Error al cargar registros: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void pedirCorreos(int codigoJefe) async {
    loggerGlobal.d('funcion llamada');
    try {
      var responseData =
          await _apiService.post('pedir_correos/', {'cliente_id': codigoJefe});

      if (responseData['correos'] != null) {
        correos = responseData['correos'];
        loggerGlobal.d(correos);
      } else {
        loggerGlobal.d(responseData['message']);
      }
    } catch (e) {
      loggerGlobal.e('Exception: $e');
    }
  }

  void _showSucces(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00B894),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '¡Envío CSV exitoso!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B894),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFail(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '¡No se encontraron registros!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F4858),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void mostrarDialogoCorreos() {
    correosSeleccionados.clear();
    correosCheckbox = {for (var correo in correos) correo: false};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.email,
                      color: Color(0xFF00B894),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Selecciona los correos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F4858),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: correos.map((correo) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: correosCheckbox[correo] == true
                              ? const Color(0xFF00B894).withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            correo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2F4858),
                            ),
                          ),
                          value: correosCheckbox[correo],
                          activeColor: const Color(0xFF00B894),
                          onChanged: (bool? valor) {
                            setStateDialog(() {
                              correosCheckbox[correo] = valor ?? false;
                            });
                            if (valor == true) {
                              correosSeleccionados.add(correo);
                            } else {
                              correosSeleccionados.remove(correo);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Color(0xFF2F4858),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _showProgressDialog(context);
                    bool success = await sendData(
                        DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        userInfo.clienteId,
                        correosSeleccionados);
                    loggerGlobal.d(success);
                    if (success) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        _showSucces(context);
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        _showFail(context);
                      }
                    }
                    loggerGlobal.d(correosSeleccionados);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Enviar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> sendData(
      String start, String end, int userId, List<dynamic> email) async {
    try {
      var responseBody = await _apiService.post('enviar_csv/', {
        'formattedStartDate': start,
        'formattedEndDate': end,
        'id_cliente': userInfo.clienteId,
        'email': email,
      });

      if (responseBody['status'] == 'success') {
        return true;
      } else if (responseBody['status'] == 'error') {
        return false;
      }
    } catch (e) {
      loggerGlobal.e('Error al enviar datos: $e');
    }
    return false;
  }

  Future _showProgressDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  const Color(0xFF00B894).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Lottie.asset(
                    'assets/animations/request_code.json',
                    repeat: true,
                    animate: true,
                  ),
                ),
                const SizedBox(width: 20),
                const Text(
                  "ENVIANDO CSV...",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2F4858),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLoadingDialog({String message = 'Cargando Datos...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFF00B894).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Lottie.asset('assets/animations/loading.json'),
              ),
              const SizedBox(width: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F4858),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _convertirHoraLocal(DateTime horaUtc) {
    return horaUtc.toLocal();
  }

  void _refreshData() {
    _refreshAnimationController.reset();
    _refreshAnimationController.forward();
    _cargarRegistrosDelDia();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF00B894).withOpacity(0.1),
              Colors.white,
              const Color(0xFF2F4858).withOpacity(0.05),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header moderno con indicador de impresora
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00B894),
                      Color(0xFF00A085),
                      Color(0xFF2F4858),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Registro de Vehículos',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            RotationTransition(
                              turns: _refreshAnimationController,
                              child: IconButton(
                                onPressed: _isLoading ? null : _refreshData,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _printerConnected
                                  ? _disconnectPrinter
                                  : _searchPrinters,
                              child: _buildPrinterIndicator(),
                            ),
                            const Spacer(),
                            Text(
                              _printerConnected
                                  ? 'Toca para desconectar'
                                  : 'Toca para conectar impresora',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernButton(
                            text: 'Registrar Entrada',
                            onPressed: _isProcessing ? null : _registrarEntrada,
                            backgroundColor: Colors.white,
                            textColor: const Color(0xFF2F4858),
                            isLoading: _isProcessing,
                            icon: Icons.add_circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernButton(
                            text: 'CSV Email',
                            onPressed: mostrarDialogoCorreos,
                            backgroundColor: const Color(0xFF00A085),
                            textColor: Colors.white,
                            icon: Icons.email,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // NUEVO BOTÓN DE PRUEBA
                        Expanded(
                          child: _buildModernButton(
                            text: 'Test Print',
                            onPressed: _isTestingPrinter ? null : _testPrinter,
                            backgroundColor: _printerConnected
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF9E9E9E),
                            textColor: Colors.white,
                            isLoading: _isTestingPrinter,
                            icon: Icons.print,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Campos de entrada
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildModernTextField(
                      controller: _patenteController,
                      label: 'Ingresa Patente',
                      icon: Icons.directions_car,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp("[a-zA-Z0-9]")),
                        UpperCaseTextFormatter(),
                      ],
                    ),
                    _buildModernTextField(
                      controller: _busquedaController,
                      label: 'Buscar Patente',
                      icon: Icons.search,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp("[a-zA-Z0-9]")),
                        UpperCaseTextFormatter(),
                      ],
                    ),
                  ],
                ),
              ),

              // Lista de vehículos
              Expanded(
                child: _vehiculosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_parking,
                              size: 80,
                              color: const Color(0xFF2F4858).withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay vehículos registrados',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2F4858).withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Los vehículos aparecerán aquí cuando se registren',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF2F4858).withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 100,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _vehiculosFiltrados.length,
                        itemBuilder: (context, index) {
                          var vehiculo = _vehiculosFiltrados[index];
                          return _buildVehicleCard(vehiculo, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
