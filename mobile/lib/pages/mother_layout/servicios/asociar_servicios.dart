import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:parking/services/parking_service.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:parking/utils/globals.dart';

class AgendarServicioPage extends StatefulWidget {
  const AgendarServicioPage({super.key});

  @override
  AgendarServicioPageState createState() => AgendarServicioPageState();
}

class AgendarServicioPageState extends State<AgendarServicioPage> {
  final ApiService apiService = ApiService();
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  List<Map<String, dynamic>> serviciosAgendados = [];
  bool _isLoading = true;
  List<dynamic> correos = [];

  List<String> correosSeleccionados = [];
  Map<String, bool> correosCheckbox = {};

  @override
  void initState() {
    super.initState();
    _cargarServiciosAgendados();
    pedirCorreos(userInfo.sociedadId);
  }

  Future<void> _cargarServiciosAgendados() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await apiService.get('registro_servicios/');
      setState(() {
        serviciosAgendados = List<Map<String, dynamic>>.from(response['data'])
            .where((servicio) => servicio['servicio_finalizado'] != true)
            .toList();
      });
    } catch (e) {
      _mostrarError('Error al cargar los servicios agendados: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    }
  }

  void _mostrarDialogoServicio({Map<String, dynamic>? servicio}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ServicioDialog(
          servicio: servicio,
          onSave: (nuevoServicio) async {
            try {
              if (servicio == null) {
                // Crear nuevo servicio
                await apiService.post('registro_servicios/', nuevoServicio);
                if (context.mounted) {
                  await _calendarService.insertEvent(context, nuevoServicio);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                // Actualizar servicio existente
                await apiService.put(
                    'registro_servicios/${servicio['id']}/', nuevoServicio);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                // Aquí deberías actualizar el evento en Google Calendar
              }
              _cargarServiciosAgendados();
            } catch (e) {
              _mostrarError('Error al guardar el servicio: $e');
            }
          },
          onDelete: servicio == null
              ? null
              : () async {
                  try {
                    await apiService
                        .delete('registro_servicios/${servicio['id']}/');
                    // Aquí deberías eliminar el evento de Google Calendar

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Servicio Agendado Eliminado')),
                      );
                      _cargarServiciosAgendados();
                    }
                  } catch (e) {
                    _mostrarError('Error al eliminar el servicio: $e');
                  }
                },
        );
      },
    );
  }

  Future<void> _mostrarDialogoConfirmacion(
      Map<String, dynamic> servicio) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar finalización'),
          content: const Text('¿Desea finalizar el servicio agendado?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Finalizar'),
              onPressed: () {
                Navigator.of(context).pop();
                _finalizarServicio(servicio);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _finalizarServicio(Map<String, dynamic> servicio) async {
    try {
      await apiService.put('registro_servicios/${servicio['id']}/', {
        ...servicio,
        'servicio_finalizado': true,
      });
      await _cargarServiciosAgendados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio finalizado')),
        );
      }
    } catch (e) {
      _mostrarError('Error al finalizar el servicio: $e');
    }
  }

  void pedirCorreos(int codigoJefe) async {
    loggerGlobal.d('funcion llamada');
    try {
      var responseData =
          await apiService.post('pedir_correos/', {'cliente_id': codigoJefe});

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

  void mostrarDialogoCorreos() {
    correosSeleccionados.clear();
    correosCheckbox = {for (var correo in correos) correo: false};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Selecciona los correos'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: correos.map((correo) {
                      return CheckboxListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              correo,
                              style: const TextStyle(
                                fontSize: 14.0,
                              ),
                            ),
                          ],
                        ),
                        value: correosCheckbox[correo],
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
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Aceptar'),
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
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSucces(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡Envío CSV exitoso!'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
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
          title: const Text('¡No se encontraron registros!'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> sendData(
      String start, String end, int userId, List<dynamic> email) async {
    try {
      var response = await apiService.post('enviar_csv/', {
        'formattedStartDate': start,
        'formattedEndDate': end,
        'id_cliente': userId.toString(),
        'email': email,
        'rut_cliente': userInfo.rut,
      }); // requiresAuth es true por defecto

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

  Future _showProgressDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          elevation: 5.0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0.0, 3.0),
                  blurRadius: 5.0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                      flex: 2,
                      child: Lottie.asset('assets/animations/request_code.json',
                          repeat: true, animate: true)),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      "ENVIANDO CSV...",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Servicios')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: serviciosAgendados.length,
                    itemBuilder: (context, index) {
                      final servicio = serviciosAgendados[index];
                      return ListTile(
                        title: Text(
                            '${servicio['nombre_vehiculo']} - ${servicio['nombre_servicio']} - ${servicio['patente']}'),
                        subtitle: Text(
                            'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(servicio['dia_agendado']))}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _mostrarDialogoServicio(servicio: servicio),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () =>
                                  _mostrarDialogoConfirmacion(servicio),
                              color: Colors.green,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: mostrarDialogoCorreos,
                  child: const Text(
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color.fromARGB(255, 0, 0, 0)),
                      'Enviar CSV Servicios Registrados Email'),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 85.0, right: 4, left: 4, top: 10),
                  child: ElevatedButton(
                    onPressed: () => _mostrarDialogoServicio(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 25),
                      backgroundColor: const Color.fromARGB(255, 6, 62, 107),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      "AGENDAR SERVICIO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ServicioDialog extends StatefulWidget {
  final Map<String, dynamic>? servicio;
  final Function(Map<String, dynamic>) onSave;
  final Function()? onDelete;

  const ServicioDialog({
    super.key,
    this.servicio,
    required this.onSave,
    this.onDelete,
  });

  @override
  ServicioDialogState createState() => ServicioDialogState();
}

class ServicioDialogState extends State<ServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> serviciosDisponibles = [];
  List<Map<String, dynamic>> clientesDisponibles = [];
  List<Map<String, dynamic>> tiposVehiculos = [];
  Map<String, dynamic>? servicioSeleccionado;
  Map<String, dynamic>? clienteSeleccionado;
  Map<String, dynamic>? tipoVehiculoSeleccionado;
  final TextEditingController _patenteController = TextEditingController();
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  bool pagoCompleto = false;
  int? abonoMonto;
  final TextEditingController _valorPersonalizadoController =
      TextEditingController();
  final TextEditingController _duracionPersonalizadaController =
      TextEditingController();
  bool _usarValorPersonalizado = false;
  bool _usarDuracionPersonalizada = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    if (widget.servicio != null) {
      _inicializarCampos();
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Lottie.asset('assets/animations/loading.json'),
                  ),
                  const SizedBox(width: 16),
                  const Text('Agendando Servicio...'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _guardarServicio() async {
    if (_formKey.currentState!.validate()) {
      // Validaciones adicionales
      String errorMessage = '';

      if (clienteSeleccionado == null) {
        errorMessage += 'Por favor, seleccione un cliente.\n';
      }
      if (servicioSeleccionado == null) {
        errorMessage += 'Por favor, seleccione un servicio.\n';
      }
      if (tipoVehiculoSeleccionado == null) {
        errorMessage += 'Por favor, seleccione un tipo de vehículo.\n';
      }
      if (_patenteController.text.isEmpty) {
        errorMessage += 'Por favor, ingrese la patente.\n';
      }
      if (fechaSeleccionada == null) {
        errorMessage += 'Por favor, seleccione una fecha.\n';
      }
      if (horaSeleccionada == null) {
        errorMessage += 'Por favor, seleccione una hora.\n';
      }
      if (!pagoCompleto && (abonoMonto == null || abonoMonto! <= 0)) {
        errorMessage += 'Por favor, ingrese un monto de abono válido.\n';
      }

      if (errorMessage.isNotEmpty) {
        // Mostrar mensaje de error usando el nuevo método
        _mostrarErrorDialog(errorMessage);
        return;
      }

      _showLoadingDialog();

      final nuevoServicio = {
        'cliente_holding': userInfo.sociedadId,
        'cliente_servicio': clienteSeleccionado!['id'],
        'servicio': servicioSeleccionado!['id'],
        'tipo_vehiculo': tipoVehiculoSeleccionado!['id'],
        'patente': _patenteController.text,
        'dia_agendado': DateTime(
          fechaSeleccionada!.year,
          fechaSeleccionada!.month,
          fechaSeleccionada!.day,
          horaSeleccionada!.hour,
          horaSeleccionada!.minute,
        ).toIso8601String(),
        'cancelado_completo': pagoCompleto,
        'abonado':
            pagoCompleto ? servicioSeleccionado!['valor_servicio'] : abonoMonto,
        'valor_servicio_personalizado': _usarValorPersonalizado
            ? int.tryParse(_valorPersonalizadoController.text)
            : null,
        'duracion_servicio_personalizada': _usarDuracionPersonalizada
            ? int.tryParse(_duracionPersonalizadaController.text)
            : null,
      };

      try {
        // Guardar en el backend
        final servicioGuardado = await widget.onSave(nuevoServicio);
        // Agregar al calendario de Google
        if (mounted) {
          await GoogleCalendarService().insertEvent(context, servicioGuardado);
        }

        // Cerrar todos los diálogos
        if (mounted) {
          Navigator.of(context).pop(); // Cierra el diálogo de carga
          Navigator.of(context).pop(); // Cierra el diálogo de servicio
        }

        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Servicio agendado con éxito')),
          );
        }
      } catch (e) {
        // Cerrar solo el diálogo de carga en caso de error
        loggerGlobal.d('Éxito');
        if (mounted) {
          Navigator.of(context).pop();
        }
        // Mostrar mensaje de error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Éxito')),
          );
        }
      }
    }
  }

  void _mostrarErrorDialog(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: SingleChildScrollView(
            child: ListBody(
              children:
                  mensaje.split('\n').map((error) => Text(error)).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cargarDatos() async {
    try {
      await Future.wait([
        _cargarServicios(),
        _cargarClientes(),
        _cargarTiposVehiculos(),
      ]);
    } catch (e) {
      // Manejar errores
    }
  }

  Future<void> _cargarServicios() async {
    try {
      final response =
          await apiService.get('servicios/?cliente_id=${userInfo.sociedadId}');
      setState(() {
        serviciosDisponibles =
            List<Map<String, dynamic>>.from(response['data']);
        serviciosDisponibles.sort(
            (a, b) => a['nombre_servicio'].compareTo(b['nombre_servicio']));
      });
    } catch (e) {
      // Manejar el error aquí, por ejemplo:
      loggerGlobal.d('Error al cargar servicios: $e');
      // Puedes también mostrar un SnackBar o un diálogo de error si lo deseas
    }
  }

  Future<void> _cargarClientes() async {
    try {
      final response = await apiService
          .get('clientes_servicios/?cliente_id=${userInfo.sociedadId}');
      setState(() {
        clientesDisponibles = List<Map<String, dynamic>>.from(response['data']);
        clientesDisponibles.sort((a, b) => a['nombre'].compareTo(b['nombre']));
      });
    } catch (e) {
      // Manejar el error aquí, por ejemplo:
      loggerGlobal.d('Error al cargar clientes: $e');
      // Puedes también mostrar un SnackBar o un diálogo de error si lo deseas
    }
  }

  Future<void> _cargarTiposVehiculos() async {
    final response = await apiService.get('tipos_vehiculos/');
    setState(() {
      tiposVehiculos = List<Map<String, dynamic>>.from(response['data']);
      tiposVehiculos.sort((a, b) => a['nombre'].compareTo(b['nombre']));
    });
  }

  void _inicializarCampos() {
    if (widget.servicio != null) {
      String sociedadId = widget.servicio!['cliente_servicio'].toString();
      String servicioId = widget.servicio!['servicio'].toString();
      String tipoVehiculoId = widget.servicio!['tipo_vehiculo'].toString();

      clienteSeleccionado =
          _findMatchingItem(clientesDisponibles, {'id': sociedadId});
      servicioSeleccionado =
          _findMatchingItem(serviciosDisponibles, {'id': servicioId});
      tipoVehiculoSeleccionado =
          _findMatchingItem(tiposVehiculos, {'id': tipoVehiculoId});

      _patenteController.text = widget.servicio!['patente'] ?? '';
      fechaSeleccionada =
          DateTime.tryParse(widget.servicio!['dia_agendado']) ?? DateTime.now();
      horaSeleccionada = TimeOfDay.fromDateTime(fechaSeleccionada!);
      pagoCompleto = widget.servicio!['cancelado_completo'] ?? false;
      abonoMonto = widget.servicio!['abonado'];
    }

    if (widget.servicio != null) {
      _valorPersonalizadoController.text =
          widget.servicio!['valor_servicio_personalizado']?.toString() ?? '';
      _duracionPersonalizadaController.text =
          widget.servicio!['duracion_servicio_personalizada']?.toString() ?? '';
      _usarValorPersonalizado =
          widget.servicio!['valor_servicio_personalizado'] != null;
      _usarDuracionPersonalizada =
          widget.servicio!['duracion_servicio_personalizada'] != null;
    }

    if (clienteSeleccionado == null ||
        servicioSeleccionado == null ||
        tipoVehiculoSeleccionado == null) {
      _cargarDatos().then((_) {
        setState(() {
          _inicializarCampos();
        });
      });
    }
  }

  Map<String, dynamic>? _findMatchingItem(
      List<Map<String, dynamic>> items, dynamic value) {
    if (value == null) return null;
    try {
      return items.firstWhere(
        (item) => item['id'].toString() == value['id'].toString(),
      );
    } catch (e) {
      // Si no se encuentra ningún elemento que coincida, devolvemos null
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.servicio == null ? 'Agendar Servicio' : 'Editar Servicio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<Map<String, dynamic>>(
                value:
                    _findMatchingItem(clientesDisponibles, clienteSeleccionado),
                items: [
                  const DropdownMenuItem<Map<String, dynamic>>(
                    value: null,
                    child: Text('Seleccione un cliente'),
                  ),
                  ...clientesDisponibles.map((cliente) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: cliente,
                      child: Text(cliente['nombre']),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    clienteSeleccionado = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Cliente'),
              ),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _findMatchingItem(
                    serviciosDisponibles, servicioSeleccionado),
                items: [
                  const DropdownMenuItem<Map<String, dynamic>>(
                    value: null,
                    child: Text('Seleccione un servicio'),
                  ),
                  ...serviciosDisponibles.map((servicio) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: servicio,
                      child: Text(
                          '${servicio['nombre_servicio']} - \$${servicio['valor_servicio']}'),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    servicioSeleccionado = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Servicio'),
              ),
              if (servicioSeleccionado != null) ...[
                CheckboxListTile(
                  title: const Text('Usar valor personalizado'),
                  value: _usarValorPersonalizado,
                  onChanged: (value) {
                    setState(() {
                      _usarValorPersonalizado = value ?? false;
                    });
                  },
                ),
                if (_usarValorPersonalizado)
                  TextFormField(
                    controller: _valorPersonalizadoController,
                    decoration:
                        const InputDecoration(labelText: 'Valor personalizado'),
                    keyboardType: TextInputType.number,
                  ),
                CheckboxListTile(
                  title: const Text('Usar duración personalizada'),
                  value: _usarDuracionPersonalizada,
                  onChanged: (value) {
                    setState(() {
                      _usarDuracionPersonalizada = value ?? false;
                    });
                  },
                ),
                if (_usarDuracionPersonalizada)
                  TextFormField(
                    controller: _duracionPersonalizadaController,
                    decoration: const InputDecoration(
                        labelText: 'Duración personalizada (minutos)'),
                    keyboardType: TextInputType.number,
                  ),
              ],
              DropdownButtonFormField<Map<String, dynamic>>(
                value:
                    _findMatchingItem(tiposVehiculos, tipoVehiculoSeleccionado),
                items: [
                  const DropdownMenuItem<Map<String, dynamic>>(
                    value: null,
                    child: Text('Seleccione un tipo de vehículo'),
                  ),
                  ...tiposVehiculos.map((tipo) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: tipo,
                      child: Text(tipo['nombre']),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    tipoVehiculoSeleccionado = value;
                  });
                },
                decoration:
                    const InputDecoration(labelText: 'Tipo de Vehículo'),
              ),
              TextFormField(
                controller: _patenteController,
                decoration: const InputDecoration(labelText: 'Patente'),
                validator: (value) =>
                    value!.isEmpty ? 'Por favor ingrese la patente' : null,
              ),
              ListTile(
                title: const Text('Fecha del Servicio'),
                subtitle: Text(fechaSeleccionada != null
                    ? DateFormat('dd/MM/yyyy').format(fechaSeleccionada!)
                    : 'No seleccionada'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _seleccionarFecha,
              ),
              ListTile(
                title: const Text('Hora del Servicio'),
                subtitle: Text(horaSeleccionada != null
                    ? horaSeleccionada!.format(context)
                    : 'No seleccionada'),
                trailing: const Icon(Icons.access_time),
                onTap: _seleccionarHora,
              ),
              CheckboxListTile(
                title: const Text('Pago completo'),
                value: pagoCompleto,
                onChanged: (bool? value) {
                  setState(() {
                    pagoCompleto = value ?? false;
                  });
                },
              ),
              if (!pagoCompleto && servicioSeleccionado != null)
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Monto de abono'),
                  keyboardType: TextInputType.number,
                  initialValue: abonoMonto?.toString(),
                  onChanged: (value) {
                    abonoMonto = int.tryParse(value);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.onDelete != null)
          TextButton(
            onPressed: widget.onDelete,
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _guardarServicio,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        fechaSeleccionada = picked;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: horaSeleccionada ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        horaSeleccionada = picked;
      });
    }
  }

  @override
  void dispose() {
    _patenteController.dispose();
    super.dispose();
  }
}

class GoogleCalendarService {
  static const _scopes = [calendar.CalendarApi.calendarScope];
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  Future<void> insertEvent(
      BuildContext context, Map<String, dynamic> servicio) async {
    try {
      final GoogleSignInAccount? account = await _signIn(context);
      if (account == null) {
        throw Exception('No se pudo iniciar sesión con Google');
      }

      final authHeaders = await account.authHeaders;
      final httpClient = GoogleAuthClient(authHeaders);
      final calendarApi = calendar.CalendarApi(httpClient);

      final event = calendar.Event()
        ..summary = 'Servicio de vehículo'
        ..description =
            'Servicio para ${servicio['nombre_vehiculo']} - ${servicio['patente']} - ${servicio['nombre_servicio']}'
        ..start = (calendar.EventDateTime()
          ..dateTime = DateTime.parse(servicio['dia_agendado'])
          ..timeZone = 'America/Santiago')
        ..end = (calendar.EventDateTime()
          ..dateTime = DateTime.parse(servicio['dia_agendado'])
              .add(const Duration(hours: 1))
          ..timeZone = 'America/Santiago');

      await calendarApi.events.insert(event, 'primary');
      loggerGlobal.d('Evento agregado al calendario de Google');
    } catch (e) {
      loggerGlobal.d('Error al agregar evento a Google Calendar: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(BuildContext context, String eventId) async {
    try {
      final GoogleSignInAccount? account = await _signIn(context);
      if (account == null) {
        throw Exception('No se pudo iniciar sesión con Google');
      }

      final authHeaders = await account.authHeaders;
      final httpClient = GoogleAuthClient(authHeaders);
      final calendarApi = calendar.CalendarApi(httpClient);

      await calendarApi.events.delete('primary', eventId);
      loggerGlobal.d('Evento eliminado del calendario de Google');
    } catch (e) {
      loggerGlobal.d('Error al eliminar evento de Google Calendar: $e');
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> _signIn(BuildContext context) async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      loggerGlobal.d('Error signing in: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión con Google: $error')),
        );
      }
      return null;
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
