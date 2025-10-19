import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  AdminScreenState createState() => AdminScreenState();
}

class AdminScreenState extends State<AdminScreen> {
  List<dynamic> correos = [];
  List<String> correosSeleccionados = [];
  Map<String, bool> correosCheckbox = {};
  late String formattedStartDate;
  late String formattedEndDate;
  late int userId;
  final ApiService apiService = ApiService();

  DateTimeRange selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now()
        .add(const Duration(days: 7)), // Por ejemplo, una semana después
  );

  @override
  void initState() {
    super.initState();
    pedirCorreos(userInfo.sociedadId);
  }

  bool dateRangeSelected = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
      saveText: 'Seleccionar',
    );

    if (pickedRange != null) {
      setState(() {
        selectedDateRange = pickedRange;
        dateRangeSelected = true;
        loggerGlobal.d(
            selectedDateRange); // Se actualiza solo si se selecciona un rango
      });
    } else {
      loggerGlobal.d(selectedDateRange);
      dateRangeSelected =
          false; // Se actualiza si el diálogo se cierra sin seleccionar
    }
  }

  void _mostrarDialogoCorreos() {
    correosSeleccionados.clear();
    correosCheckbox = {for (var correo in correos) correo: false};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Usamos StatefulBuilder para crear estado propio en el diálogo.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Selecciona los correos'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width *
                      0.9, // 90% del ancho de la pantalla
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: correos.map((correo) {
                      return CheckboxListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              correo,
                              style: const TextStyle(
                                fontSize:
                                    14.0, // Ajusta el tamaño del texto si es necesario
                              ),
                            ),
                          ],
                        ),
                        value: correosCheckbox[correo],
                        onChanged: (bool? valor) {
                          // Actualiza el estado del diálogo
                          setStateDialog(() {
                            correosCheckbox[correo] = valor ?? false;
                          });
                          // Actualiza la lista de correos seleccionados
                          if (valor == true) {
                            correosSeleccionados.add(correo);
                          } else {
                            correosSeleccionados.remove(correo);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Aceptar'),
                  onPressed: () async {
                    _showProgressDialog(context);
                    bool success = await sendData(formattedStartDate,
                        formattedEndDate, userId, correosSeleccionados);
                    loggerGlobal.d(success);
                    if (success) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        _showSucces(context);
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        _showFail(context);
                      }
                    }
                    loggerGlobal.d(correosSeleccionados);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> sendData(
      String start, String end, int userId, List<dynamic> email) async {
    var url = Uri.parse('http://34.176.183.88:8181/parking_app/enviar_csv/');

    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        'formattedStartDate': start,
        'formattedEndDate': end,
        'id_cliente': userId.toString(),
        'email': email,
        'rut_cliente': userInfo.rut,
      }),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = json.decode(response.body);
      if (responseBody['status'] == 'success') {
        return true;
      } else if (responseBody['status'] == 'error') {
        return false;
      }
    }

    return false;
  }

  Future<void> pedirCorreos(int codigoCLiente) async {
    loggerGlobal.d('funcion llamada');
    try {
      final response = await apiService
          .post('pedir_correos/', {'cliente_id': codigoCLiente});
      loggerGlobal.d('Respuesta recibida: $response');

      if (response.containsKey('correos')) {
        setState(() {
          correos = List<String>.from(response['correos']);
        });
        loggerGlobal.d('Correos obtenidos: $correos');
      } else if (response.containsKey('status') &&
          response['status'] == 'error') {
        loggerGlobal.d('Error: ${response['message']}');
        // Aquí puedes manejar el error, por ejemplo, mostrando un mensaje al usuario
      } else {
        loggerGlobal.d('Respuesta inesperada: $response');
      }
    } catch (e) {
      loggerGlobal.d('Exception: $e');
      // Aquí puedes manejar la excepción, por ejemplo, mostrando un mensaje de error al usuario
    }
  }

  void _consultarCSV() async {
    _selectDate(context).then((_) async {
      if (dateRangeSelected) {
        formattedStartDate =
            DateFormat('yyyy-MM-dd').format(selectedDateRange.start);
        formattedEndDate =
            DateFormat('yyyy-MM-dd').format(selectedDateRange.end);
        userId = userInfo.sociedadId;

        _mostrarDialogoConfirmacion();

        // No hay correos, procede con la lógica para enviar datos
      }
    });
  }

  Future<void> _mostrarDialogoConfirmacion() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmación'),
          content: const Text('¿Desea enviarle el csv a otro usuario?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () async {
                _showProgressDialog(context);
                correos.clear();
                correos.add(userInfo.email);
                bool success = await sendData(
                    formattedStartDate, formattedEndDate, userId, correos);
                if (success) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    _showSucces(context);
                  }
                } else {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    _showFail(context);
                  }
                }
              },
            ),
            TextButton(
              child: const Text('Sí'),
              onPressed: () async {
                await pedirCorreos(userInfo.sociedadId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _mostrarDialogoCorreos();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future _showProgressDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false, // makes the dialog non-dismissible
      builder: (BuildContext context) {
        return Dialog(
          elevation: 5.0, // Adjust this value for desired shadow intensity
          backgroundColor:
              Colors.transparent, // Makes the dialog background transparent
          child: Container(
            width: MediaQuery.of(context).size.width *
                0.8, // Takes up to 80% of screen width
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              color: Colors.white, // Light green color for the dialog
              boxShadow: const [
                // Add custom box shadow
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0.0, 3.0),
                  blurRadius: 5.0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                      flex: 2,
                      child: Lottie.asset('assets/animations/request_code.json',
                          repeat: true, animate: true)),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      "ENVIANDO CSV...",
                      style: TextStyle(
                        fontWeight: FontWeight.bold, // Makes the font bold
                        fontSize:
                            18.0, // Adjust this value for desired font size
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSucces(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡Envío CSV exitoso!'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showFail(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡No se encontraron registros!'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
            'ADMINISTRACIÓN'),
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
            _buildButton('FIJAR MONTOS', _fijarMontos),
            _buildButton('CONSULTAR/BORRAR REGISTROS', _modificarRegistro),
            _buildButton('CONSULTAR CSV', _consultarCSV),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String title, VoidCallback onPressed) {
    return SizedBox(
      width: 200, // Ancho del botón
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

  void _fijarMontos() {
    navigateToScreen(context, '/FijarMonto');
    // Lógica para fijar montos
  }

  void _modificarRegistro() {
    navigateToScreen(context, '/ModificarRegistro');
  }
}
