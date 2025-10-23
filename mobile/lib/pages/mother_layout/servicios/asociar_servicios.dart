import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:parking/services/parking_service.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:parking/utils/globals.dart';
import 'package:logger/logger.dart';

Logger logger = Logger();

class AgendarServicioPage extends StatefulWidget {
  const AgendarServicioPage({super.key});

  @override
  AgendarServicioPageState createState() => AgendarServicioPageState();
}

class AgendarServicioPageState extends State<AgendarServicioPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  List<dynamic> _serviciosAgendados = [];
  bool _isLoading = true;
  List<dynamic> _correos = [];
  List<String> _correosSeleccionados = [];
  Map<String, bool> _correosCheckbox = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _cargarServiciosAgendados();
    _pedirCorreos(userInfo.sociedadId);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarServiciosAgendados() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 🔴 CAMBIO: Agregar filtro por sociedad_id
      final response = await _apiService
          .get('registro_servicios/?sociedad_id=${userInfo.sociedadId}');

      setState(() {
        _serviciosAgendados = (response['data'] as List)
            .where((servicio) => servicio['servicio_finalizado'] != true)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error al cargar servicios agendados: $e');
      setState(() {
        _serviciosAgendados = [];
        _isLoading = false;
      });
      if (mounted) {
        _mostrarDialogo('Error', 'Error al cargar los servicios: $e');
      }
    }
  }

  Future<void> _pedirCorreos(int sociedadId) async {
    logger.d('Pidiendo correos para sociedad: $sociedadId');
    try {
      // 🔴 CAMBIO: cliente_id → sociedad_id
      var responseData =
          await _apiService.post('pedir_correos/', {'sociedad_id': sociedadId});

      if (responseData['correos'] != null) {
        setState(() {
          _correos = responseData['correos'];
        });
        logger.d('Correos obtenidos: $_correos');
      } else {
        logger.d(responseData['message']);
      }
    } catch (e) {
      logger.e('Error al pedir correos: $e');
    }
  }

  void _mostrarDialogo(String titulo, String mensaje) {
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
                  color: titulo == 'Éxito'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  titulo == 'Éxito' ? Icons.check_circle : Icons.error,
                  color: titulo == 'Éxito' ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Text(titulo),
            ],
          ),
          content: Text(mensaje),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00B894),
              ),
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoServicio({Map<String, dynamic>? servicio}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _ServicioDialog(
          servicio: servicio,
          onSave: (nuevoServicio) async {
            try {
              if (servicio == null) {
                // Crear nuevo servicio
                await _apiService.post('registro_servicios/', nuevoServicio);
                if (context.mounted) {
                  await _calendarService.insertEvent(context, nuevoServicio);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                // Actualizar servicio existente
                await _apiService.put(
                    'registro_servicios/${servicio['id']}/', nuevoServicio);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
              _cargarServiciosAgendados();
              _mostrarDialogo('Éxito', 'Servicio guardado exitosamente');
            } catch (e) {
              _mostrarDialogo('Error', 'Error al guardar el servicio: $e');
            }
          },
          onDelete: servicio == null
              ? null
              : () async {
                  try {
                    await _apiService
                        .delete('registro_servicios/${servicio['id']}/');
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _mostrarDialogo('Éxito', 'Servicio eliminado');
                      _cargarServiciosAgendados();
                    }
                  } catch (e) {
                    _mostrarDialogo('Error', 'Error al eliminar: $e');
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00B894),
              ),
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
      await _apiService.put('registro_servicios/${servicio['id']}/', {
        ...servicio,
        'servicio_finalizado': true,
      });
      await _cargarServiciosAgendados();
      if (mounted) {
        _mostrarDialogo('Éxito', 'Servicio finalizado exitosamente');
      }
    } catch (e) {
      _mostrarDialogo('Error', 'Error al finalizar el servicio: $e');
    }
  }

  void _mostrarDialogoCorreos() {
    _correosSeleccionados.clear();
    _correosCheckbox = {for (var correo in _correos) correo: false};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Selecciona los correos'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _correos.map((correo) {
                      return CheckboxListTile(
                        title: Text(
                          correo,
                          style: const TextStyle(fontSize: 14.0),
                        ),
                        value: _correosCheckbox[correo],
                        activeColor: const Color(0xFF00B894),
                        onChanged: (bool? valor) {
                          setStateDialog(() {
                            _correosCheckbox[correo] = valor ?? false;
                          });
                          if (valor == true) {
                            _correosSeleccionados.add(correo);
                          } else {
                            _correosSeleccionados.remove(correo);
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
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00B894),
                  ),
                  child: const Text('Aceptar'),
                  onPressed: () async {
                    _showProgressDialog(context);
                    bool success =
                        await _enviarDatos(userInfo.sociedadId.toString());
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    if (success) {
                      _mostrarDialogo('Éxito', 'Datos enviados correctamente');
                    } else {
                      _mostrarDialogo('Error', 'Error al enviar datos');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Lottie.asset('assets/animations/loading.json'),
                ),
                const SizedBox(width: 20),
                const Text(
                  'Enviando datos...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _enviarDatos(String idCliente) async {
    try {
      final response = await _apiService.post('enviar_csv_servicios/', {
        'id_cliente': idCliente,
        'email': _correosSeleccionados,
      });

      if (response['status'] == 'success') {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      logger.e('Error al enviar datos: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00B894),
              Color(0xFF00A085),
              Color(0xFF2F4858),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 70),
                  child: _buildServiciosPanel(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: _buildFloatingButtons(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_note, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'SERVICIOS AGENDADOS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: _cargarServiciosAgendados,
              tooltip: 'Recargar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiciosPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 15, 15, 100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00B894).withOpacity(0.1),
                  const Color(0xFF00A085).withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Servicios Activos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F4858),
                        ),
                      ),
                      Text(
                        '${_serviciosAgendados.length} agendados',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00B894),
                      ),
                    ),
                  )
                : _serviciosAgendados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay servicios agendados',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Presiona el botón + para crear uno',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _serviciosAgendados.length,
                        itemBuilder: (context, index) {
                          final servicio = _serviciosAgendados[index];
                          return _buildServicioCard(servicio);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicioCard(Map<String, dynamic> servicio) {
    final diaAgendado = servicio['dia_agendado'] != null
        ? DateTime.parse(servicio['dia_agendado'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.car_repair,
                    color: Color(0xFF00B894),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio['nombre_servicio'] ?? 'Sin servicio',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F4858),
                        ),
                      ),
                      Text(
                        servicio['patente'] ?? 'Sin patente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF2F4858)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'editar') {
                      _mostrarDialogoServicio(servicio: servicio);
                    } else if (value == 'finalizar') {
                      _mostrarDialogoConfirmacion(servicio);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Color(0xFF00B894)),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'finalizar',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 20, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Finalizar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  diaAgendado != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(diaAgendado)
                      : 'Sin fecha',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '\$${servicio['valor_final'] ?? '0'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00B894),
                  ),
                ),
              ],
            ),
            if (servicio['nombre_cliente_servicio'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      servicio['nombre_cliente_servicio'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00B894), Color(0xFF00A085)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B894).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _mostrarDialogoServicio(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'AGENDAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF2F4858),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F4858).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _mostrarDialogoCorreos,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'ENVIAR CSV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Diálogo para crear/editar servicio agendado
class _ServicioDialog extends StatefulWidget {
  final Map<String, dynamic>? servicio;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback? onDelete;

  const _ServicioDialog({
    this.servicio,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_ServicioDialog> createState() => _ServicioDialogState();
}

class _ServicioDialogState extends State<_ServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _patenteController;
  late TextEditingController _valorPersonalizadoController;
  late TextEditingController _duracionPersonalizadaController;

  Map<String, dynamic>? _clienteSeleccionado;
  Map<String, dynamic>? _servicioSeleccionado;
  Map<String, dynamic>? _tipoVehiculoSeleccionado;
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  bool _pagoCompleto = false;
  int? _abonoMonto;
  bool _usarValorPersonalizado = false;
  bool _usarDuracionPersonalizada = false;

  List<dynamic> _clientesServicios = [];
  List<dynamic> _servicios = [];
  List<dynamic> _tiposVehiculos = [];

  @override
  void initState() {
    super.initState();
    _patenteController =
        TextEditingController(text: widget.servicio?['patente'] ?? '');
    _valorPersonalizadoController = TextEditingController();
    _duracionPersonalizadaController = TextEditingController();

    _cargarDatos();

    if (widget.servicio != null) {
      _cargarDatosServicio();
    }
  }

  @override
  void dispose() {
    _patenteController.dispose();
    _valorPersonalizadoController.dispose();
    _duracionPersonalizadaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final clientes = await _apiService
          .get('clientes_servicios/?sociedad_id=${userInfo.sociedadId}');
      final servicios = await _apiService
          .get('servicios/?sociedad_id=${userInfo.sociedadId}');
      final tiposVehiculos = await _apiService.get('tipos_vehiculos/');

      setState(() {
        _clientesServicios = clientes['data'] ?? [];
        _servicios = servicios['data'] ?? [];
        _tiposVehiculos = tiposVehiculos['data'] ?? [];
      });
    } catch (e) {
      logger.e('Error al cargar datos: $e');
    }
  }

  void _cargarDatosServicio() {
    final servicio = widget.servicio!;

    if (servicio['dia_agendado'] != null) {
      final dia = DateTime.parse(servicio['dia_agendado']);
      _fechaSeleccionada = dia;
      _horaSeleccionada = TimeOfDay.fromDateTime(dia);
    }

    _pagoCompleto = servicio['cancelado_completo'] ?? false;
    _abonoMonto = servicio['abonado'];
    _usarValorPersonalizado = servicio['valor_servicio_personalizado'] != null;
    _usarDuracionPersonalizada =
        servicio['duracion_servicio_personalizada'] != null;

    if (_usarValorPersonalizado) {
      _valorPersonalizadoController.text =
          servicio['valor_servicio_personalizado'].toString();
    }

    if (_usarDuracionPersonalizada) {
      final duracion = servicio['duracion_servicio_personalizada'];
      if (duracion != null) {
        final parts = duracion.toString().split(':');
        if (parts.length >= 2) {
          final horas = int.tryParse(parts[0]) ?? 0;
          final minutos = int.tryParse(parts[1]) ?? 0;
          final totalMinutos = (horas * 60) + minutos;
          _duracionPersonalizadaController.text = totalMinutos.toString();
        }
      }
    }
  }

  Map<String, dynamic>? _findMatchingItem(
      List<dynamic> items, Map<String, dynamic>? selected) {
    if (selected == null) return null;
    try {
      return items.firstWhere(
        (item) => item['id'] == selected['id'],
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00B894),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2F4858),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00B894),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2F4858),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _horaSeleccionada = picked;
      });
    }
  }

  void _guardarServicio() {
    if (_formKey.currentState!.validate()) {
      if (_clienteSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor seleccione un cliente')),
        );
        return;
      }

      if (_servicioSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor seleccione un servicio')),
        );
        return;
      }

      if (_fechaSeleccionada == null || _horaSeleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor seleccione fecha y hora')),
        );
        return;
      }

      final diaAgendado = DateTime(
        _fechaSeleccionada!.year,
        _fechaSeleccionada!.month,
        _fechaSeleccionada!.day,
        _horaSeleccionada!.hour,
        _horaSeleccionada!.minute,
      );

      final Map<String, dynamic> datos = {
        'cliente_servicio': _clienteSeleccionado!['id'],
        'servicio': _servicioSeleccionado!['id'],
        'tipo_vehiculo': _tipoVehiculoSeleccionado?['id'],
        'patente': _patenteController.text.trim().toUpperCase(),
        'dia_agendado': diaAgendado.toIso8601String(),
        'cancelado_completo': _pagoCompleto,
        'cliente_sociedad':
            userInfo.sociedadId.toString(), // 🔴 IMPORTANTE: Convertir a String
      };

      if (!_pagoCompleto && _abonoMonto != null) {
        datos['abonado'] = _abonoMonto;
      }

      if (_usarValorPersonalizado &&
          _valorPersonalizadoController.text.isNotEmpty) {
        datos['valor_servicio_personalizado'] =
            int.parse(_valorPersonalizadoController.text);
      }

      if (_usarDuracionPersonalizada &&
          _duracionPersonalizadaController.text.isNotEmpty) {
        final minutos = int.parse(_duracionPersonalizadaController.text);
        final horas = minutos ~/ 60;
        final mins = minutos % 60;
        datos['duracion_servicio_personalizada'] =
            '${horas.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:00';
      }

      widget.onSave(datos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.servicio != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B894), Color(0xFF00A085)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      esEdicion ? 'Editar Servicio' : 'Agendar Servicio',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F4858),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _findMatchingItem(
                            _clientesServicios, _clienteSeleccionado),
                        decoration: InputDecoration(
                          labelText: 'Cliente',
                          prefixIcon: const Icon(Icons.person,
                              color: Color(0xFF00B894)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF00B894), width: 2),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<Map<String, dynamic>>(
                            value: null,
                            child: Text('Seleccione un cliente'),
                          ),
                          ..._clientesServicios.map((cliente) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: cliente,
                              child: Text(cliente['nombre']),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _clienteSeleccionado = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _findMatchingItem(
                            _servicios, _servicioSeleccionado),
                        decoration: InputDecoration(
                          labelText: 'Servicio',
                          prefixIcon: const Icon(Icons.room_service,
                              color: Color(0xFF00B894)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF00B894), width: 2),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<Map<String, dynamic>>(
                            value: null,
                            child: Text('Seleccione un servicio'),
                          ),
                          ..._servicios.map((servicio) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: servicio,
                              child: Text(servicio['nombre_servicio']),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _servicioSeleccionado = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Usar valor personalizado'),
                        value: _usarValorPersonalizado,
                        activeColor: const Color(0xFF00B894),
                        onChanged: (value) {
                          setState(() {
                            _usarValorPersonalizado = value ?? false;
                          });
                        },
                      ),
                      if (_usarValorPersonalizado) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _valorPersonalizadoController,
                          decoration: InputDecoration(
                            labelText: 'Valor personalizado',
                            prefixIcon: const Icon(Icons.attach_money,
                                color: Color(0xFF00B894)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Usar duración personalizada'),
                        value: _usarDuracionPersonalizada,
                        activeColor: const Color(0xFF00B894),
                        onChanged: (value) {
                          setState(() {
                            _usarDuracionPersonalizada = value ?? false;
                          });
                        },
                      ),
                      if (_usarDuracionPersonalizada) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _duracionPersonalizadaController,
                          decoration: InputDecoration(
                            labelText: 'Duración personalizada (minutos)',
                            prefixIcon: const Icon(Icons.timer,
                                color: Color(0xFF00B894)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _findMatchingItem(
                            _tiposVehiculos, _tipoVehiculoSeleccionado),
                        decoration: InputDecoration(
                          labelText: 'Tipo de Vehículo',
                          prefixIcon: const Icon(Icons.directions_car,
                              color: Color(0xFF00B894)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<Map<String, dynamic>>(
                            value: null,
                            child: Text('Seleccione un tipo'),
                          ),
                          ..._tiposVehiculos.map((tipo) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: tipo,
                              child: Text(tipo['nombre']),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _tipoVehiculoSeleccionado = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _patenteController,
                        decoration: InputDecoration(
                          labelText: 'Patente',
                          prefixIcon: const Icon(Icons.confirmation_number,
                              color: Color(0xFF00B894)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) =>
                            value!.isEmpty ? 'Ingrese la patente' : null,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Fecha del Servicio'),
                        subtitle: Text(_fechaSeleccionada != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(_fechaSeleccionada!)
                            : 'No seleccionada'),
                        trailing: const Icon(Icons.calendar_today,
                            color: Color(0xFF00B894)),
                        onTap: _seleccionarFecha,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Hora del Servicio'),
                        subtitle: Text(_horaSeleccionada != null
                            ? _horaSeleccionada!.format(context)
                            : 'No seleccionada'),
                        trailing: const Icon(Icons.access_time,
                            color: Color(0xFF00B894)),
                        onTap: _seleccionarHora,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Pago completo'),
                        value: _pagoCompleto,
                        activeColor: const Color(0xFF00B894),
                        onChanged: (bool? value) {
                          setState(() {
                            _pagoCompleto = value ?? false;
                          });
                        },
                      ),
                      if (!_pagoCompleto && _servicioSeleccionado != null) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Monto de abono',
                            prefixIcon: const Icon(Icons.payments,
                                color: Color(0xFF00B894)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: _abonoMonto?.toString(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            _abonoMonto = int.tryParse(value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.onDelete != null)
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onDelete,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onDelete != null) const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F4858),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00B894), Color(0xFF00A085)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00B894).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _guardarServicio,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: Text(
                              esEdicion ? 'Actualizar' : 'Guardar',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Servicio de Google Calendar
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
            'Servicio para ${servicio['nombre_vehiculo'] ?? 'vehículo'} - ${servicio['patente']} - ${servicio['nombre_servicio'] ?? 'servicio'}'
        ..start = (calendar.EventDateTime()
          ..dateTime = DateTime.parse(servicio['dia_agendado'])
          ..timeZone = 'America/Santiago')
        ..end = (calendar.EventDateTime()
          ..dateTime = DateTime.parse(servicio['dia_agendado'])
              .add(const Duration(hours: 1))
          ..timeZone = 'America/Santiago');

      await calendarApi.events.insert(event, 'primary');
      logger.d('Evento agregado al calendario de Google');
    } catch (e) {
      logger.e('Error al agregar evento a Google Calendar: $e');
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
      logger.d('Evento eliminado del calendario de Google');
    } catch (e) {
      logger.e('Error al eliminar evento de Google Calendar: $e');
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> _signIn(BuildContext context) async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      logger.e('Error signing in: $error');
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
