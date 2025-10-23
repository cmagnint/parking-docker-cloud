import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/services/printer_background_service.dart';
import 'package:parking/services/printer_service.dart';
import 'package:parking/utils/globals.dart';
import 'package:lottie/lottie.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

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
  bool _isLoading = false;
  late AnimationController _refreshAnimationController;
  StreamSubscription<bool>? _connectionSubscription;

  bool _printerConnected = false;
  List<BluetoothInfo> _availablePrinters = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarRegistrosDelDia();
      pedirCorreos(userInfo.sociedadId);
      _checkPrinterConnection();
    });

    _busquedaController.addListener(_filtrarVehiculos);

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
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _refreshAnimationController.dispose();
    _busquedaController.removeListener(_filtrarVehiculos);
    _busquedaController.dispose();
    _patenteController.dispose();
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

  Future<void> _checkPrinterConnection() async {
    try {
      bool realConnectionStatus = await PrinterService.checkConnection();
      bool serviceRunning = PrinterBackgroundService.isRunning;

      loggerGlobal.d('Estado real de conexión: $realConnectionStatus');
      loggerGlobal.d('Servicio corriendo: $serviceRunning');

      if (realConnectionStatus &&
          !serviceRunning &&
          PrinterService.connectedPrinterName != null) {
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

  Future<void> _searchPrinters() async {
    try {
      _showLoadingDialog(message: 'Buscando impresoras...');

      // Crear un Future con timeout de 60 segundos
      List<BluetoothInfo> printers =
          await PrinterService.getAvailablePrinters().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          // Si se agota el tiempo, retornar lista vacía
          return <BluetoothInfo>[];
        },
      );

      if (mounted) {
        Navigator.of(context).pop();

        if (printers.isNotEmpty) {
          setState(() {
            _availablePrinters = printers;
          });
          _showPrinterSelectionDialog();
        } else {
          _mostrarDialogoError(
              'No se encontraron impresoras.\n\nAsegúrate de que:\n• La impresora esté encendida\n• Esté en modo de emparejamiento\n• El Bluetooth esté activo\n• La impresora esté cerca del dispositivo');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _mostrarDialogoError('Error al buscar impresoras: $e');
      }
    }
  }

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

  Future<void> _connectToPrinter(String macAddress, String printerName) async {
    try {
      _showLoadingDialog(message: 'Conectando a impresora...');

      bool connected = await PrinterService.connectToPrinter(
        macAddress,
        printerName: printerName,
      );

      if (mounted) {
        Navigator.of(context).pop();

        if (connected) {
          _mostrarDialogoExito('Impresora conectada exitosamente');
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

  Future<void> _disconnectPrinter() async {
    try {
      _showLoadingDialog(message: 'Desconectando impresora...');

      await PrinterService.disconnect();

      if (mounted) {
        Navigator.of(context).pop();
        _mostrarDialogoExito('Impresora desconectada');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _mostrarDialogoError('Error al desconectar: $e');
      }
    }
  }

  Widget _buildPrinterIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _printerConnected
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
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
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            _printerConnected ? 'ON' : 'OFF',
            style: TextStyle(
              color: _printerConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2F4858),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: const Color(0xFF2F4858).withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF00A085),
            size: 20,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: const Color(0xFF2F4858).withOpacity(0.15),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF00B894),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
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
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Icon(
                icon ?? Icons.check,
                color: textColor,
                size: 18,
              ),
        label: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: fontSize ?? 13,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Vehiculo vehiculo, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFF00B894).withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF00A085)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(21),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.white,
                size: 22,
              ),
            ),
            title: Text(
              vehiculo.patente,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF2F4858),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: const Color(0xFF2F4858).withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('HH:mm').format(vehiculo.horaEntrada)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: const Color(0xFF2F4858).withOpacity(0.8),
                      ),
                    ),
                    if (vehiculo.saldoPendiente > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '\$${vehiculo.saldoPendiente}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: const Color(0xFF00A085),
              size: 16,
            ),
            onTap: () => _mostrarDialogoSalida(vehiculo),
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO MODIFICADO: Ahora incluye detección de registro anterior cerrado
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
      logger.d('usuario_registrador ${userInfo.rut}');

      int saldoPendiente = response['saldo_pendiente'] ?? 0;
      bool registroAnteriorCerrado =
          response['registro_anterior_cerrado'] ?? false;
      Map<String, dynamic>? infoRegistroAnterior =
          response['info_registro_anterior'];

      var vehiculo =
          Vehiculo(patente, horaEntrada, saldoPendiente: saldoPendiente);

      setState(() {
        _vehiculos.add(vehiculo);
        _filtrarVehiculos();
      });

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

      // ✅ NUEVO: Lógica mejorada para mostrar mensajes
      if (registroAnteriorCerrado && infoRegistroAnterior != null) {
        // Si se cerró un registro anterior, mostrar el diálogo especial
        _mostrarDialogoRegistroAnteriorCerrado(
          patente: patente,
          fechaInicio: infoRegistroAnterior['fecha_inicio'],
          fechaCierre: infoRegistroAnterior['fecha_cierre'],
          saldoGenerado: infoRegistroAnterior['saldo_generado'],
          saldoTotalPendiente: saldoPendiente,
        );
      } else if (response['tiene_saldo_pendiente']) {
        // Si hay saldo pendiente (pero no se cerró ningún registro), mostrar diálogo simple
        _mostrarDialogoSaldoPendiente(saldoPendiente);
      } else {
        // Si no hay saldo pendiente ni se cerró registro, mostrar éxito
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

  // ✅ NUEVO MÉTODO: Diálogo para registro anterior cerrado automáticamente
  void _mostrarDialogoRegistroAnteriorCerrado({
    required String patente,
    required String fechaInicio,
    required String fechaCierre,
    required int saldoGenerado,
    required int saldoTotalPendiente,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registro Anterior Detectado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patente destacada
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A085).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00A085),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      patente.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A085),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Mensaje principal
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ Este vehículo no fue despachado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDialogInfoRow(
                        icon: Icons.login,
                        label: 'Ingreso anterior:',
                        value: fechaInicio,
                      ),
                      const SizedBox(height: 8),
                      _buildDialogInfoRow(
                        icon: Icons.event,
                        label: 'Cerrado automáticamente:',
                        value: fechaCierre,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Información financiera
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Saldo generado por registro anterior:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '\$${saldoGenerado.toString()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (saldoTotalPendiente > saldoGenerado) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Saldo pendiente de otros registros:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '\$${(saldoTotalPendiente - saldoGenerado).toString()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SALDO TOTAL PENDIENTE:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '\$${saldoTotalPendiente.toString()}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Nota informativa
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El saldo se cobrará al momento de la salida del vehículo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: const Color(0xFF00A085),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ MÉTODO AUXILIAR para el diálogo de registro anterior cerrado
  Widget _buildDialogInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            limitAbonoInput();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(
                            color: Color(0xFF2F4858),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B894),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ABONO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isPagarTotalEnabled
                            ? () {
                                Navigator.of(context).pop();
                                _registrarSalida(
                                  vehiculo,
                                  totalAPagar,
                                  vehiculo.saldoPendiente,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F4858),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isWarning = false, bool isTotal = false}) {
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
              color: isWarning
                  ? Colors.red
                  : isTotal
                      ? const Color(0xFF2F4858)
                      : const Color(0xFF2F4858).withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: FontWeight.w700,
              color: isWarning
                  ? Colors.red
                  : isTotal
                      ? const Color(0xFF00B894)
                      : const Color(0xFF2F4858),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoResultado(
      BuildContext context, tarifa, totalPagado, saldoAnterior) {
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
                'Salida registrada',
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
                _buildInfoRow('TARIFA:', '\$${tarifa.toStringAsFixed(0)}'),
                if (saldoAnterior > 0)
                  _buildInfoRow('SALDO ANTERIOR:',
                      '\$${saldoAnterior.toStringAsFixed(0)}'),
                const Divider(thickness: 2),
                _buildInfoRow(
                    'TOTAL PAGADO:', '\$${totalPagado.toStringAsFixed(0)}',
                    isTotal: true),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B894),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
                            style: const TextStyle(
                              fontSize: 14,
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
                        userInfo.sociedadId,
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
      var response = await _apiService.post('enviar_csv/', {
        'formattedStartDate': start,
        'formattedEndDate': end,
        'id_cliente': userId.toString(),
        'email': email,
        'rut_cliente': userInfo.rut,
      });

      if (response['status'] == 'success') {
        return true;
      } else if (response['status'] == 'error') {
        return false;
      }
      return false;
    } catch (e) {
      loggerGlobal.e('Error al enviar CSV: $e');
      return false;
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

  Future _showProgressDialog(BuildContext context) {
    return showDialog(
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
                child: Lottie.asset('assets/animations/request_code.json'),
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
      ),
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
    setState(() {
      if (_busquedaController.text.isEmpty) {
        _vehiculosFiltrados = List.from(_vehiculos);
      } else {
        _vehiculosFiltrados = _vehiculos
            .where((vehiculo) => vehiculo.patente
                .toLowerCase()
                .contains(_busquedaController.text.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _cargarRegistrosDelDia() async {
    setState(() {
      _isLoading = true;
    });
    _showLoadingDialog();
    try {
      var codigoSociedad = userInfo.sociedadId;

      var jsonResponse = await _apiService.post('obtener_registros_del_dia/', {
        'codigo_sociedad': codigoSociedad,
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
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void pedirCorreos(int codigoSociedad) async {
    loggerGlobal.d('funcion llamada');
    try {
      var responseData = await _apiService
          .post('pedir_correos/', {'sociedad_id': codigoSociedad});

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

  DateTime _convertirHoraLocal(DateTime horaUtc) {
    return horaUtc.toLocal();
  }

  void _refreshData() {
    _refreshAnimationController.reset();
    _refreshAnimationController.forward();
    _cargarRegistrosDelDia();
    logger.d('usuario_registrador ${userInfo.rut}');
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
              const Color(0xFF00B894).withOpacity(0.08),
              Colors.white,
              const Color(0xFF2F4858).withOpacity(0.03),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER COMPACTO
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Registro de Vehículos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _printerConnected
                                  ? _disconnectPrinter
                                  : _searchPrinters,
                              child: _buildPrinterIndicator(),
                            ),
                            const SizedBox(width: 8),
                            RotationTransition(
                              turns: _refreshAnimationController,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _isLoading ? null : _refreshData,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // BOTONES DE ACCIÓN COMPACTOS
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernButton(
                            text: 'Registrar',
                            onPressed: _isProcessing ? null : _registrarEntrada,
                            backgroundColor: Colors.white,
                            textColor: const Color(0xFF2F4858),
                            isLoading: _isProcessing,
                            icon: Icons.add_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildModernButton(
                            text: 'CSV Email',
                            onPressed: mostrarDialogoCorreos,
                            backgroundColor: const Color(0xFF00A085),
                            textColor: Colors.white,
                            icon: Icons.email_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // CAMPOS DE ENTRADA COMPACTOS
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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

              // LISTA DE VEHÍCULOS - MAXIMIZADO
              Expanded(
                child: _vehiculosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_parking,
                              size: 70,
                              color: const Color(0xFF2F4858).withOpacity(0.25),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No hay vehículos registrados',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2F4858).withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Los vehículos aparecerán aquí',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFF2F4858).withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 4,
                          bottom: 80,
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
