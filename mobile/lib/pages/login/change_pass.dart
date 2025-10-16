import 'package:flutter/material.dart';
import 'package:parking/utils/globals.dart';
import 'package:parking/services/parking_service.dart';

import 'package:lottie/lottie.dart';

class ChangePassScreen extends StatefulWidget {
  const ChangePassScreen({super.key});

  @override
  ChangePassScreenState createState() => ChangePassScreenState();
}

class ChangePassScreenState extends State<ChangePassScreen> {
  bool obscureText = true;
  ApiService apiService = ApiService();
  final TextEditingController newPass = TextEditingController();

  Future<void> cambiarContrasena(String rut, String nuevaContrasena) async {
    try {
      var response = await apiService.post(
          'cambiar_contrasena/',
          {
            'rut': rut,
            'nuevaContrasena': nuevaContrasena,
          },
          requiresAuth: false); // Sin autenticación

      if (response['status'] == 'success') {
        _showSuccessDialog(); // Mostrar el dialog cuando sea success
        return;
      } else {
        // Manejar error si es necesario
        _showErrorDialog(response['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      _showErrorDialog('Error al cambiar la contraseña: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Evita que el dialogo se cierre tocando fuera de su área
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animations/change_pass.json',
                  width: 150, height: 150), // Ajusta el tamaño según necesites
              const SizedBox(height: 20),
              const Text("¡Cambio de contraseña exitoso!")
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cerrar"),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el dialog
                Navigator.of(context)
                    .pushReplacementNamed('/Login'); // Redirigir al LoginScreen
              },
            ),
          ],
        );
      },
    );
  }

  final String globalrut = userInfo.rut;
  final String globalpass = userInfo.password;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 104, 138, 166),
            Color.fromARGB(255, 128, 226, 131),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  const Icon(
                    Icons.password_outlined,
                    size: 100,
                  ),
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      const SizedBox(width: 21),
                      Container(
                        padding: const EdgeInsets.all(
                            10), // Spacing inside the frame
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color.fromARGB(104, 4, 17, 28),
                            width: 4.0,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: '¡Bienvenido ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: userInfo.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              const TextSpan(
                                text: '!\n Su rut es: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: globalrut,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    '\n Esta pestaña es para cambiar la contraseña \n Ingrese una nueva contraseña mayor a 6 digitos ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextField(
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      controller: newPass,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                obscureText = !obscureText;
                              });
                            },
                            child: Icon(
                              obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                          hintText: 'NUEVA CONTRASEÑA',
                          hintStyle: const TextStyle(
                              letterSpacing: 3,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          fillColor: Colors.white,
                          filled: true),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(thickness: 0.9, color: Colors.blueGrey[700]),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: ElevatedButton(
                      onPressed: () {
                        cambiarContrasena(userInfo.rut, newPass.text);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 25),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "INGRESAR",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 25),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "CERRAR",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                              thickness: 0.5, color: Colors.blueGrey[700]),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'by ®Terrasoft',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Lottie.asset('assets/animations/change_pass_screen.json',
                      width: 150, height: 150),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
