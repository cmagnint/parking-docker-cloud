import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:parking/services/parking_service.dart';

class AdministrarCliente extends StatefulWidget {
  const AdministrarCliente({super.key});

  @override
  AdministrarClienteState createState() => AdministrarClienteState();
}

Logger logger = Logger();

class AdministrarClienteState extends State<AdministrarCliente>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _clientes = [];
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
    _cargarClientes();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _apiService.get('administrar_sociedad/');

      if (data['status'] == 'success') {
        setState(() {
          _clientes = data['sociedades'];
          _isLoading = false;
        });
      } else {
        _mostrarDialogo('Error', 'No se pudieron cargar los clientes');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e('Error al cargar clientes: $e');
      _mostrarDialogo('Error', 'Error al conectar con el servidor: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _mostrarUsuariosModal(Map<String, dynamic> cliente) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _DialogoUsuariosCliente(
          apiService: _apiService,
          cliente: cliente,
        );
      },
    );
  }

  Future<void> _cambiarEstadoCliente(int clienteId, String nuevoEstado) async {
    try {
      final data = await _apiService.put(
        'administrar_sociedad/$clienteId/',
        {'estado': nuevoEstado},
      );

      if (data['status'] == 'success') {
        _mostrarDialogo('Éxito', data['message']);
        _cargarClientes();
      } else {
        _mostrarDialogo('Error', data['message']);
      }
    } catch (e) {
      logger.e('Error al cambiar estado: $e');
      _mostrarDialogo('Error', 'Error al cambiar el estado del cliente: $e');
    }
  }

  Future<void> _editarCliente(Map<String, dynamic> cliente) async {
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return _DialogoEditarCliente(cliente: cliente);
      },
    );

    if (resultado != null) {
      try {
        final data = await _apiService.put(
          'administrar_sociedad/${cliente['id']}/',
          resultado,
        );

        if (data['status'] == 'success') {
          _mostrarDialogo('Éxito', data['message']);
          _cargarClientes();
        } else {
          _mostrarDialogo('Error', data['message']);
        }
      } catch (e) {
        logger.e('Error al editar cliente: $e');
        _mostrarDialogo('Error', 'Error al conectar con el servidor: $e');
      }
    }
  }

  List<dynamic> get _clientesFiltrados {
    if (_filtroEstado == 'TODOS') return _clientes;
    return _clientes.where((c) => c['estado'] == _filtroEstado).toList();
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
                  child: _buildClientesPanel(),
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
          const Icon(Icons.business, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ADMINISTRAR CLIENTES',
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
              onPressed: _cargarClientes,
              tooltip: 'Recargar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientesPanel() {
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
                        Icons.business_center,
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
                            'Clientes Registrados',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F4858),
                            ),
                          ),
                          Text(
                            '${_clientesFiltrados.length} ${_filtroEstado == 'TODOS' ? 'en total' : _filtroEstado.toLowerCase()}',
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _mostrarFormularioCrear,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Nuevo Cliente',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'Filtrar:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F4858),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...[
                    ('TODOS', Icons.all_inclusive, null),
                    ('ACTIVO', Icons.check_circle, Colors.green),
                    ('PRUEBA', Icons.schedule, Colors.orange),
                    ('INACTIVO', Icons.cancel, Colors.red),
                  ].map((filtro) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _filtroEstado == filtro.$1,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(filtro.$2, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                filtro.$1,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _filtroEstado = filtro.$1;
                            });
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: filtro.$3?.withOpacity(0.2) ??
                              const Color(0xFF00B894).withOpacity(0.2),
                          checkmarkColor: filtro.$3 ?? const Color(0xFF00B894),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          labelPadding: EdgeInsets.zero,
                        ),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00B894),
                    ),
                  )
                : _clientesFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay clientes ${_filtroEstado == 'TODOS' ? 'registrados' : _filtroEstado.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clientesFiltrados.length,
                        itemBuilder: (context, index) {
                          final cliente = _clientesFiltrados[index];
                          return _buildClienteCard(cliente);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    final esActivo = cliente['estado'] == 'ACTIVO';
    final esPrueba = cliente['estado'] == 'PRUEBA';
    final tipoCliente = cliente['tipo_cliente'] ?? 'SOCIEDAD';

    Color estadoColor;
    IconData estadoIcon;
    if (esActivo) {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
    } else if (esPrueba) {
      estadoColor = Colors.orange;
      estadoIcon = Icons.schedule;
    } else {
      estadoColor = Colors.red;
      estadoIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarUsuariosModal(cliente),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        estadoIcon,
                        color: estadoColor,
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
                                  cliente['razon_social'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2F4858),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tipoCliente == 'PERSONA'
                                      ? Colors.purple.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
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
                                  'RUT: ${cliente['rut_formateado'] ?? cliente['rut_sociedad']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cliente['nombre_admin'],
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people,
                        size: 14,
                        color: Color(0xFF00B894),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${cliente['usuarios_activos']}/${cliente['total_usuarios']} usuarios activos',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF00B894),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.edit,
                        tooltip: 'Editar',
                        color: Colors.blue,
                        onPressed: () => _editarCliente(cliente),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: esActivo ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _cambiarEstadoCliente(
                          cliente['id'],
                          esActivo ? 'INACTIVO' : 'ACTIVO',
                        ),
                        icon: Icon(
                          esActivo ? Icons.block : Icons.check_circle,
                          size: 14,
                        ),
                        label: Text(
                          esActivo ? 'DESACTIVAR' : 'ACTIVAR',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
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
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  void _mostrarFormularioCrear() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _FormularioCrearCliente(
          apiService: _apiService,
          onClienteCreado: () {
            _cargarClientes();
          },
        );
      },
    );
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
}

// Formateador de RUT chileno
class RutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Limitar a 9 caracteres (8 números + 1 dígito verificador)
    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    String formatted = '';

    if (text.length <= 1) {
      formatted = text;
    } else {
      // Separar dígito verificador
      String dv = text[text.length - 1];
      String numero = text.substring(0, text.length - 1);

      // Formatear con puntos
      String reversed = numero.split('').reversed.join('');
      String formattedReversed = '';

      for (int i = 0; i < reversed.length; i++) {
        if (i > 0 && i % 3 == 0) {
          formattedReversed += '.';
        }
        formattedReversed += reversed[i];
      }

      numero = formattedReversed.split('').reversed.join('');
      formatted = '$numero-$dv';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Función para limpiar el RUT (eliminar puntos y guiones)
String limpiarRut(String rut) {
  return rut.replaceAll(RegExp(r'[^0-9kK]'), '');
}

// Widget para editar cliente
class _DialogoEditarCliente extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const _DialogoEditarCliente({required this.cliente});

  @override
  State<_DialogoEditarCliente> createState() => _DialogoEditarClienteState();
}

class _DialogoEditarClienteState extends State<_DialogoEditarCliente> {
  late TextEditingController _razonSocialController;
  late TextEditingController _nombreAdminController;
  late TextEditingController _correoAdminController;

  @override
  void initState() {
    super.initState();
    _razonSocialController =
        TextEditingController(text: widget.cliente['razon_social']);
    _nombreAdminController =
        TextEditingController(text: widget.cliente['nombre_admin']);
    _correoAdminController =
        TextEditingController(text: widget.cliente['correo_admin']);
  }

  @override
  void dispose() {
    _razonSocialController.dispose();
    _nombreAdminController.dispose();
    _correoAdminController.dispose();
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B894), Color(0xFF00A085)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'EDITAR CLIENTE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F4858),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.grey,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 18, color: Color(0xFF2F4858)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'RUT: ${widget.cliente['rut_formateado'] ?? widget.cliente['rut_sociedad']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F4858),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildModernTextField(
                controller: _razonSocialController,
                label: 'Razón Social',
                icon: Icons.business,
              ),
              const SizedBox(height: 14),
              _buildModernTextField(
                controller: _nombreAdminController,
                label: 'Nombre Administrador',
                icon: Icons.person,
              ),
              const SizedBox(height: 14),
              _buildModernTextField(
                controller: _correoAdminController,
                label: 'Correo Administrador',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final resultado = <String, String>{};

                        if (_razonSocialController.text.isNotEmpty &&
                            _razonSocialController.text !=
                                widget.cliente['razon_social']) {
                          resultado['razon_social'] =
                              _razonSocialController.text;
                        }

                        if (_nombreAdminController.text.isNotEmpty &&
                            _nombreAdminController.text !=
                                widget.cliente['nombre_admin']) {
                          resultado['nombre_admin'] =
                              _nombreAdminController.text;
                        }

                        if (_correoAdminController.text.isNotEmpty &&
                            _correoAdminController.text !=
                                widget.cliente['correo_admin']) {
                          resultado['correo_admin'] =
                              _correoAdminController.text;
                        }

                        if (resultado.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('No hay cambios para guardar'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.of(context).pop(resultado);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B894),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
}

// Widget separado para el formulario de crear cliente
class _FormularioCrearCliente extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onClienteCreado;

  const _FormularioCrearCliente({
    required this.apiService,
    required this.onClienteCreado,
  });

  @override
  State<_FormularioCrearCliente> createState() =>
      _FormularioCrearClienteState();
}

class _FormularioCrearClienteState extends State<_FormularioCrearCliente> {
  // Campos del representante legal (siempre obligatorios)
  final TextEditingController _nombreRepresentanteController =
      TextEditingController();
  final TextEditingController _rutRepresentanteController =
      TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  // Campos de la sociedad (solo si es SOCIEDAD)
  final TextEditingController _razonSocialController = TextEditingController();
  final TextEditingController _rutSociedadController = TextEditingController();
  final TextEditingController _giroController = TextEditingController();

  // Campos de ubicación (siempre obligatorios)
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _comunaController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _notaController = TextEditingController();

  String _tipoCliente = 'SOCIEDAD';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Agregar listeners para actualizar el estado cuando cambien los campos
    _nombreRepresentanteController.addListener(_actualizarEstado);
    _rutRepresentanteController.addListener(_actualizarEstado);
    _correoController.addListener(_actualizarEstado);
    _direccionController.addListener(_actualizarEstado);
    _comunaController.addListener(_actualizarEstado);
    _ciudadController.addListener(_actualizarEstado);
    _regionController.addListener(_actualizarEstado);
    _razonSocialController.addListener(_actualizarEstado);
    _rutSociedadController.addListener(_actualizarEstado);
    _giroController.addListener(_actualizarEstado);
  }

  void _actualizarEstado() {
    setState(() {});
  }

  @override
  void dispose() {
    _nombreRepresentanteController.dispose();
    _rutRepresentanteController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _razonSocialController.dispose();
    _rutSociedadController.dispose();
    _giroController.dispose();
    _direccionController.dispose();
    _comunaController.dispose();
    _ciudadController.dispose();
    _regionController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  // Getter para verificar si todos los campos obligatorios están llenos
  bool get _camposObligatoriosCompletos {
    // Campos siempre obligatorios
    bool camposBasicos = _nombreRepresentanteController.text.isNotEmpty &&
        _rutRepresentanteController.text.isNotEmpty &&
        _correoController.text.isNotEmpty &&
        _direccionController.text.isNotEmpty &&
        _comunaController.text.isNotEmpty &&
        _ciudadController.text.isNotEmpty &&
        _regionController.text.isNotEmpty;

    // Si es SOCIEDAD, verificar campos adicionales
    if (_tipoCliente == 'SOCIEDAD') {
      return camposBasicos &&
          _razonSocialController.text.isNotEmpty &&
          _rutSociedadController.text.isNotEmpty &&
          _giroController.text.isNotEmpty; // Giro ahora es obligatorio
    }

    return camposBasicos;
  }

  void _crearUsuario() async {
    if (!_camposObligatoriosCompletos) {
      _mostrarDialogo(
          'Error', 'Por favor complete todos los campos obligatorios');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Preparar datos base con RUTs limpios
      final Map<String, dynamic> requestData = {
        'tipo_cliente': _tipoCliente,
        // Representante legal (siempre) - RUT limpio
        'rut_representante': limpiarRut(_rutRepresentanteController.text),
        'nombre_representante': _nombreRepresentanteController.text,
        'correo': _correoController.text,
        'telefono': _telefonoController.text,
        // Ubicación (siempre)
        'direccion': _direccionController.text,
        'comuna': _comunaController.text,
        'ciudad': _ciudadController.text,
        'region': _regionController.text,
        'nota': _notaController.text,
        'estado': 'ACTIVO',
      };

      // Si es SOCIEDAD, agregar campos específicos con RUT limpio
      if (_tipoCliente == 'SOCIEDAD') {
        requestData['razon_social'] = _razonSocialController.text;
        requestData['rut_sociedad'] = limpiarRut(_rutSociedadController.text);
        requestData['giro'] = _giroController.text;
      }

      final data = await widget.apiService.post(
        'administrar_sociedad/',
        requestData,
      );

      setState(() {
        _isCreating = false;
      });

      if (data['status'] == 'success') {
        Navigator.of(context).pop();
        widget.onClienteCreado();

        final usuarioAdmin = data['usuario_admin'] ?? {};
        final rut = usuarioAdmin['rut'] ?? 'No disponible';
        final password = usuarioAdmin['password_temporal'] ?? 'No disponible';

        _mostrarDialogoConPassword(rut, password);
      } else {
        _mostrarDialogo('Error', data['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      logger.e('Error al crear cliente: $e');
      _mostrarDialogo('Error', 'Error al conectar con el servidor: $e');
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.error, color: Colors.red),
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

  // Función auxiliar para copiar al portapapeles
  Future<void> _copiarAlPortapapeles(String texto, String etiqueta) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$etiqueta copiado al portapapeles'),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _mostrarDialogoConPassword(String rut, String password) {
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle, color: Colors.green),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cliente creado exitosamente',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo RUT con botón copiar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.badge,
                          size: 18,
                          color: Color(0xFF2F4858),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Usuario (RUT)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F4858),
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _copiarAlPortapapeles(rut, 'RUT'),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B894).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy,
                                    size: 14,
                                    color: Color(0xFF00B894),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copiar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00B894),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      rut,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F4858),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Campo Contraseña con botón copiar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 18,
                          color: Color(0xFF2F4858),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Contraseña temporal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F4858),
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                _copiarAlPortapapeles(password, 'Contraseña'),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B894).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy,
                                    size: 14,
                                    color: Color(0xFF00B894),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copiar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00B894),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      password,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: Color(0xFF2F4858),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Advertencia
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guarda esta información de forma segura. No se mostrará nuevamente.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B894),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF00A085)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_business,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'CREAR NUEVO CLIENTE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed:
                        _isCreating ? null : () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Formulario
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    // Selector de tipo de cliente
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00B894).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.category,
                                color: Color(0xFF00B894),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tipo de Cliente',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2F4858),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTipoButton(
                                  'SOCIEDAD',
                                  'Empresa',
                                  Icons.business,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTipoButton(
                                  'PERSONA',
                                  'Persona Natural',
                                  Icons.person,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // SECCIÓN: Datos de la Sociedad (solo si es SOCIEDAD)
                    if (_tipoCliente == 'SOCIEDAD') ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(Icons.business,
                                color: Color(0xFF00B894), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Datos de la Empresa',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2F4858),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildModernTextField(
                        'Razón Social *',
                        _razonSocialController,
                        Icons.business,
                      ),
                      const SizedBox(height: 14),
                      _buildModernTextField(
                        'RUT Empresa (ej: 9.771.793-1) *',
                        _rutSociedadController,
                        Icons.badge,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RutInputFormatter()],
                      ),
                      const SizedBox(height: 14),
                      _buildModernTextField(
                        'Giro Comercial *',
                        _giroController,
                        Icons.work,
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],

                    // SECCIÓN: Representante Legal (siempre obligatorio)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin,
                              color: Color(0xFF2F4858), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _tipoCliente == 'PERSONA'
                                ? 'Datos Personales'
                                : 'Representante Legal',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F4858),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      _tipoCliente == 'PERSONA'
                          ? 'Nombre Completo *'
                          : 'Nombre Representante Legal *',
                      _nombreRepresentanteController,
                      Icons.person,
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      _tipoCliente == 'PERSONA'
                          ? 'RUT (ej: 9.771.793-1) *'
                          : 'RUT Representante (ej: 9.771.793-1) *',
                      _rutRepresentanteController,
                      Icons.badge,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RutInputFormatter()],
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      'Correo Electrónico *',
                      _correoController,
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      'Teléfono (opcional)',
                      _telefonoController,
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // SECCIÓN: Dirección
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Color(0xFF00A085), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Dirección',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F4858),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      'Dirección *',
                      _direccionController,
                      Icons.location_on,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            'Comuna *',
                            _comunaController,
                            Icons.location_city,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModernTextField(
                            'Ciudad *',
                            _ciudadController,
                            Icons.location_city,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      'Región *',
                      _regionController,
                      Icons.map,
                    ),
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      'Notas (opcional)',
                      _notaController,
                      Icons.notes,
                    ),
                  ],
                ),
              ),
            ),

            // Footer con botón crear (solo visible cuando campos obligatorios están completos)
            if (_camposObligatoriosCompletos)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _crearUsuario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Crear Cliente',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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

  Widget _buildTipoButton(String value, String label, IconData icon) {
    final isSelected = _tipoCliente == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _tipoCliente = value;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00B894) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFF00B894) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF2F4858),
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2F4858),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para mostrar usuarios de un cliente en modal
class _DialogoUsuariosCliente extends StatefulWidget {
  final ApiService apiService;
  final Map<String, dynamic> cliente;

