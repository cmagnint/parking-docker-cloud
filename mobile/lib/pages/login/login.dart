import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:lottie/lottie.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController rutController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool obscureText = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  Logger logger = Logger();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Focus nodes
  final FocusNode _rutFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _slideController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rutFocus.dispose();
    _passwordFocus.dispose();
    rutController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Helper function para extraer RUT sin formato
  String _getRutWithoutFormat(String formattedRut) {
    return formattedRut.replaceAll(RegExp(r'[^0-9Kk]'), '');
  }

  // Validation functions
  String? _validateRut(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su RUT';
    }
    if (value.length < 7) {
      return 'RUT debe tener al menos 7 caracteres';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }
    if (value.length < 3) {
      return 'Contraseña debe tener al menos 3 caracteres';
    }
    return null;
  }

  // Modern input field widget
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    VoidCallback? onFieldSubmitted,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        obscureText: isPassword ? obscureText : false,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            size: 24,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: () {
                    setState(() {
                      obscureText = !obscureText;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        inputFormatters: !isPassword
            ? [
                RutInputFormatter(),
              ]
            : null,
        onFieldSubmitted: (_) => onFieldSubmitted?.call(),
      ),
    );
  }

  // Modern button widget
  Widget _buildModernButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isPrimary = true,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.transparent,
          foregroundColor: isPrimary
              ? const Color(0xFF2F4858) // Azul petróleo
              : Colors.white,
          elevation: isPrimary ? 8 : 0,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2F4858)), // Azul petróleo
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Future<void> loginButtonPressed(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    userInfo.rut = _getRutWithoutFormat(rutController.text);
    userInfo.password = passwordController.text;

    try {
      if ((userInfo.password.isNotEmpty) && (userInfo.rut.isNotEmpty)) {
        var responseData = await apiService.post(
            'login/',
            {
              'rut': _getRutWithoutFormat(rutController.text),
              'password': passwordController.text,
            },
            requiresAuth: false); // Sin autenticación

        logger.d(responseData);

        if (responseData['status'] == 'success') {
          await tokenStorage.write(
              key: 'authToken', value: responseData['token']);

          userInfo.admin = responseData['admin'] ?? false;
          userInfo.clienteId = responseData['cliente_id'] ?? 0;
          userInfo.email = responseData['correo'] ?? '';
          userInfo.superadmin = responseData['superadmin'] ?? false;
          userInfo.name = responseData['name'] ?? '';
          userInfo.rut = responseData['rut'] ?? '';

          // Cargar parámetros adicionales si están disponibles
          userInfo.valorParametro = responseData['valor_parametro'] ?? 0;
          userInfo.tiempoParametro = responseData['intervalo_parametro'] ?? 0;
          userInfo.montoMinimo = responseData['monto_minimo'] ?? 0;
          userInfo.tiempoMinimo = responseData['intervalo_minimo'] ?? 0;

          if (context.mounted) {
            setState(() {
              _isLoading = false;
            });
            _showSuccessAnimation();
            await Future.delayed(const Duration(milliseconds: 1500));
            navigateToScreen(context, '/Mother_Layout');
          }
        } else {
          if (context.mounted) {
            setState(() {
              _isLoading = false;
            });
            _showErrorDialog(context, 'Usuario o contraseña incorrectos');
          }
        }
      }
    } on TimeoutException {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(context,
            'La conexión ha tardado demasiado, favor intente nuevamente.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      loggerGlobal.d(e);

      if (context.mounted) {
        String errorMessage = 'Error de conexión';

        // Extraer el mensaje del JSON si existe
        String errorString = e.toString();
        if (errorString.contains('"message":"')) {
          try {
            int startIndex = errorString.indexOf('"message":"') + 11;
            int endIndex = errorString.indexOf('"', startIndex);
            errorMessage = errorString.substring(startIndex, endIndex);
          } catch (parseError) {
            errorMessage = 'Usuario o contraseña incorrectos';
          }
        }

        _showErrorDialog(context, errorMessage);
      }
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/loading.json',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Bienvenido!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F4858), // Azul petróleo
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // Password recovery functions using updated API
  Future<bool> generarCodigo(String rut) async {
    try {
      final response = await apiService.post(
          'generar_codigo/',
          {
            'rut': rut,
          },
          requiresAuth: false); // Sin autenticación

      if (response['status'] == 'success') {
        return true;
      } else if (response['status'] == 'error') {
        return false;
      }
      return false;
    } catch (exception) {
      return false;
    }
  }

  Future<bool> verificarCodigo(String rut, String codigo) async {
    try {
      final response = await apiService.post(
          'verificar_codigo/',
          {
            'rut': rut,
            'codigo': codigo,
          },
          requiresAuth: false); // Sin autenticación

      if (response['status'] == 'success') {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendCodePressed(BuildContext context) async {
    // ✅ MODIFICACIÓN: Limpiar el formato del RUT antes de enviarlo
    final String rut = _getRutWithoutFormat(rutController.text);

    if (rut.isEmpty) {
      _showErrorDialog(context, 'Por favor ingrese su RUT');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    userInfo.rut = rut; // Ya está limpio
    globalState.hasResponse = false;
    bool isSuccessful = await generarCodigo(rut);

    setState(() {
      _isLoading = false;
    });

    if (isSuccessful && context.mounted) {
      _showEmailSentDialog(context);
    } else {
      if (context.mounted) {
        _showEmailNotSentDialog(context);
      }
    }
  }

  Future<void> _showEmailSentDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/email_send.json',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Código enviado!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hemos enviado un código de verificación a tu correo. Revisa también la carpeta de spam.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showRecoveryDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A085), // Verde esmeralda
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEmailNotSentDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/invalid.json',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Error!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El correo no fue enviado.\nRUT inválido.\nPor favor intente nuevamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2F4858), // Azul petróleo para error
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecoveryDialog() {
    int intentos = 3;
    String mensajeError = "";
    final TextEditingController codigoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Ingrese el código recibido'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codigoController,
                    decoration: InputDecoration(
                      labelText: 'Código',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (mensajeError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        mensajeError,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // userInfo.rut ya está limpio desde sendCodePressed
                    String rut = userInfo.rut;
                    final String codigo = codigoController.text;

                    final bool esCorrecto = await verificarCodigo(rut, codigo);

                    if (esCorrecto && context.mounted) {
                      Navigator.of(context).pop();
                      navigateToScreen(context, '/ChangePassScreen');
                    } else {
                      intentos--;
                      if (intentos <= 0 && context.mounted) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          mensajeError =
                              "Código incorrecto, te quedan $intentos intentos.";
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894), // Verde esmeralda
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Validar Código',
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
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo y título
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF00B894)
                                        .withOpacity(0.3), // Verde esmeralda
                                    const Color(0xFF2F4858)
                                        .withOpacity(0.2), // Azul petróleo
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_parking,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '¡Bienvenido!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'TERRAPARKING',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Campos de entrada
                            _buildModernTextField(
                              controller: rutController,
                              label: 'RUT (sin puntos ni guión)',
                              icon: Icons.person,
                              validator: _validateRut,
                              focusNode: _rutFocus,
                              onFieldSubmitted: () {
                                FocusScope.of(context)
                                    .requestFocus(_passwordFocus);
                              },
                            ),

                            _buildModernTextField(
                              controller: passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock,
                              isPassword: true,
                              validator: _validatePassword,
                              focusNode: _passwordFocus,
                              onFieldSubmitted: () =>
                                  loginButtonPressed(context),
                            ),

                            // Remember me checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  fillColor: WidgetStateProperty.all(
                                    const Color(0xFF00B894), // Verde esmeralda
                                  ),
                                  checkColor: Colors.white,
                                ),
                                Text(
                                  'Recordarme',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Botones
                            _buildModernButton(
                              text: 'INICIAR SESIÓN',
                              onPressed: () => loginButtonPressed(context),
                              isLoading: _isLoading,
                            ),

                            const SizedBox(height: 16),

                            _buildModernButton(
                              text: '¿Olvidó su contraseña?',
                              onPressed: () => sendCodePressed(context),
                              isPrimary: false,
                            ),

                            const SizedBox(height: 32),

                            // Footer
                            Divider(
                              color: Colors.white.withOpacity(0.3),
                              thickness: 1,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'by ®Terrasoft',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'V 1.2.5',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class RutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Remover todo excepto dígitos y K
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9Kk]'), '');

    // Convertir K a mayúscula
    digitsOnly = digitsOnly.toUpperCase();

    // Limitar a máximo 9 caracteres (8 dígitos + 1 dígito verificador)
    if (digitsOnly.length > 9) {
      digitsOnly = digitsOnly.substring(0, 9);
    }

    // Si no hay contenido, devolver vacío
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    String formatted = '';

    if (digitsOnly.length <= 1) {
      // Solo 1 dígito
      formatted = digitsOnly;
    } else if (digitsOnly.length <= 4) {
      // Hasta 4 dígitos: X.XXX
      if (digitsOnly.length > 1) {
        formatted = digitsOnly.substring(0, digitsOnly.length - 1);
        if (formatted.length > 1) {
          formatted =
              '${formatted.substring(0, formatted.length - 3 < 0 ? 0 : formatted.length - 3)}.${formatted.substring(formatted.length - 3 < 0 ? 0 : formatted.length - 3)}';
        }
        formatted += '-${digitsOnly.substring(digitsOnly.length - 1)}';
      } else {
        formatted = digitsOnly;
      }
    } else if (digitsOnly.length <= 7) {
      // 5-7 dígitos: XX.XXX-X
      String body = digitsOnly.substring(0, digitsOnly.length - 1);
      String dv = digitsOnly.substring(digitsOnly.length - 1);

      if (body.length <= 2) {
        formatted = '$body-$dv';
      } else {
        String firstPart = body.substring(0, body.length - 3);
        String secondPart = body.substring(body.length - 3);
        formatted = '$firstPart.$secondPart-$dv';
      }
    } else {
      // 8-9 dígitos: XX.XXX.XXX-X
      String body = digitsOnly.substring(0, digitsOnly.length - 1);
      String dv = digitsOnly.substring(digitsOnly.length - 1);

      if (body.length <= 3) {
        formatted = '$body-$dv';
      } else if (body.length <= 6) {
        String firstPart = body.substring(0, body.length - 3);
        String secondPart = body.substring(body.length - 3);
        formatted = '$firstPart.$secondPart-$dv';
      } else {
        String firstPart = body.substring(0, body.length - 6);
        String secondPart = body.substring(body.length - 6, body.length - 3);
        String thirdPart = body.substring(body.length - 3);
        formatted = '$firstPart.$secondPart.$thirdPart-$dv';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
