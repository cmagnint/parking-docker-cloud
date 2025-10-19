import 'package:flutter/material.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class TokenCheckScreen extends StatefulWidget {
  const TokenCheckScreen({super.key});

  @override
  TokenCheckScreenState createState() => TokenCheckScreenState();
}

class TokenCheckScreenState extends State<TokenCheckScreen> {
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
  }

  Future<void> _checkTokenAndNavigate() async {
    // Pequeña pausa para mostrar la pantalla
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Obtener token guardado
      String? token = await storage.read(key: 'authToken');

      if (token == null || token.isEmpty) {
        // No hay token, ir al login
        _navigateToLogin();
        return;
      }

      // Verificar token usando el método POST existente
      final response = await apiService.post('check_token/', {'token': token});

      if (response['valid'] == true && response['status'] == 'success') {
        // Token válido, cargar datos del usuario
        _loadUserDataAndNavigateHome(response);
      } else {
        // Token inválido o expirado, ir al login
        _navigateToLogin();
      }
    } catch (e) {
      loggerGlobal.e('Error checking token: $e');
      // En caso de error, ir al login
      _navigateToLogin();
    }
  }

  void _loadUserDataAndNavigateHome(Map<String, dynamic> userData) {
    // Cargar los mismos datos que en login
    userInfo.admin = userData['admin'] ?? false;
    userInfo.sociedadId = userData['sociedad_id'] ?? 0;
    userInfo.email = userData['correo'] ?? '';
    userInfo.superadmin = userData['superadmin'] ?? false;
    userInfo.name = userData['name'] ?? '';
    userInfo.rut = userData['rut'] ?? '';

    // Cargar parámetros adicionales si están disponibles
    userInfo.valorParametro = userData['valor_parametro'] ?? 0;
    userInfo.tiempoParametro = userData['intervalo_parametro'] ?? 0;
    userInfo.montoMinimo = userData['monto_minimo'] ?? 0;
    userInfo.tiempoMinimo = userData['intervalo_minimo'] ?? 0;

    // Ir al home
    if (mounted) {
      navigateToScreen(context, '/Mother_Layout');
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      navigateToScreen(context, '/Login');
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
              Color(0xFF00B894), // Verde esmeralda claro
              Color(0xFF00A085), // Verde esmeralda medio
              Color(0xFF2F4858), // Azul petróleo
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'Verificando sesión...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
