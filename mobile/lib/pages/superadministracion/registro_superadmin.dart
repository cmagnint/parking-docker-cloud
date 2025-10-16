import 'package:flutter/material.dart';
import 'package:parking/services/parking_service.dart';
import 'package:intl/intl.dart';
import 'package:parking/utils/globals.dart';

class SuperRegistro extends StatefulWidget {
  const SuperRegistro({super.key});

  @override
  SuperRegistroState createState() => SuperRegistroState();
}

class SuperRegistroState extends State<SuperRegistro> {
  DateTime? fechaSeleccionada;
  List<dynamic> registros = [];
  List<int> idsParaEliminar = [];
  String mensajeSinRegistros = '';
  Map<String, dynamic> registrosPorHolding = {};
  List<String> nombresHoldings = [];
  bool isLoading = true;
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    String fechaFormateada = fechaSeleccionada != null
        ? DateFormat('dd/MM/yyyy').format(fechaSeleccionada!)
        : 'No seleccionada';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              navigateToScreen(context, '/SuperAdmin'), // Volver atrás
        ),
        title: const Text(
            style: TextStyle(fontWeight: FontWeight.w900),
            'MODIFICAR REGISTRO'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              height: 40,
            ),
            ElevatedButton(
              onPressed: () => _seleccionarFecha(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white, // Color del texto e íconos
                side: const BorderSide(
                    color: Colors.black, width: 2), // Contorno del botón
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Bordes redondeados
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                elevation: 5, // Sombra del botón
              ),
              child: const Text(
                'SELECCIONAR FECHA',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Texto en negrita
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fechaFormateada,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _enviarFecha(),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white, // Color del texto e íconos
                side: const BorderSide(
                    color: Colors.black, width: 2), // Contorno del botón
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Bordes redondeados
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                elevation: 5, // Sombra del botón
              ),
              child: const Text(
                'CONSULTAR FECHA',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Texto en negrita
                  color: Colors.black,
                ),
              ),
            ),
            if (registrosPorHolding.isEmpty && mensajeSinRegistros.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    mensajeSinRegistros,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Expanded(
                child: registrosPorHolding.isNotEmpty
                    ? Column(
                        children: [
                          ListTile(
                            title: const Text('NOMBRE DEL HOLDING',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            tileColor: Colors.grey[
                                300], // Color de fondo para la fila del título
                          ),
                          const Divider(), // Línea divisoria
                          Expanded(
                            child: ListView.builder(
                              itemCount: registrosPorHolding.keys.length,
                              itemBuilder: (context, index) {
                                String holding =
                                    registrosPorHolding.keys.elementAt(index);
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Text(holding),
                                      onTap: () =>
                                          _mostrarRegistrosPorHolding(holding),
                                    ),
                                    const Divider(), // Línea divisoria entre cada fila
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          mensajeSinRegistros,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarRegistrosPorHolding(String holdingSeleccionado) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      int totalRegistros =
          registrosPorHolding[holdingSeleccionado]['total_dia'];

      return Scaffold(
        appBar: AppBar(
          title: Text('Registros de $holdingSeleccionado'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: registrosPorHolding[holdingSeleccionado]['registros']
                    .length,
                itemBuilder: (context, index) {
                  var registro = registrosPorHolding[holdingSeleccionado]
                      ['registros'][index];
                  return Card(
                    child: ListTile(
                      title: Text('Patente: ${registro['patente']}'),
                      subtitle: Text(
                        'Hora Inicio: ${registro['hora_inicio']}\n'
                        'Hora Término: ${registro['hora_termino'] ?? 'No disponible'}\n'
                        'Total: ${registro['total'] ?? 'No disponible'}\n'
                        'RUT Trabajador: ${registro['rut_trabajador']}',
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Total del Día: $totalRegistros',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }));
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
    );

    if (fechaElegida != null && fechaElegida != fechaSeleccionada) {
      setState(() {
        fechaSeleccionada = fechaElegida;
      });
    }
  }

  Future<void> _enviarFecha() async {
    if (fechaSeleccionada == null) {
      _mostrarDialogoError('Por favor, seleccione una fecha');
      return;
    }

    var formatoFecha = DateFormat('dd/MM/yyyy');
    var fechaFormateada = formatoFecha.format(fechaSeleccionada!);

    try {
      var responseData = await apiService.post('registro_por_fecha_admin/', {
        'fecha': fechaFormateada,
      });

      if (responseData['status'] == 'success') {
        setState(() {
          registrosPorHolding = responseData['registros_por_holding'];
          nombresHoldings = registrosPorHolding.keys.toList();
          // Si la lista de registros está vacía, establece el mensaje
          mensajeSinRegistros = registros.isEmpty
              ? "No fue encontrado registro para esta fecha"
              : "";
        });
      } else {
        _mostrarDialogoError('Error al obtener los registros');
      }
    } catch (e) {
      loggerGlobal.e('Error al enviar fecha: $e');
      _mostrarDialogoError('Error al obtener los registros: ${e.toString()}');
    }
  }

  void _mostrarDialogoError(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(mensaje),
          actions: <Widget>[
            TextButton(
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
