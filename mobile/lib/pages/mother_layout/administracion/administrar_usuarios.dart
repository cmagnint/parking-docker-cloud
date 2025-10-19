import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

String limpiarRut(String rut) {
  // Elimina puntos, guiones y espacios, dejando solo números y K/k
  return rut.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
}

class AdministrarUsuarios extends StatefulWidget {
  const AdministrarUsuarios({super.key});

  @override
  AdministrarUsuariosState createState() => AdministrarUsuariosState();
}

Logger logger = Logger();

class AdministrarUsuariosState extends State<AdministrarUsuarios>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _usuarios = [];
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
    _cargarUsuarios();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ⭐ NUEVA URL: GET usuarios/{id_sociedad}/
      final data = await _apiService.get('usuarios/${userInfo.sociedadId}/');

      if (data['status'] == 'success') {
        setState(() {
          _usuarios = data['usuarios'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _usuarios = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e('Error al cargar usuarios: $e');
      setState(() {
        _usuarios = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _cambiarEstadoUsuario(String rut, String nuevoEstado) async {
    try {
      // ⭐ ASEGURAR QUE EL RUT ESTÉ LIMPIO antes de enviar
      String rutLimpio = limpiarRut(rut);

      logger.d('Cambiando estado del RUT: $rutLimpio a $nuevoEstado');

      // ⭐ NUEVA URL: PUT usuarios/{id_sociedad}/{rut}/
      final data = await _apiService.put(
        'usuarios/${userInfo.sociedadId}/$rutLimpio/',
        {'estado': nuevoEstado},
      );

      if (data['status'] == 'success') {
        _mostrarDialogo('Éxito', data['message']);
        _cargarUsuarios();
      } else {
        _mostrarDialogo('Error', data['message']);
      }
    } catch (e) {
      logger.e('Error al cambiar estado: $e');
      _mostrarDialogo('Error', 'Error al cambiar el estado del usuario: $e');
    }
  }

  Future<void> _editarUsuario(Map<String, dynamic> usuario) async {
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return _DialogoEditarUsuario(usuario: usuario);
      },
    );

    if (resultado != null) {
      try {
        // ⭐ LIMPIAR EL RUT antes de enviar
        String rutLimpio = limpiarRut(usuario['rut']);

        logger.d('Editando usuario con RUT: $rutLimpio');

        // ⭐ NUEVA URL: PUT usuarios/{id_sociedad}/{rut}/
        final data = await _apiService.put(
          'usuarios/${userInfo.sociedadId}/$rutLimpio/',
          resultado,
        );

        if (data['status'] == 'success') {
          _mostrarDialogo('Éxito', data['message']);
          _cargarUsuarios();
        } else {
          _mostrarDialogo('Error', data['message']);
        }
      } catch (e) {
        logger.e('Error al editar usuario: $e');
        _mostrarDialogo('Error', 'Error al conectar con el servidor: $e');
      }
    }
  }

  Future<void> _eliminarUsuario(String rut, String nombre) async {
    final confirmar = await showDialog<bool>(
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
              const Text('Confirmar'),
            ],
          ),
          content: Text('¿Está seguro que desea eliminar al usuario $nombre?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Eliminar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        // ⭐ LIMPIAR EL RUT antes de enviar
        String rutLimpio = limpiarRut(rut);

        logger.d('Eliminando usuario con RUT: $rutLimpio');

        // ⭐ NUEVA URL: DELETE usuarios/{id_sociedad}/{rut}/
        final data = await _apiService.delete(
          'usuarios/${userInfo.sociedadId}/$rutLimpio/',
        );

        if (data['status'] == 'success') {
          _mostrarDialogo('Éxito', data['message']);
          _cargarUsuarios();
        } else {
          _mostrarDialogo('Error', data['message']);
        }
      } catch (e) {
        logger.e('Error al eliminar usuario: $e');
        _mostrarDialogo('Error', 'Error al eliminar el usuario: $e');
      }
    }
  }

  List<dynamic> get _usuariosFiltrados {
    if (_filtroEstado == 'TODOS') return _usuarios;
    return _usuarios.where((u) => u['estado'] == _filtroEstado).toList();
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
                  child: _buildUsuariosPanel(),
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
          const Icon(Icons.people, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ADMINISTRAR USUARIOS',
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
              onPressed: _cargarUsuarios,
              tooltip: 'Recargar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuariosPanel() {
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
                        Icons.group,
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
                            'Usuarios Registrados',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F4858),
                            ),
                          ),
                          Text(
                            '${_usuariosFiltrados.length} ${_filtroEstado == 'TODOS' ? 'en total' : _filtroEstado == 'ON' ? 'activos' : 'inactivos'}',
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
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text(
                      'Nuevo Usuario',
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
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('TODOS', Icons.all_inclusive, null),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                            'ON', Icons.check_circle, Colors.green),
                        const SizedBox(width: 6),
                        _buildFilterChip('OFF', Icons.cancel, Colors.red),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00B894),
                    ),
                  )
                : _usuariosFiltrados.isEmpty
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
                              'No hay usuarios ${_filtroEstado == 'TODOS' ? 'registrados' : _filtroEstado == 'ON' ? 'activos' : 'inactivos'}',
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
                        itemCount: _usuariosFiltrados.length,
                        itemBuilder: (context, index) {
                          final usuario = _usuariosFiltrados[index];
                          return _buildUsuarioCard(usuario);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String estado, IconData icon, Color? color) {
    final isSelected = _filtroEstado == estado;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(estado, style: const TextStyle(fontSize: 11)),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _filtroEstado = estado;
        });
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor:
          color?.withOpacity(0.2) ?? const Color(0xFF00B894).withOpacity(0.2),
      checkmarkColor: color ?? const Color(0xFF00B894),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelPadding: EdgeInsets.zero,
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: esActivo
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esActivo ? Icons.check_circle : Icons.cancel,
                    color: esActivo ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario['nombre'],
                        style: const TextStyle(
                          fontSize: 14,
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    tooltip: 'Editar',
                    color: Colors.blue,
                    onPressed: () => _editarUsuario(usuario),
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
                    onPressed: () => _cambiarEstadoUsuario(
                      usuario['rut'],
                      esActivo ? 'OFF' : 'ON',
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
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete,
                  tooltip: 'Eliminar',
                  color: Colors.orange,
                  onPressed: () => _eliminarUsuario(
                    usuario['rut'],
                    usuario['nombre'],
                  ),
                ),
              ],
            ),
          ],
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
        return _FormularioCrearUsuario(
          apiService: _apiService,
          onUsuarioCreado: () {
            _cargarUsuarios();
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

// Widget para editar usuario
class _DialogoEditarUsuario extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const _DialogoEditarUsuario({required this.usuario});

  @override
  State<_DialogoEditarUsuario> createState() => _DialogoEditarUsuarioState();
}

class _DialogoEditarUsuarioState extends State<_DialogoEditarUsuario> {
  late TextEditingController _nombreController;
  late TextEditingController _correoController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.usuario['nombre']);
    _correoController = TextEditingController(text: widget.usuario['correo']);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
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
                      'EDITAR USUARIO',
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
                        'RUT: ${widget.usuario['rut']}',
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
                controller: _nombreController,
                label: 'Nombre',
                icon: Icons.person,
              ),
              const SizedBox(height: 14),
              _buildModernTextField(
                controller: _correoController,
                label: 'Correo',
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

                        if (_nombreController.text.isNotEmpty &&
                            _nombreController.text !=
                                widget.usuario['nombre']) {
                          resultado['nombre'] = _nombreController.text;
                        }

                        if (_correoController.text.isNotEmpty &&
                            _correoController.text !=
                                widget.usuario['correo']) {
                          resultado['correo'] = _correoController.text;
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

    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    String formatted = '';

    if (text.length <= 1) {
      formatted = text;
    } else {
      String dv = text[text.length - 1];
      String numero = text.substring(0, text.length - 1);

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

// Widget para crear usuario
class _FormularioCrearUsuario extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onUsuarioCreado;

  const _FormularioCrearUsuario({
    required this.apiService,
    required this.onUsuarioCreado,
  });

  @override
  State<_FormularioCrearUsuario> createState() =>
      _FormularioCrearUsuarioState();
}

class _FormularioCrearUsuarioState extends State<_FormularioCrearUsuario> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();

  bool _isCreating = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  bool get _camposCompletos {
    return _nombreController.text.isNotEmpty &&
        _rutController.text.isNotEmpty &&
        _correoController.text.isNotEmpty;
  }

  void _crearUsuario() async {
    if (!_camposCompletos) {
      _mostrarDialogo('Error', 'Por favor complete todos los campos');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // ⭐ LIMPIAR EL RUT: eliminar puntos, guiones, espacios
      // Ejemplo: "9.771.793-1" -> "97717931"
      String rutLimpio = limpiarRut(_rutController.text);

      logger.d('RUT original: ${_rutController.text}');
      logger.d('RUT limpio enviado: $rutLimpio');

      // ⭐ NUEVA URL: POST usuarios/{id_sociedad}/
      final data =
          await widget.apiService.post('usuarios/${userInfo.sociedadId}/', {
        'rut': rutLimpio, // ⭐ Enviar RUT sin puntos ni guiones
        'nombre': _nombreController.text.trim(),
        'correo': _correoController.text.trim().toLowerCase(),
      });

      setState(() {
        _isCreating = false;
      });

      if (data['status'] == 'success') {
        Navigator.of(context).pop();
        widget.onUsuarioCreado();

        final usuarioData = data['usuario'] ?? {};
        final rutCreado = usuarioData['rut'] ?? rutLimpio;
        final password = usuarioData['password_temporal'] ?? 'No disponible';

        _mostrarDialogoConPassword(
          rutCreado,
          password,
        );
      } else {
        _mostrarDialogo('Error', data['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      logger.e('Error al crear usuario: $e');
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
                  'Usuario creado',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        'Guarda esta información. No se mostrará nuevamente.',
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF00A085)],
                ),
                borderRadius: BorderRadius.only(
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
                      Icons.person_add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'NUEVO USUARIO',
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildModernTextField(
                    'Nombre Completo *',
                    _nombreController,
                    Icons.person,
                  ),
                  const SizedBox(height: 14),
                  _buildModernTextField(
                    'RUT (ej: 9.771.793-1) *',
                    _rutController,
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
                  const SizedBox(height: 24),
                  if (_camposCompletos)
                    SizedBox(
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_add, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Crear Usuario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
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
      onChanged: (_) => setState(() {}),
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