  const _DialogoUsuariosCliente({
    required this.apiService,
    required this.cliente,
  });

  @override
  State<_DialogoUsuariosCliente> createState() =>
      _DialogoUsuariosClienteState();
}

class _DialogoUsuariosClienteState extends State<_DialogoUsuariosCliente> {
  List<dynamic> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data =
          await widget.apiService.get('data_usuarios/${widget.cliente['id']}/');

      setState(() {
        _usuarios = data['usuarios'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error al cargar usuarios: $e');
      setState(() {
        _usuarios = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F4858), Color(0xFF00A085)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Usuarios',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.cliente['razon_social'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2F4858),
                      ),
                    )
                  : _usuarios.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Este cliente no tiene\nusuarios registrados',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _usuarios.length,
                          itemBuilder: (context, index) {
                            final usuario = _usuarios[index];
                            return _buildUsuarioCard(usuario);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsuarioCard(Map<String, dynamic> usuario) {
    final esActivo = usuario['estado'] == 'ON';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: esActivo
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                esActivo ? Icons.check_circle : Icons.cancel,
                color: esActivo ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario['nombre'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F4858),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 11, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        usuario['rut'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.email, size: 11, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          usuario['correo'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: esActivo
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      usuario['estado'],
                      style: TextStyle(
                        color: esActivo ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
