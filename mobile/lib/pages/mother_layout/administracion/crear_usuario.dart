import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class CrearUsuario extends StatefulWidget {
  const CrearUsuario({super.key});

  @override
  CrearUsuarioState createState() => CrearUsuarioState();
}

Logger logger = Logger();

class CrearUsuarioState extends State<CrearUsuario> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  ApiService apiService = ApiService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Usuario'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            _buildTextField(
              'Nombre',
              _nombreController,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              'RUT',
              _rutController,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              'Correo',
              _correoController,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 0.0, right: 4, left: 4, top: 10),
              child: ElevatedButton(
                onPressed: () {
                  _crearUsuario();
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
                  backgroundColor: const Color.fromARGB(255, 6, 62, 107),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "CREAR USUARIO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _crearUsuario() async {
    try {
      final response = await apiService.post('create_user/', {
        'nombre': _nombreController.text,
        'rut': _rutController.text,
        'correo': _correoController.text,
        'cliente': userInfo.clienteId,
        'estado': 'ON',
      });

      if (response['status'] == 'success') {
        _mostrarDialogo('Éxito', 'Usuario creado exitosamente');
      } else {
        _mostrarDialogo('Error', response['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      logger.e('Error al crear usuario: $e');
      _mostrarDialogo('Error',
          'Ocurrió un error al crear el usuario. Por favor, inténtalo de nuevo.');
    }
  }

  void _mostrarDialogo(String titulo, String mensaje) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensaje),
          actions: <Widget>[
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                navigateToScreen(context, '/Mother_Layout');
              },
            ),
          ],
        );
      },
    );
  }
}
