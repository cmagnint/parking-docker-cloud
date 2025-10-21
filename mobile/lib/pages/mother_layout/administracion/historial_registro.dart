import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class HistorialRegistros extends StatefulWidget {
  const HistorialRegistros({super.key});

  @override
  HistorialRegistrosState createState() => HistorialRegistrosState();
}

class HistorialRegistrosState extends State<HistorialRegistros>
    with SingleTickerProviderStateMixin {
  DateTime? fechaInicio;
  DateTime? fechaFin;
  List<dynamic> registros = [];
  Set<int> idsParaEliminar = {};
  String mensajeSinRegistros = '';
  ApiService apiService = ApiService();
  bool _isLoading = false;

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.only(bottom: 100),
                  child: _buildRegistrosPanel(),
                ),
              ),
            ),
          ],
        ),
      ),
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
          const Icon(Icons.history, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'HISTORIAL DE REGISTROS',
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
              onPressed: _limpiarBusqueda,
              tooltip: 'Limpiar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrosPanel() {
    return Container(
      margin: const EdgeInsets.all(15),
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
          _buildPanelHeader(),
          _isLoading
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00B894),
                    ),
                  ),
                )
              : registros.isEmpty && mensajeSinRegistros.isNotEmpty
                  ? Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              mensajeSinRegistros,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : registros.isNotEmpty
                      ? Expanded(child: _buildRegistrosList())
                      : const Expanded(
                          child: Center(
                            child: Text(
                              'Selecciona un rango de fechas\npara consultar registros',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2F4858),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
          if (registros.isNotEmpty && idsParaEliminar.isNotEmpty)
            _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.date_range,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Seleccionar Rango de Fechas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F4858),
                  ),
                ),
              ),
              if (registros.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${registros.length} registros',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  'Fecha Inicio',
                  fechaInicio,
                  Icons.calendar_today,
                  () => _seleccionarFecha(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateSelector(
                  'Fecha Fin',
                  fechaFin,
                  Icons.event,
                  () => _seleccionarFecha(context, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (fechaInicio != null && fechaFin != null)
                  ? _consultarRegistros
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B894),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CONSULTAR REGISTROS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime? fecha,
    IconData icon,
    VoidCallback onTap,
  ) {
    String fechaFormateada =
        fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : 'Seleccionar';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                fecha != null ? const Color(0xFF00B894) : Colors.grey.shade300,
            width: fecha != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: fecha != null
              ? const Color(0xFF00B894).withOpacity(0.05)
              : Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: fecha != null
                      ? const Color(0xFF00B894)
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: fecha != null
                        ? const Color(0xFF00B894)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              fechaFormateada,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: fecha != null
                    ? const Color(0xFF2F4858)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrosList() {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: registros.length,
      itemBuilder: (context, index) {
        var registro = registros[index];
        bool isSelected = idsParaEliminar.contains(registro['id']);
        return _buildRegistroCard(registro, isSelected);
      },
    );
  }

  Widget _buildRegistroCard(Map<String, dynamic> registro, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.red.shade300 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.red.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
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
                    color: isSelected
                        ? Colors.red.shade100
                        : const Color(0xFF00B894).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_parking,
                    color: isSelected
                        ? Colors.red.shade700
                        : const Color(0xFF00B894),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patente: ${registro['patente']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F4858),
                        ),
                      ),
                      Text(
                        'Usuario: ${registro['nombre_trabajador'] ?? registro['usuario_registrador']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(registro, isSelected),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.login, 'Entrada',
                registro['hora_inicio'] ?? 'N/A', Colors.green),
            const SizedBox(height: 6),
            _buildInfoRow(
                Icons.logout,
                'Salida',
                registro['hora_termino'] ?? 'Aún en el estacionamiento',
                Colors.orange),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.attach_money, 'Tarifa',
                '\$${registro['tarifa'] ?? 0}', const Color(0xFF00B894)),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.payment, 'Cancelado',
                '\$${registro['cancelado'] ?? 0}', Colors.blue),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.account_balance_wallet, 'Saldo',
                '\$${registro['saldo'] ?? 0}', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> registro, bool isSelected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.edit,
          color: Colors.blue,
          onPressed: () => _mostrarDialogoEditar(registro),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: isSelected ? Icons.undo : Icons.delete,
          color: isSelected ? Colors.orange : Colors.red,
          onPressed: () {
            setState(() {
              if (isSelected) {
                idsParaEliminar.remove(registro['id']);
              } else {
                idsParaEliminar.add(registro['id']);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ElevatedButton(
        onPressed: _confirmarEliminacion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever, size: 20),
            const SizedBox(width: 8),
            Text(
              'ELIMINAR ${idsParaEliminar.length} REGISTRO${idsParaEliminar.length > 1 ? 'S' : ''}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esInicio) async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: esInicio
          ? (fechaInicio ?? DateTime.now())
          : (fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00B894),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2F4858),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaElegida != null) {
      setState(() {
        if (esInicio) {
          fechaInicio = fechaElegida;
          // Si la fecha de inicio es posterior a la fecha de fin, ajustar
          if (fechaFin != null && fechaInicio!.isAfter(fechaFin!)) {
            fechaFin = fechaInicio;
          }
        } else {
          fechaFin = fechaElegida;
          // Si la fecha de fin es anterior a la fecha de inicio, ajustar
          if (fechaInicio != null && fechaFin!.isBefore(fechaInicio!)) {
            fechaInicio = fechaFin;
          }
        }
      });
    }
  }

  Future<void> _consultarRegistros() async {
    if (fechaInicio == null || fechaFin == null) {
      _mostrarDialogo('Error', 'Por favor, seleccione ambas fechas', false);
      return;
    }

    setState(() {
      _isLoading = true;
      registros = [];
      idsParaEliminar.clear();
      mensajeSinRegistros = '';
    });

    var formatoFecha = DateFormat('dd/MM/yyyy');
    var fechaInicioFormateada = formatoFecha.format(fechaInicio!);
    var fechaFinFormateada = formatoFecha.format(fechaFin!);

    try {
      // ✅ Usar GET con query params en la URL unificada
      var response = await apiService.get(
          'gestion_registros/?id_sociedad=${userInfo.sociedadId}&fecha_inicio=$fechaInicioFormateada&fecha_fin=$fechaFinFormateada');

      loggerGlobal.d(response);

      setState(() {
        _isLoading = false;
        if (response['status'] == 'success') {
          registros = response['registros'];
          mensajeSinRegistros = registros.isEmpty
              ? "No se encontraron registros\nen el rango de fechas seleccionado"
              : "";
        } else {
          mensajeSinRegistros =
              "Error al obtener los registros:\n${response['message']}";
        }
      });
    } catch (e) {
      loggerGlobal.e('Error al consultar registros: $e');
      setState(() {
        _isLoading = false;
        mensajeSinRegistros =
            'Error al obtener los registros:\n${e.toString()}';
      });
    }
  }

  void _mostrarDialogoEditar(Map<String, dynamic> registro) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _DialogoEditarRegistro(
          registro: registro,
          onRegistroModificado: () {
            _consultarRegistros();
          },
        );
      },
    );
  }

  void _confirmarEliminacion() {
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('Confirmar Eliminación'),
            ],
          ),
          content: Text(
            '¿Está seguro que desea eliminar ${idsParaEliminar.length} registro${idsParaEliminar.length > 1 ? 's' : ''}?\n\nEsta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Confirmar Eliminación'),
              onPressed: () {
                Navigator.of(context).pop();
                _mostrarSegundaConfirmacion();
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarSegundaConfirmacion() {
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Segunda Confirmación'),
            ],
          ),
          content: const Text(
            '¿Realmente desea eliminar estos registros?\n\nEsta es la última confirmación.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('SÍ, ELIMINAR'),
              onPressed: () {
                Navigator.of(context).pop();
                _eliminarRegistros();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarRegistros() async {
    try {
      // ✅ Usar DELETE en la URL unificada
      var response = await apiService.delete('gestion_registros/', data: {
        'ids': idsParaEliminar.toList(),
      });

      if (response['status'] == 'success') {
        setState(() {
          registros.removeWhere(
              (registro) => idsParaEliminar.contains(registro['id']));
          idsParaEliminar.clear();
        });
        _mostrarDialogo('Éxito', 'Registros eliminados exitosamente', true);
      } else {
        _mostrarDialogo('Error',
            'Error al eliminar los registros:\n${response['message']}', false);
      }
    } catch (e) {
      loggerGlobal.e('Error al eliminar registros: $e');
      _mostrarDialogo(
          'Error', 'Error al eliminar los registros:\n${e.toString()}', false);
    }
  }

  void _limpiarBusqueda() {
    setState(() {
      fechaInicio = null;
      fechaFin = null;
      registros = [];
      idsParaEliminar.clear();
      mensajeSinRegistros = '';
    });
  }

  void _mostrarDialogo(String titulo, String mensaje, bool esExito) {
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
                  color: esExito
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esExito ? Icons.check_circle : Icons.error,
                  color: esExito ? Colors.green : Colors.red,
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
}

// ============================================================================
// DIÁLOGO PARA EDITAR REGISTRO
// ============================================================================

class _DialogoEditarRegistro extends StatefulWidget {
  final Map<String, dynamic> registro;
  final VoidCallback onRegistroModificado;

  const _DialogoEditarRegistro({
    required this.registro,
    required this.onRegistroModificado,
  });

  @override
  State<_DialogoEditarRegistro> createState() => _DialogoEditarRegistroState();
}

class _DialogoEditarRegistroState extends State<_DialogoEditarRegistro> {
  late TextEditingController _patenteController;
  late TextEditingController _tarifaController;
  late TextEditingController _canceladoController;
  late TextEditingController _saldoController;
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _patenteController =
        TextEditingController(text: widget.registro['patente']);
    _tarifaController = TextEditingController(
        text: widget.registro['tarifa']?.toString() ?? '0');
    _canceladoController = TextEditingController(
        text: widget.registro['cancelado']?.toString() ?? '0');
    _saldoController = TextEditingController(
        text: widget.registro['saldo']?.toString() ?? '0');
  }

  @override
  void dispose() {
    _patenteController.dispose();
    _tarifaController.dispose();
    _canceladoController.dispose();
    _saldoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Color(0xFF00B894),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Editar Registro',
                      style: TextStyle(
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
              const SizedBox(height: 24),
              _buildTextField(
                controller: _patenteController,
                label: 'Patente',
                icon: Icons.local_parking,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _tarifaController,
                label: 'Tarifa (CLP)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _canceladoController,
                label: 'Cancelado (CLP)',
                icon: Icons.payment,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _saldoController,
                label: 'Saldo (CLP)',
                icon: Icons.account_balance_wallet,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarCambios,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'GUARDAR CAMBIOS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF00B894), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00B894), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Future<void> _guardarCambios() async {
    // Validar campos
    if (_patenteController.text.isEmpty) {
      _mostrarDialogo('Error', 'La patente no puede estar vacía', false);
      return;
    }

    int? tarifa = int.tryParse(_tarifaController.text);
    int? cancelado = int.tryParse(_canceladoController.text);
    int? saldo = int.tryParse(_saldoController.text);

    if (tarifa == null || tarifa < 0) {
      _mostrarDialogo('Error', 'La tarifa debe ser un número válido', false);
      return;
    }
    if (cancelado == null || cancelado < 0) {
      _mostrarDialogo(
          'Error', 'El monto cancelado debe ser un número válido', false);
      return;
    }
    if (saldo == null || saldo < 0) {
      _mostrarDialogo('Error', 'El saldo debe ser un número válido', false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // ✅ Usar PUT en la URL unificada
      var response = await _apiService.put(
        'gestion_registros/',
        {
          'registro_id': widget.registro['id'],
          'patente': _patenteController.text.toUpperCase(),
          'tarifa': tarifa,
          'cancelado': cancelado,
          'saldo': saldo,
        },
      );

      setState(() {
        _isSaving = false;
      });

      if (response['status'] == 'success') {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onRegistroModificado();
          _mostrarDialogo('Éxito', 'Registro modificado exitosamente', true);
        }
      } else {
        _mostrarDialogo('Error',
            'Error al modificar el registro:\n${response['message']}', false);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      loggerGlobal.e('Error al modificar registro: $e');
      _mostrarDialogo(
          'Error', 'Error al modificar el registro:\n${e.toString()}', false);
    }
  }

  void _mostrarDialogo(String titulo, String mensaje, bool esExito) {
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
                  color: esExito
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esExito ? Icons.check_circle : Icons.error,
                  color: esExito ? Colors.green : Colors.red,
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
}
