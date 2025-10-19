import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class ParametrosScreen extends StatefulWidget {
  const ParametrosScreen({super.key});

  @override
  ParametrosScreenState createState() => ParametrosScreenState();
}

class ParametrosScreenState extends State<ParametrosScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  String montoActual = '';
  String intervaloActual = '';
  String montoMinimo = '';
  String intervaloMinimo = '';

  final TextEditingController _nuevoMontoController = TextEditingController();
  final TextEditingController _nuevoIntervaloController =
      TextEditingController();
  final TextEditingController _montoMinimoController = TextEditingController();
  final TextEditingController _intervaloMinimoController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

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
    _fetchParametros();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nuevoMontoController.dispose();
    _nuevoIntervaloController.dispose();
    _montoMinimoController.dispose();
    _intervaloMinimoController.dispose();
    super.dispose();
  }

  Future<void> _fetchParametros() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ⭐ NUEVA URL: GET parametros/{id_sociedad}/
      var response =
          await _apiService.get('parametros/${userInfo.sociedadId}/');

      setState(() {
        montoActual = response['monto_por_intervalo'].toString();
        intervaloActual = response['intervalo_minutos'].toString();
        montoMinimo = response['monto_minimo'].toString();
        intervaloMinimo = response['intervalo_minimo'].toString();
        _isLoading = false;
      });
    } catch (e) {
      loggerGlobal.e('Error al obtener parámetros: $e');
      setState(() {
        _isLoading = false;
      });
      _mostrarDialogoError('Error al cargar parámetros', e.toString());
    }
  }

  Future<void> _actualizarMontos() async {
    // Validar campos
    int? nuevoMonto = int.tryParse(_nuevoMontoController.text);
    int? nuevoIntervalo = int.tryParse(_nuevoIntervaloController.text);
    int? nuevoMontoMinimo = int.tryParse(_montoMinimoController.text);
    int? nuevoIntervaloMinimo = int.tryParse(_intervaloMinimoController.text);

    if (nuevoMonto == null || nuevoMonto <= 0) {
      _mostrarDialogoError('Error', 'El monto debe ser mayor a cero');
      return;
    }
    if (nuevoIntervalo == null || nuevoIntervalo <= 0) {
      _mostrarDialogoError('Error', 'El intervalo debe ser mayor a cero');
      return;
    }
    if (nuevoMontoMinimo == null || nuevoMontoMinimo <= 0) {
      _mostrarDialogoError('Error', 'El monto mínimo debe ser mayor a cero');
      return;
    }
    if (nuevoIntervaloMinimo == null || nuevoIntervaloMinimo <= 0) {
      _mostrarDialogoError('Error', 'El tiempo mínimo debe ser mayor a cero');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // ⭐ NUEVA URL: PUT parametros/{id_sociedad}/
      await _apiService.put('parametros/${userInfo.sociedadId}/', {
        'monto_por_intervalo': nuevoMonto,
        'intervalo_minutos': nuevoIntervalo,
        'monto_minimo': nuevoMontoMinimo,
        'intervalo_minimo': nuevoIntervaloMinimo,
      });

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        _mostrarDialogoExito();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      loggerGlobal.e('Error al actualizar montos: $e');
      _mostrarDialogoError('Error al actualizar', e.toString());
    }
  }

  void _mostrarDialogoExito() {
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
              const Text('¡Éxito!'),
            ],
          ),
          content: const Text('Parámetros actualizados correctamente'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00B894),
              ),
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
                _fetchParametros(); // Recargar datos
                _limpiarFormulario();
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoError(String titulo, String mensaje) {
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

  void _limpiarFormulario() {
    _nuevoMontoController.clear();
    _nuevoIntervaloController.clear();
    _montoMinimoController.clear();
    _intervaloMinimoController.clear();
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
                  child: _buildParametrosPanel(),
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
          const Icon(Icons.settings, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'CONFIGURAR TARIFAS',
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
              onPressed: _fetchParametros,
              tooltip: 'Recargar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParametrosPanel() {
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
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00B894),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00B894).withOpacity(0.1),
                          const Color(0xFF00A085).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B894),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.monetization_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parámetros Actuales',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2F4858),
                                ),
                              ),
                              Text(
                                'Configuración de tarifas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tarifa Principal
                  _buildInfoCard(
                    'Tarifa Principal',
                    Icons.attach_money,
                    Colors.blue,
                    [
                      _buildInfoRow('Monto por intervalo', '\$$montoActual'),
                      _buildInfoRow('Intervalo', '$intervaloActual minutos'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tarifa Mínima
                  _buildInfoCard(
                    'Tarifa Mínima',
                    Icons.timer,
                    Colors.orange,
                    [
                      _buildInfoRow('Monto mínimo', '\$$montoMinimo'),
                      _buildInfoRow(
                          'Tiempo mínimo', '$intervaloMinimo minutos'),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Formulario de actualización
                  const Row(
                    children: [
                      Icon(Icons.edit, color: Color(0xFF00B894), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Actualizar Tarifas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F4858),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildModernTextField(
                    'Nuevo Monto por Intervalo',
                    _nuevoMontoController,
                    Icons.attach_money,
                    '\$ Pesos',
                  ),
                  const SizedBox(height: 14),
                  _buildModernTextField(
                    'Nuevo Intervalo',
                    _nuevoIntervaloController,
                    Icons.access_time,
                    'Minutos',
                  ),
                  const SizedBox(height: 14),
                  _buildModernTextField(
                    'Nuevo Monto Mínimo',
                    _montoMinimoController,
                    Icons.money_off,
                    '\$ Pesos',
                  ),
                  const SizedBox(height: 14),
                  _buildModernTextField(
                    'Nuevo Tiempo Mínimo',
                    _intervaloMinimoController,
                    Icons.timer,
                    'Minutos',
                  ),

                  const SizedBox(height: 24),

                  // Botón actualizar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _actualizarMontos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B894),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
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
                              children: [
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Guardar Cambios',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2F4858),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2F4858),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    String suffix,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF00B894), size: 20),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
        ),
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
