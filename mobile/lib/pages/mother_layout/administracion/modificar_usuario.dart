import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class ModificarUsuario extends StatefulWidget {
  const ModificarUsuario({super.key});

  @override
  ModificarUsuarioState createState() => ModificarUsuarioState();
}

Logger logger = Logger();

class ModificarUsuarioState extends State<ModificarUsuario> {
  List<String> usuariosOn = [];
  List<String> usuariosOff = [];
  Map<String, dynamic> infoUsuarios = {};
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response =
          await _apiService.get('data_usuarios/${userInfo.clienteId}/');
      logger.d(response);

      setState(() {
        usuariosOn.clear();
        usuariosOff.clear();
        infoUsuarios.clear();
        if (response['usuarios'] != null) {
          for (var usuario in response['usuarios']) {
            String rut = usuario['rut'].toString();
            infoUsuarios[rut] = usuario;
            if (usuario['estado'] == 'ON') {
              usuariosOn.add(rut);
            } else {
              usuariosOff.add(rut);
            }
          }
        }
        logger.d('Usuarios ON: $usuariosOn');
        logger.d('Usuarios OFF: $usuariosOff');
      });
    } catch (e) {
      logger.e('Error al cargar usuarios: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _actualizarRegistro() async {
    final apiService = ApiService();

    try {
      var response = await apiService.post('modificar_usuarios/', {
        'rutsON': usuariosOn,
        'rutsOFF': usuariosOff,
      });
      loggerGlobal.d(response);
      _mostrarDialogoExito('Su estado fue modificado exitosamente');
    } catch (e) {
      logger.e("Error al modificar registros: $e");
      _mostrarDialogoError('Error al modificar el registro');
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

  void _cambiarEstadoUsuario(String rut, bool habilitar) {
    setState(() {
      if (habilitar) {
        usuariosOff.remove(rut);
        usuariosOn.add(rut);
        infoUsuarios[rut]['estado'] = 'ON';
      } else {
        usuariosOn.remove(rut);
        usuariosOff.add(rut);
        infoUsuarios[rut]['estado'] = 'OFF';
      }
    });
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
                _cargarUsuarios();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editarUsuario(String rut) async {
    String nombre = infoUsuarios[rut]['nombre'];
    String correo = infoUsuarios[rut]['correo'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                controller: TextEditingController(text: nombre),
                onChanged: (value) => nombre = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'RUT'),
                controller: TextEditingController(text: rut),
                onChanged: (value) => rut = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Correo'),
                controller: TextEditingController(text: correo),
                onChanged: (value) => correo = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Guardar'),
              onPressed: () => Navigator.of(context).pop({
                'nombre': nombre,
                'rut': rut,
                'correo': correo,
              }),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final response =
            await _apiService.put('modificar_usuario/$rut/', result);
        setState(() {
          infoUsuarios[rut] = response;
        });
        _mostrarDialogoExito('Usuario actualizado exitosamente');
      } catch (e) {
        logger.e("Error al actualizar usuario: $e");
        _mostrarDialogoError('Error al actualizar usuario');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'TRABAJADORES HABILITADOS',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: _buildUsuariosList(usuariosOn)),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'TRABAJADORES INHABILITADOS',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: _buildUsuariosList(usuariosOff)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 85, right: 4, left: 4, top: 10),
                  child: ElevatedButton(
                    onPressed: _actualizarRegistro,
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
                      "MODIFICAR ESTADO USUARIO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUsuariosList(List<String> listaRuts) {
    return ListView.builder(
      itemCount: listaRuts.length,
      itemBuilder: (context, index) {
        String rut = listaRuts[index];
        var usuario = infoUsuarios[rut];
        bool esHabilitado = usuario['estado'] == 'ON';
        return Card(
          child: ListTile(
            title: Text(usuario['nombre']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('RUT: $rut'),
                Text('Correo: ${usuario['correo']}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarUsuario(rut),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esHabilitado ? Colors.red : Colors.green,
                  ),
                  onPressed: () => _cambiarEstadoUsuario(rut, !esHabilitado),
                  child: Text(esHabilitado ? 'INHABILITAR' : 'HABILITAR'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
