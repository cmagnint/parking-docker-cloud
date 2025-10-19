import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class ModificarRegistro extends StatefulWidget {
  const ModificarRegistro({super.key});

  @override
  ModificarRegistroState createState() => ModificarRegistroState();
}

class ModificarRegistroState extends State<ModificarRegistro> {
  DateTime? fechaSeleccionada;
  List<dynamic> registros = [];
  Set<int> idsParaEliminar = {};
  String mensajeSinRegistros = '';
  ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    String fechaFormateada = fechaSeleccionada != null
        ? DateFormat('dd/MM/yyyy').format(fechaSeleccionada!)
        : 'No seleccionada';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _seleccionarFecha(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                elevation: 5,
              ),
              child: const Text(
                'SELECCIONAR FECHA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
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
              onPressed: _enviarFecha,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                elevation: 5,
              ),
              child: const Text(
                'CONSULTAR FECHA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            if (registros.isEmpty && mensajeSinRegistros.isNotEmpty)
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
                child: ListView.builder(
                  itemCount: registros.length,
                  itemBuilder: (context, index) {
                    var registro = registros[index];
                    bool isSelected = idsParaEliminar.contains(registro['id']);
                    return Card(
                      color: isSelected ? Colors.red[100] : null,
                      child: ListTile(
                        title: Text('Patente: ${registro['patente']}'),
                        subtitle: Text(
                            'Hora Inicio: ${registro['hora_inicio']}\n'
                            'Hora Término: ${registro['hora_termino'] ?? 'No disponible'}\n'
                            'Cancelado (CLP): ${registro['cancelado'] ?? 'No disponible'} \n'
                            'Saldo (CLP): ${registro['saldo'] ?? 'No disponible'} \n'
                            'RUT Usuario Registrador: ${registro['usuario_registrador']}'),
                        trailing: IconButton(
                          icon: Icon(isSelected ? Icons.undo : Icons.delete),
                          onPressed: () {
                            setState(() {
                              if (isSelected) {
                                idsParaEliminar.remove(registro['id']);
                              } else {
                                idsParaEliminar.add(registro['id']);
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (registros.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                    bottom: 85, right: 4, left: 4, top: 10),
                child: ElevatedButton(
                  onPressed:
                      idsParaEliminar.isNotEmpty ? _modificarRegistro : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 25),
                    backgroundColor: const Color.fromARGB(255, 6, 62, 107),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    "BORRAR REGISTROS SELECCIONADOS",
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

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
      var response = await apiService.post('registro_por_fecha/', {
        'fecha': fechaFormateada,
        'id_boss': userInfo.sociedadId,
      });
      loggerGlobal.d(response);
      if (response['status'] == 'success') {
        setState(() {
          registros = response['registros'];
          mensajeSinRegistros = registros.isEmpty
              ? "No fue encontrado registro para esta fecha"
              : "";
          idsParaEliminar.clear();
        });
      } else {
        _mostrarDialogoError('Error al obtener los registros');
      }
    } catch (e) {
      loggerGlobal.e('Error al enviar fecha: $e');
      _mostrarDialogoError('Error al obtener los registros: ${e.toString()}');
    }
  }

  Future<void> _modificarRegistro() async {
    try {
      var response = await apiService.post('borrar_registros/', {
        'ids': idsParaEliminar.toList(),
      });

      if (response['status'] == 'success') {
        setState(() {
          registros.removeWhere(
              (registro) => idsParaEliminar.contains(registro['id']));
          idsParaEliminar.clear();
        });
        _mostrarDialogoExito('Registros eliminados con éxito');
      } else {
        _mostrarDialogoError('Error al eliminar los registros');
      }
    } catch (e) {
      loggerGlobal.e('Error al modificar registro: $e');
      _mostrarDialogoError('Error al eliminar los registros: ${e.toString()}');
    }
  }

  void _mostrarDialogoExito(String mensaje) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Éxito'),
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
