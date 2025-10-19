import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importar intl para formateo de fecha
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';
import 'package:lottie/lottie.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  HistorialScreenState createState() => HistorialScreenState();
}

class HistorialScreenState extends State<HistorialScreen> {
  List<Registro> _registros = [];

  int? _rutTrabajadorSeleccionado;

  void _mostrarRegistrosTrabajador(int rut) {
    _rutTrabajadorSeleccionado = rut;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLoadingDialog();
      _pedirHistorial();
    });
  }

  double _calcularTotalDelDia({int? rutSeleccionado}) {
    double total = 0.0;
    for (var registro in _registros) {
      if (registro.total != null &&
          (rutSeleccionado == null ||
              registro.rutRegistrado == rutSeleccionado)) {
        total += registro.total!;
      }
    }
    return total;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // El usuario no debe poder cerrar el diálogo
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Usa el tamaño que prefieras para tu animación Lottie
              SizedBox(
                width: 100,
                height: 100,
                child: Lottie.asset('assets/animations/loading.json'),
              ),
              const SizedBox(width: 16),
              const Text('Cargando Datos...'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pedirHistorial() async {
    final apiService = ApiService();
    const endpoint = 'pedir_historial/';

    // Crear un mapa para almacenar los parámetros
    Map<String, dynamic> params = {};

    // Verificar si el usuario es administrador y enviar el ID del cliente
    if (userInfo.admin) {
      params['id_cliente'] = userInfo.sociedadId.toString();
    } else {
      // Si no es administrador, enviar el rut del usuario actual
      params['usuario_registrador'] = userInfo.rut.toString();
    }

    try {
      // Usar el método get del ApiService
      final response =
          await apiService.get('$endpoint${Uri(queryParameters: params)}');

      if (mounted) {
        Navigator.of(context).pop();
      }

      List<dynamic> registrosJson = response['data'] ??
          []; // Asumiendo que la respuesta tiene una clave 'data'
      loggerGlobal.d(registrosJson);

      setState(() {
        _registros =
            registrosJson.map((json) => Registro.fromJson(json)).toList();
      });
    } catch (e) {
      loggerGlobal.e('Error al pedir historial: $e');
      // Manejo de error
      if (mounted) {
        // Mostrar un diálogo o snackbar con el error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el historial: $e')),
        );
      }
    }
  }

  String _formatearFechaHora(DateTime fechaHora, {bool esHoraTermino = false}) {
    final formato = DateFormat('yyyy-MM-dd - HH:mm:ss');

    // Si es horaTermino y viene con un offset de -04:43, conviértela primero a UTC y luego aplica GMT-3
    if (esHoraTermino) {
      // Ajustar a UTC (suma 4 horas y 43 minutos)
      fechaHora = fechaHora.toUtc().add(const Duration(hours: 0));
    }

    // Ahora, para todas las fechas, convertir de UTC a GMT-3
    fechaHora = fechaHora.toUtc().add(const Duration(hours: -3));

    return formato.format(fechaHora);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Registros'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => navigateToScreen(context, '/Ingreso'),
        ),
      ),
      body: _rutTrabajadorSeleccionado == null
          ? _buildAdminView()
          : _buildUserView(rutSeleccionado: _rutTrabajadorSeleccionado),
    );
  }

  Widget _buildUserView({int? rutSeleccionado}) {
    // Asegúrate de que solo estamos agregando el botón de volver para los admins.
    bool mostrarBotonVolver = userInfo.admin;

    List<Registro> registrosFiltrados = _registros.where((registro) {
      return rutSeleccionado == null ||
          registro.rutRegistrado == rutSeleccionado;
    }).toList();

    return ListView.builder(
      itemCount: registrosFiltrados.length + (mostrarBotonVolver ? 2 : 1),
      itemBuilder: (context, index) {
        if (index == 0 && mostrarBotonVolver) {
          // Botón para volver a la vista de administrador
          return ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Volver a la lista de trabajadores'),
            onTap: () {
              setState(() {
                _rutTrabajadorSeleccionado = null;
              });
            },
          );
        } else if (index <
            registrosFiltrados.length + (mostrarBotonVolver ? 1 : 0)) {
          // Ajusta el índice si se muestra el botón de volver.
          var registro =
              registrosFiltrados[mostrarBotonVolver ? index - 1 : index];
          // El código existente para mostrar cada registro
          return ListTile(
            title: Text(registro.patente),
            subtitle: Text(
                'Inicio: ${_formatearFechaHora(registro.horaInicio)}, Termino: ${(registro.horaTermino) != null ? _formatearFechaHora(registro.horaTermino!, esHoraTermino: true) : '---'}, RUT: ${registro.rutRegistrado}'),
            trailing: registro.total != null
                ? Text('\$${registro.total?.toStringAsFixed(0)}')
                : null,
          );
        } else {
          // Caso especial para el último ítem que muestra el total del día
          return ListTile(
            title: const Text('Total del Día'),
            trailing: Text(
                '\$${_calcularTotalDelDia(rutSeleccionado: rutSeleccionado).toStringAsFixed(0)}'),
          );
        }
      },
    );
  }

  Widget _buildAdminView() {
    if (userInfo.admin) {
      var trabajadores = _obtenerTrabajadoresUnicos();

      return ListView.builder(
        itemCount: trabajadores.length + 1, // +1 para incluir el total general
        itemBuilder: (context, index) {
          if (index < trabajadores.length) {
            var trabajador = trabajadores.values.elementAt(index);
            String titulo = trabajador.rutRegistrado.toString() == userInfo.rut
                ? "ADMINISTRADOR: ${trabajador.nombreTrabajador}"
                : "TRABAJADOR: ${trabajador.nombreTrabajador}";

            return ListTile(
              title: Text(titulo),
              subtitle: Text('RUT: ${trabajador.rutRegistrado}'),
              onTap: () {
                setState(() {
                  _mostrarRegistrosTrabajador(trabajador.rutRegistrado);
                });
              },
            );
          } else {
            // Último ítem que muestra el total general
            return ListTile(
              title: const Text('Total General del Día'),
              trailing: Text('\$${_calcularTotalDelDia().toStringAsFixed(0)}'),
            );
          }
        },
      );
    } else {
      // Para un trabajador no administrador, simplemente muestra su propio historial
      return _buildUserView(rutSeleccionado: int.parse(userInfo.rut));
    }
  }

  Map<int, Registro> _obtenerTrabajadoresUnicos() {
    var trabajadoresUnicos = <int, Registro>{};

    for (var registro in _registros) {
      // Si el rut no está ya en el mapa, lo agrega.
      if (!trabajadoresUnicos.containsKey(registro.rutRegistrado)) {
        trabajadoresUnicos[registro.rutRegistrado] = registro;
      }
    }

    return trabajadoresUnicos;
  }
}

class Registro {
  final String patente;
  final DateTime horaInicio;
  final DateTime? horaTermino;
  final double? total;
  final int rutRegistrado;
  final String nombreTrabajador;

  Registro({
    required this.patente,
    required this.horaInicio,
    this.horaTermino,
    this.total,
    required this.rutRegistrado,
    required this.nombreTrabajador,
  });

  factory Registro.fromJson(Map<String, dynamic> json) {
    return Registro(
      patente: json['patente'],
      horaInicio: DateTime.parse(json['hora_inicio']),
      horaTermino: json['hora_termino'] != null
          ? DateTime.parse(json['hora_termino'])
          : null,
      total: json['total']?.toDouble(), // Usando el operador '?.' aquí
      rutRegistrado: json['rut_trabajador'],
      nombreTrabajador: json['nombre_trabajador'],
    );
  }
}
