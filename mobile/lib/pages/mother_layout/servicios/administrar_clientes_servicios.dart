import 'package:flutter/material.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class AdministrarClienteServicios extends StatefulWidget {
  const AdministrarClienteServicios({super.key});

  @override
  AdministrarClienteServiciosState createState() =>
      AdministrarClienteServiciosState();
}

class AdministrarClienteServiciosState
    extends State<AdministrarClienteServicios> {
  ApiService apiService = ApiService();
  List<Map<String, dynamic>> clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    try {
      final response = await apiService
          .get('clientes_servicios/?cliente_id=${userInfo.clienteId}');
      setState(() {
        clientes = List<Map<String, dynamic>>.from(response['data']);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los clientes: $e')),
        );
      }
    }
  }

  void _mostrarDialogoCliente({Map<String, dynamic>? cliente}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ClienteDialog(
          cliente: cliente,
          onSave: (nuevoCliente) async {
            if (cliente == null) {
              // Crear nuevo cliente
              await apiService.post('clientes_servicios/', nuevoCliente);
            } else {
              // Actualizar cliente existente
              await apiService.put(
                  'clientes_servicios/${cliente['id']}/', nuevoCliente);
            }
            _cargarClientes();
          },
          onDelete: cliente == null
              ? null
              : () async {
                  await apiService
                      .delete('clientes_servicios/${cliente['id']}/');
                  _cargarClientes();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Clientes')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: clientes.length,
              itemBuilder: (context, index) {
                final cliente = clientes[index];
                return ListTile(
                  title: Text(cliente['nombre']),
                  subtitle: Text('RUT: ${cliente['rut']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _mostrarDialogoCliente(cliente: cliente),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(bottom: 85.0, right: 4, left: 4, top: 10),
            child: ElevatedButton(
              onPressed: () => _mostrarDialogoCliente(),
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
                "CREAR CLIENTE",
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

class ClienteDialog extends StatefulWidget {
  final Map<String, dynamic>? cliente;
  final Function(Map<String, dynamic>) onSave;
  final Function()? onDelete;

  const ClienteDialog(
      {super.key, this.cliente, required this.onSave, this.onDelete});

  @override
  ClienteDialogState createState() => ClienteDialogState();
}

class ClienteDialogState extends State<ClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _rutController;
  late TextEditingController _celularController;
  late TextEditingController _correoController;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.cliente?['nombre'] ?? '');
    _rutController = TextEditingController(text: widget.cliente?['rut'] ?? '');
    _celularController =
        TextEditingController(text: widget.cliente?['celular'] ?? '');
    _correoController =
        TextEditingController(text: widget.cliente?['correo'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cliente == null ? 'Crear Cliente' : 'Editar Cliente'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    value!.isEmpty ? 'Por favor ingrese un nombre' : null,
              ),
              TextFormField(
                controller: _rutController,
                decoration: const InputDecoration(labelText: 'RUT'),
                validator: (value) =>
                    value!.isEmpty ? 'Por favor ingrese un RUT' : null,
              ),
              TextFormField(
                controller: _celularController,
                decoration: const InputDecoration(labelText: 'Celular'),
                validator: (value) => value!.isEmpty
                    ? 'Por favor ingrese un número de celular'
                    : null,
              ),
              TextFormField(
                controller: _correoController,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (value) =>
                    value!.isEmpty ? 'Por favor ingrese un correo' : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.onDelete != null)
          TextButton(
            onPressed: widget.onDelete,
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Guardar'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'nombre': _nombreController.text,
                'rut': _rutController.text,
                'celular': _celularController.text,
                'correo': _correoController.text,
                'cliente': userInfo.clienteId,
              });
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _celularController.dispose();
    _correoController.dispose();
    super.dispose();
  }
}
