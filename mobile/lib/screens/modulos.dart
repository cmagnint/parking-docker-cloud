import 'package:flutter/material.dart';
import 'package:parking/utils/globals.dart';

class ModuleScreen extends StatefulWidget {
  const ModuleScreen({super.key});

  @override
  ModuleScreenState createState() => ModuleScreenState();
}

class ModuleScreenState extends State<ModuleScreen> {
  String? selectedHolding;

  void administracionPressed() {
    navigateToScreen(context, '/Administracion');
    loggerGlobal.d('Mano de Obra pressed');
    // Add your logic for what should happen when this button is pressed
  }

  void superadministracionPressed() {
    navigateToScreen(context, '/SuperAdmin');
  }

  void vehiculoPressed() {
    navigateToScreen(context, '/Ingreso');
    // Add your logic for what should happen when this button is pressed
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 104, 138, 166),
            Color.fromARGB(255, 46, 52, 76),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'TERRASOFT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900, // Negrita
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 46, 52, 76),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (userInfo.superadmin)
                _buildElevatedButton(
                    context, 'SUPERADMIN', superadministracionPressed),
              const SizedBox(height: 150),
              if (userInfo.admin)
                _buildElevatedButton(
                    context, 'ADMINISTRACION', administracionPressed),
              const SizedBox(height: 150),
              _buildElevatedButton(
                  context, 'MOVIMIENTO VEHICULO', vehiculoPressed),
              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElevatedButton(
      BuildContext context, String title, VoidCallback onPressedFunction) {
    return ElevatedButton(
      onPressed: onPressedFunction,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white, // Color del texto e íconos
        side: const BorderSide(
            color: Colors.black, width: 2), // Contorno del botón
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Bordes redondeados
        ),
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        elevation: 5, // Sombra del botón
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold, // Texto en negrita
          color: Colors.black,
        ),
      ),
    );
  }
}
