import 'package:flutter/material.dart';
import 'package:parking/services/parking_service.dart';
import 'package:intl/intl.dart';
import 'package:parking/utils/globals.dart';

class SuperRegistro extends StatefulWidget {
  const SuperRegistro({super.key});

  @override
  SuperRegistroState createState() => SuperRegistroState();
}

class SuperRegistroState extends State<SuperRegistro>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> _sociedades = [];
  bool _isLoading = true;
  String _filtroEstado = 'TODOS';
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
    _cargarSociedades();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarSociedades() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await apiService.get('administrar_sociedad/');

      if (data['status'] == 'success') {
        setState(() {
          _sociedades = data['sociedades'];
          _isLoading = false;
        });
      } else {
        _mostrarDialogo('Error', 'No se pudieron cargar las sociedades');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      loggerGlobal.e('Error al cargar sociedades: $e');
      _mostrarDialogo('Error', 'Error al conectar con el servidor: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _sociedadesFiltradas {
    if (_filtroEstado == 'TODOS') {
      return _sociedades;
    }
    return _sociedades
        .where((sociedad) => sociedad['estado'] == _filtroEstado)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2F4858),
        title: const Text(
          'CONSULTAR REGISTROS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header con filtros
                  _buildHeader(),
                  // Lista de sociedades
                  Expanded(
                    child: _sociedadesFiltradas.isEmpty
                        ? _buildEmptyState()
                        : _buildSociedadesList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
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
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
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
                        Icons.assessment,
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
                            'Sociedades Registradas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F4858),
                            ),
                          ),
                          Text(
                            '${_sociedadesFiltradas.length} ${_filtroEstado == 'TODOS' ? 'total' : _filtroEstado.toLowerCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_sociedades.length}',
                        style: const TextStyle(
                          color: Color(0xFF00B894),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('TODOS'),
                      _buildFilterChip('ACTIVO'),
                      _buildFilterChip('INACTIVO'),
                      _buildFilterChip('PRUEBA'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          estado,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF2F4858),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filtroEstado = estado;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF00B894),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF00B894)
              : const Color(0xFF2F4858).withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay sociedades ${_filtroEstado == 'TODOS' ? '' : _filtroEstado.toLowerCase()}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSociedadesList() {
    return RefreshIndicator(
      onRefresh: _cargarSociedades,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sociedadesFiltradas.length,
        itemBuilder: (context, index) {
          final sociedad = _sociedadesFiltradas[index];
          return _buildSociedadCard(sociedad);
        },
      ),
    );
  }

  Widget _buildSociedadCard(Map<String, dynamic> sociedad) {
    final esActivo = sociedad['estado'] == 'ACTIVO';
    final tipoCliente = sociedad['tipo_cliente'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _mostrarSelectorFechas(sociedad),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: esActivo
                              ? [
                                  const Color(0xFF00B894),
                                  const Color(0xFF00A085)
                                ]
                              : [Colors.grey[400]!, Colors.grey[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        tipoCliente == 'PERSONA'
                            ? Icons.person
                            : Icons.business,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sociedad['razon_social'],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2F4858),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tipoCliente == 'PERSONA'
                                      ? Colors.purple.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tipoCliente == 'PERSONA'
                                          ? Icons.person
                                          : Icons.business,
                                      size: 10,
                                      color: tipoCliente == 'PERSONA'
                                          ? Colors.purple
                                          : Colors.blue,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      tipoCliente == 'PERSONA' ? 'PN' : 'SOC',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: tipoCliente == 'PERSONA'
                                            ? Colors.purple
                                            : Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.badge,
                                  size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'RUT: ${sociedad['rut_formateado'] ?? sociedad['rut_sociedad']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esActivo
                        ? const Color(0xFF00B894).withOpacity(0.05)
                        : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics,
                        color: const Color(0xFF00B894),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Consultar Registros',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF00B894),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarSelectorFechas(Map<String, dynamic> sociedad) async {
    DateTime? fechaInicio;
    DateTime? fechaFin;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.date_range, color: Color(0xFF00B894)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seleccionar Período',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    sociedad['razon_social'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fecha Inicio
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: fechaInicio ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Color(0xFF00B894),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            fechaInicio = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: Color(0xFF00B894)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha Inicio',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    fechaInicio != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(fechaInicio!)
                                        : 'Seleccionar fecha',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: fechaInicio != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Fecha Fin
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: fechaFin ?? DateTime.now(),
                          firstDate: fechaInicio ?? DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Color(0xFF00B894),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            fechaFin = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: Color(0xFF00B894)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha Fin',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    fechaFin != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(fechaFin!)
                                        : 'Seleccionar fecha',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: fechaFin != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: (fechaInicio != null && fechaFin != null)
                      ? () {
                          Navigator.of(context).pop();
                          _consultarRegistros(
                              sociedad, fechaInicio!, fechaFin!);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00B894),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Consultar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _consultarRegistros(
    Map<String, dynamic> sociedad,
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
// Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B894)),
                ),
                SizedBox(height: 16),
                Text('Consultando registros...'),
              ],
            ),
          ),
        );
      },
    );
    try {
      final fechaInicioStr = DateFormat('dd/MM/yyyy').format(fechaInicio);
      final fechaFinStr = DateFormat('dd/MM/yyyy').format(fechaFin);

      final data = await apiService.get(
        'consultar_registros_sociedad/?sociedad_id=${sociedad['id']}&fecha_inicio=$fechaInicioStr&fecha_fin=$fechaFinStr',
      );

      Navigator.of(context).pop(); // Cerrar loading

      if (data['status'] == 'success') {
        _mostrarResultados(data['data']);
      } else {
        _mostrarDialogo(
            'Error', data['message'] ?? 'Error al consultar registros');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar loading
      loggerGlobal.e('Error al consultar registros: $e');
      _mostrarDialogo('Error', 'Error al conectar con el servidor: $e');
    }
  }

  void _mostrarResultados(Map<String, dynamic> data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ResultadosScreen(data: data),
      ),
    );
  }

  void _mostrarDialogo(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensaje),
          actions: <Widget>[
            TextButton(
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

// PANTALLA DE RESULTADOS
class _ResultadosScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResultadosScreen({required this.data});
  @override
  Widget build(BuildContext context) {
    final sociedad = data['sociedad'];
    final periodo = data['periodo'];
    final resumen = data['resumen'];
    final registros = data['registros'] as List<dynamic>;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2F4858),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sociedad['nombre'],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              'RUT: ${sociedad['rut']}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Card de resumen
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00B894),
                  Color(0xFF00A085),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF00B894).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.date_range, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Período: ${periodo['fecha_inicio']} - ${periodo['fecha_fin']}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Divider(color: Colors.white30, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResumenItem(
                      Icons.directions_car,
                      'Registros',
                      '${resumen['total_registros']}',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white30,
                    ),
                    _buildResumenItem(
                      Icons.attach_money,
                      'Ingresos Totales',
                      '\$${NumberFormat('#,###', 'es_CL').format(resumen['total_ingresos'])}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de registros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Color(0xFF2F4858), size: 20),
                SizedBox(width: 8),
                Text(
                  'Detalle de Registros',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F4858),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          Expanded(
            child: registros.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay registros en este período',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: registros.length,
                    itemBuilder: (context, index) {
                      final registro = registros[index];
                      return _buildRegistroCard(registro);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistroCard(Map<String, dynamic> registro) {
    final tieneHoraTermino = registro['hora_termino'] != null;
    final tarifa = registro['tarifa'] ?? 0;
    final saldo = registro['saldo'] ?? 0;
    final pagado = saldo == 0;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con patente
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF2F4858),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        registro['patente'].toString().toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pagado
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pagado ? Icons.check_circle : Icons.warning,
                        color: pagado ? Colors.green : Colors.orange,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        pagado ? 'Pagado' : 'Pendiente',
                        style: TextStyle(
                          color: pagado ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Información de tiempos
            _buildInfoRow(
              Icons.login,
              'Entrada',
              registro['hora_inicio'],
              Colors.blue,
            ),
            if (tieneHoraTermino) ...[
              SizedBox(height: 8),
              _buildInfoRow(
                Icons.logout,
                'Salida',
                registro['hora_termino'],
                Colors.red,
              ),
            ],
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.person,
              'Trabajador',
              '${registro['nombre_trabajador']} (${registro['rut_trabajador']})',
              Colors.purple,
            ),

            // Cliente registrado (si existe)
            if (registro['cliente_registrado'] != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_pin, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cliente Registrado',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${registro['cliente_registrado']['nombre']} - ${registro['cliente_registrado']['tipo']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Divider(height: 20),

            // Información financiera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMontoColumn('Tarifa', tarifa, Colors.blue),
                _buildMontoColumn(
                  'Cancelado',
                  registro['cancelado'] ?? 0,
                  Colors.green,
                ),
                _buildMontoColumn('Saldo', saldo, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF2F4858),
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMontoColumn(String label, dynamic monto, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 2),
        Text(
          '${NumberFormat('#,###', 'es_CL').format(monto)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
