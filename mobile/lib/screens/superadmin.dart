import 'package:flutter/material.dart';
import 'package:parking/utils/globals.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  SuperAdminScreenState createState() => SuperAdminScreenState();
}

class SuperAdminScreenState extends State<SuperAdminScreen> {
  List<dynamic> correos = [];
  List<String> correosSeleccionados = [];
  Map<String, bool> correosCheckbox = {};
  late String formattedStartDate;
  late String formattedEndDate;
  late int userId;
  DateTimeRange selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now()
        .add(const Duration(days: 7)), // Por ejemplo, una semana después
  );

  @override
  void initState() {
    super.initState();
  }

  bool dateRangeSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
            'SUPERADMIN'),
        backgroundColor: const Color.fromARGB(255, 46, 52, 76),
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              navigateToScreen(context, '/Modulos'), // Volver atrás
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 80, 171, 215),
      body: Center(
        child: Wrap(
          spacing: 20, // Espacio horizontal entre los botones
          runSpacing: 20, // Espacio vertical entre los botones
          alignment: WrapAlignment.center,
          children: <Widget>[
            _buildButton('CREAR CLIENTE', _crearCliente),
            _buildButton('CONSULTAR REGISTROS', _modificarRegistro),
            _buildButton('ENVIAR CSV', _crearCSV),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String title, VoidCallback onPressed) {
    return SizedBox(
      width: 300, // Ancho del botón
      height: 100, // Altura del botón
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color.fromARGB(255, 46, 52, 76), // Color del botón
          shape: RoundedRectangleBorder(
            // Forma cuadrada
            borderRadius: BorderRadius.circular(0),
          ),
        ),
        child: Text(
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900),
            title),
      ),
    );
  }

  void _modificarRegistro() {
    navigateToScreen(context, '/SuperRegistro');
  }

  void _crearCliente() {
    navigateToScreen(context, '/CrearCliente');
  }

  void _crearCSV() {}
}
