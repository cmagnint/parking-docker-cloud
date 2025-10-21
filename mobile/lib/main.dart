import 'package:flutter/material.dart';
import 'package:parking/pages/login/login.dart';
import 'package:parking/pages/mother_layout/mother_layout.dart';
import 'package:parking/pages/mother_layout/estacionamiento/historial.dart';
import 'package:parking/pages/mother_layout/estacionamiento/ingreso.dart';
import 'package:parking/pages/login/change_pass.dart';
import 'package:parking/pages/mother_layout/administracion/parametros.dart';
import 'package:parking/pages/mother_layout/administracion/historial_registro.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:parking/pages/superadministracion/registro_superadmin.dart';
import 'package:parking/pages/superadministracion/administrar_cliente.dart';
import 'package:parking/pages/login/token_check_screen.dart';
import 'package:parking/services/printer_background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrinterBackgroundService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking App',
      initialRoute:
          '/TokenCheck', // Cambio: siempre ir primero a verificar token
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español de España
        Locale('es', ''), // Español genérico
      ],
      routes: {
        '/TokenCheck': (context) => const TokenCheckScreen(), // Nueva ruta
        '/Login': (context) => const LoginScreen(),
        '/Mother_Layout': (context) => const MotherLayout(),
        '/Ingreso': (context) => const RegistroVehiculoScreen(),
        '/Historial': (context) => const HistorialScreen(),
        '/ChangePassScreen': (context) => const ChangePassScreen(),
        '/FijarMonto': (context) => const ParametrosScreen(),
        '/ModificarRegistro': (context) => const HistorialRegistros(),
        '/SuperRegistro': (context) => const SuperRegistro(),
        '/CrearCliente': (context) => const AdministrarCliente(),
      },
    );
  }
}
