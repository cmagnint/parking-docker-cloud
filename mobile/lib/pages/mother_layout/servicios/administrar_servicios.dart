import 'package:flutter/material.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class AdministrarServicioPage extends StatefulWidget {
  const AdministrarServicioPage({super.key});

  @override
  AdministrarServicioPageState createState() => AdministrarServicioPageState();
}

class AdministrarServicioPageState extends State<AdministrarServicioPage> {
  ApiService apiService = ApiService();
  List<Map<String, dynamic>> servicios = [];

  @override
  void initState() {
    super.initState();
    _cargarServicios();
  }

  Future<void> _cargarServicios() async {
    try {
      final response =
          await apiService.get('servicios/?cliente_id=${userInfo.clienteId}');
      setState(() {
        servicios = List<Map<String, dynamic>>.from(response['data']);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los servicios: $e')),
        );
      }
    }
  }

  void _mostrarDialogoServicio({Map<String, dynamic>? servicio}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ServicioDialog(
          servicio: servicio,
          onSave: (nuevoServicio) async {
            if (servicio == null) {
              // Crear nuevo servicio
              await apiService.post('servicios/', nuevoServicio);
            } else {
              // Actualizar servicio existente
              await apiService.put(
                  'servicios/${servicio['id']}/', nuevoServicio);
            }
            _cargarServicios();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Servicios')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: servicios.length,
              itemBuilder: (context, index) {
                final servicio = servicios[index];
                return ListTile(
                  title: Text(servicio['nombre_servicio']),
                  subtitle: Text(
                      'Valor: \$${servicio['valor_servicio']} - Duración: ${servicio['duracion_servicio']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _mostrarDialogoServicio(servicio: servicio),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(bottom: 85.0, right: 4, left: 4, top: 10),
            child: ElevatedButton(
              onPressed: () => _mostrarDialogoServicio(),
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
                "CREAR SERVICIO",
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
}

class ServicioDialog extends StatefulWidget {
  final Map<String, dynamic>? servicio;
  final Function(Map<String, dynamic>) onSave;

  const ServicioDialog({super.key, this.servicio, required this.onSave});

  @override
  ServicioDialogState createState() => ServicioDialogState();
}

class ServicioDialogState extends State<ServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _nombreServicio;
  late int _valorServicio;
  late Duration _duracionServicio;

  @override
  void initState() {
    super.initState();
    _nombreServicio = widget.servicio?['nombre_servicio'] ?? '';
    _valorServicio = widget.servicio?['valor_servicio'] ?? 0;
    _duracionServicio =
        _parseDuracion(widget.servicio?['duracion_servicio'] ?? '00:00:00');
  }

  Duration _parseDuracion(String duracion) {
    final partes = duracion.split(':');
    return Duration(
      hours: int.parse(partes[0]),
      minutes: int.parse(partes[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.servicio == null ? 'Crear Servicio' : 'Editar Servicio'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              initialValue: _nombreServicio,
              decoration:
                  const InputDecoration(labelText: 'Nombre del Servicio'),
              validator: (value) =>
                  value!.isEmpty ? 'Por favor ingrese un nombre' : null,
              onSaved: (value) => _nombreServicio = value!,
            ),
            TextFormField(
              initialValue: _valorServicio.toString(),
              decoration:
                  const InputDecoration(labelText: 'Valor del Servicio'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value!.isEmpty ? 'Por favor ingrese un valor' : null,
              onSaved: (value) => _valorServicio = int.parse(value!),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _duracionServicio.inHours.toString(),
                    decoration: const InputDecoration(labelText: 'Horas'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _duracionServicio = Duration(
                          hours: int.tryParse(value) ?? 0,
                          minutes: _duracionServicio.inMinutes % 60,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: (_duracionServicio.inMinutes % 60).toString(),
                    decoration: const InputDecoration(labelText: 'Minutos'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _duracionServicio = Duration(
                          hours: _duracionServicio.inHours,
                          minutes: int.tryParse(value) ?? 0,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Guardar'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              widget.onSave({
                'nombre_servicio': _nombreServicio,
                'valor_servicio': _valorServicio,
                'duracion_servicio':
                    '${_duracionServicio.inHours.toString().padLeft(2, '0')}:${(_duracionServicio.inMinutes % 60).toString().padLeft(2, '0')}:00',
                'cliente': userInfo.clienteId,
              });
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}
