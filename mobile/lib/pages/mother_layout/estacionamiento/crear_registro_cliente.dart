import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  ClientesScreenState createState() => ClientesScreenState();
}

class ClientesScreenState extends State<ClientesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _clientes = [];
  bool _isLoading = true;
  String _filtroTipo = 'TODOS';

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
    _fetchClientes();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchClientes() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('clientes/');
      setState(() {
        _clientes = response['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarDialogo('Error', 'Error al cargar clientes: $e', false);
    }
  }

  List<dynamic> get _clientesFiltrados {
    if (_filtroTipo == 'TODOS') {
      return _clientes;
    }
    return _clientes.where((c) => c['tipo'] == _filtroTipo).toList();
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
      floatingActionButton: _buildFloatingButton(),
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
          const Icon(Icons.people_alt, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'CLIENTES FRECUENTES',
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
              onPressed: _fetchClientes,
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
      margin: const EdgeInsets.fromLTRB(15, 15, 15, 70),
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
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00B894),
              ),
            )
          : Column(
              children: [
                _buildPanelHeader(),
                Expanded(child: _buildClientesList()),
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
                  Icons.card_membership,
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
                      'Clientes con Tarifas Especiales',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F4858),
                      ),
                    ),
                    Text(
                      '${_clientesFiltrados.length} ${_filtroTipo == 'TODOS' ? 'en total' : 'con tarifa $_filtroTipo'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_clientes.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildFiltros(),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Row(
      children: [
        _buildFiltroChip('TODOS', Icons.dashboard),
        const SizedBox(width: 8),
        _buildFiltroChip('DIARIA', Icons.today),
        const SizedBox(width: 8),
        _buildFiltroChip('SEMANAL', Icons.date_range),
        const SizedBox(width: 8),
        _buildFiltroChip('MENSUAL', Icons.calendar_month),
      ],
    );
  }

  Widget _buildFiltroChip(String tipo, IconData icon) {
    bool isSelected = _filtroTipo == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filtroTipo = tipo;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00B894) : Colors.grey.shade200,
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
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                tipo == 'TODOS' ? 'TODO' : tipo.substring(0, 3),
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2F4858),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientesList() {
    if (_clientesFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay clientes registrados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _clientesFiltrados.length,
      itemBuilder: (context, index) {
        final cliente = _clientesFiltrados[index];
        return _buildClienteCard(cliente);
      },
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    bool registra = cliente['registrar'] ?? false;
    String tipo = cliente['tipo'] ?? 'DIARIA';

    Color tipoColor = tipo == 'DIARIA'
        ? Colors.blue
        : tipo == 'SEMANAL'
            ? Colors.orange
            : Colors.purple;

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
                    color: tipoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: tipoColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente['nombre_cliente'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F4858),
                        ),
                      ),
                      Text(
                        'RUT: ${cliente['rut_cliente'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tipoColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tipo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.directions_car,
                    'Patente',
                    cliente['patente_cliente'] ?? 'N/A',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.attach_money,
                    'Valor',
                    '\$${cliente['valor'] ?? 0}',
                    const Color(0xFF00B894),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.payment,
                    'Pago',
                    cliente['modo_pago'] ?? 'N/A',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    registra ? Icons.check_circle : Icons.block,
                    'Registra',
                    registra ? 'SÍ' : 'NO',
                    registra ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'EDITAR',
                  color: Colors.blue,
                  onPressed: () => _updateCliente(cliente),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'ELIMINAR',
                  color: Colors.red,
                  onPressed: () => _confirmarEliminacion(cliente),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Container(
      width: MediaQuery.of(context).size.width - 30,
      padding: const EdgeInsets.only(bottom: 70),
      child: ElevatedButton.icon(
        onPressed: _createCliente,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B894),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
        ),
        icon: const Icon(Icons.person_add, size: 24),
        label: const Text(
          'CREAR CLIENTE FRECUENTE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _createCliente() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => const _ClienteDialog(),
    );

    if (result != null) {
      try {
        // Agregar la sociedad del usuario actual
        result['sociedad'] = userInfo.sociedadId;

        await _apiService.post('clientes/', result);
        _mostrarDialogo('Éxito', 'Cliente creado con éxito', true);
        _fetchClientes();
      } catch (e) {
        _mostrarDialogo('Error', 'Error al crear cliente: $e', false);
      }
    }
  }

  Future<void> _updateCliente(dynamic cliente) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => _ClienteDialog(cliente: cliente),
    );

    if (result != null) {
      try {
        // Agregar la sociedad del usuario actual
        result['sociedad'] = userInfo.sociedadId;

        await _apiService.put('clientes/${cliente['id']}/', result);
        _mostrarDialogo('Éxito', 'Cliente actualizado con éxito', true);
        _fetchClientes();
      } catch (e) {
        _mostrarDialogo('Error', 'Error al actualizar cliente: $e', false);
      }
    }
  }

  Future<void> _confirmarEliminacion(dynamic cliente) async {
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
            '¿Está seguro que desea eliminar al cliente "${cliente['nombre_cliente']}"?\n\nEsta acción no se puede deshacer.',
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
              child: const Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCliente(cliente['id']);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCliente(int id) async {
    try {
      await _apiService.delete('clientes/$id/');
      _mostrarDialogo('Éxito', 'Cliente eliminado con éxito', true);
      _fetchClientes();
    } catch (e) {
      _mostrarDialogo('Error', 'Error al eliminar cliente: $e', false);
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

// ============================================================================
// DIÁLOGO PARA CREAR/EDITAR CLIENTE
// ============================================================================

class _ClienteDialog extends StatefulWidget {
  final Map<String, dynamic>? cliente;

  const _ClienteDialog({this.cliente});

  @override
  __ClienteDialogState createState() => __ClienteDialogState();
}

class __ClienteDialogState extends State<_ClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rutController;
  late TextEditingController _nombreController;
  late TextEditingController _patenteController;
  late TextEditingController _valorController;
  late TextEditingController _modoPagoController;
  late String _tipo;
  late bool _registrar;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    _rutController = TextEditingController(text: cliente?['rut_cliente'] ?? '');
    _nombreController =
        TextEditingController(text: cliente?['nombre_cliente'] ?? '');
    _patenteController =
        TextEditingController(text: cliente?['patente_cliente'] ?? '');
    _valorController =
        TextEditingController(text: cliente?['valor']?.toString() ?? '');
    _modoPagoController =
        TextEditingController(text: cliente?['modo_pago'] ?? '');
    _tipo = cliente?['tipo'] ?? 'MENSUAL';
    _registrar = cliente?['registrar'] ?? true;
  }

  @override
  void dispose() {
    _rutController.dispose();
    _nombreController.dispose();
    _patenteController.dispose();
    _valorController.dispose();
    _modoPagoController.dispose();
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
          child: Form(
            key: _formKey,
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
                        Icons.person_add,
                        color: Color(0xFF00B894),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.cliente == null
                            ? 'Crear Cliente'
                            : 'Editar Cliente',
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
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _rutController,
                  label: 'RUT del Cliente',
                  icon: Icons.badge,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el RUT';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nombreController,
                  label: 'Nombre del Cliente',
                  icon: Icons.person,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _patenteController,
                  label: 'Patente del Vehículo',
                  icon: Icons.directions_car,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese la patente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildDropdown(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _valorController,
                  label: 'Valor de la Tarifa (CLP)',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el valor';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _modoPagoController,
                  label: 'Modo de Pago',
                  icon: Icons.payment,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildRegistrarSwitch(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _guardarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'GUARDAR CLIENTE',
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
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
      validator: validator,
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _tipo,
      decoration: InputDecoration(
        labelText: 'Tipo de Tarifa',
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.calendar_today,
            color: Color(0xFF00B894), size: 20),
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
      items: ['DIARIA', 'SEMANAL', 'MENSUAL'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _tipo = newValue!;
        });
      },
    );
  }

  Widget _buildRegistrarSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _registrar
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _registrar ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _registrar ? Icons.check_circle : Icons.block,
            color: _registrar ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Registra Entrada/Salida?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _registrar
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                Text(
                  _registrar
                      ? 'Cliente se registra (tarifa \$0)'
                      : 'Cliente NO se registra (acceso libre)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _registrar,
            onChanged: (bool value) {
              setState(() {
                _registrar = value;
              });
            },
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
          ),
        ],
      ),
    );
  }

  void _guardarCliente() {
    if (_formKey.currentState!.validate()) {
      final rutLimpio = _rutController.text.replaceAll(RegExp(r'[^\d]'), '');
      Navigator.of(context).pop({
        'rut_cliente': rutLimpio,
        'nombre_cliente': _nombreController.text,
        'patente_cliente': _patenteController.text.toUpperCase(),
        'tipo': _tipo,
        'valor': int.parse(_valorController.text),
        'modo_pago': _modoPagoController.text,
        'registrar': _registrar,
      });
    }
  }
}
