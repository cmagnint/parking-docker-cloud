import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parking/services/parking_service.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  ClientesScreenState createState() => ClientesScreenState();
}

class ClientesScreenState extends State<ClientesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _clientes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClientes();
  }

  Future<void> _fetchClientes() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('clientes/');
      setState(() => _clientes = response['data']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createCliente() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => const _ClienteDialog(),
    );

    if (result != null) {
      try {
        await _apiService.post('clientes/', result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente creado con éxito')),
          );
        }
        _fetchClientes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear cliente: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateCliente(dynamic cliente) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => _ClienteDialog(cliente: cliente),
    );

    if (result != null) {
      try {
        await _apiService.put('clientes/${cliente['id']}/', result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente actualizado con éxito')),
          );
        }
        _fetchClientes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar cliente: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCliente(int id) async {
    try {
      await _apiService.delete('clientes/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente eliminado con éxito')),
        );
      }
      _fetchClientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar cliente: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Clientes')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _clientes.length,
                    itemBuilder: (context, index) {
                      final cliente = _clientes[index];
                      return ListTile(
                        title: Text(cliente['nombre_cliente']),
                        subtitle: Text(cliente['rut_cliente']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _updateCliente(cliente),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteCliente(cliente['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(
                bottom: 85.0, right: 16, left: 16, top: 10),
            child: ElevatedButton(
              onPressed: _createCliente,
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

class RutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    String formattedText = '';

    for (int i = 0; i < text.length; i++) {
      if (i == text.length - 1) {
        formattedText += '-${text[i]}';
      } else if ((text.length - i) % 3 == 0 && i != 0) {
        formattedText += '.${text[i]}';
      } else {
        formattedText += text[i];
      }
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class _ClienteDialog extends StatefulWidget {
  final Map<String, dynamic>? cliente;

  const _ClienteDialog({this.cliente});

  @override
  __ClienteDialogState createState() => __ClienteDialogState();
}

class __ClienteDialogState extends State<_ClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rutController;
  late TextEditingController _nombreController;
  late TextEditingController _patenteController;
  late TextEditingController _valorController;
  late String _tipo;
  late String _modoPago;
  late bool _registrar;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    _rutController = TextEditingController(text: cliente?['rut_cliente'] ?? '');
    _nombreController =
        TextEditingController(text: cliente?['nombre_cliente'] ?? '');
    _patenteController =
        TextEditingController(text: cliente?['patente_cliente'] ?? '');
    _valorController =
        TextEditingController(text: cliente?['valor']?.toString() ?? '');
    _tipo = cliente?['tipo'] ?? 'DIARIA';
    _modoPago = cliente?['modo_pago'] ?? '';
    _registrar = cliente?['registrar'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.cliente == null ? 'Crear Cliente' : 'Editar Cliente',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: _rutController,
                        decoration: const InputDecoration(labelText: 'RUT'),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.-]')),
                          RutInputFormatter(),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese el RUT';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese el nombre';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _patenteController,
                        decoration: const InputDecoration(labelText: 'Patente'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese la patente';
                          }
                          return null;
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: _tipo,
                        decoration:
                            const InputDecoration(labelText: 'Tipo de Tarifa'),
                        items: ['DIARIA', 'SEMANAL', 'MENSUAL']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _tipo = newValue!;
                          });
                        },
                      ),
                      TextFormField(
                        controller: _valorController,
                        decoration: const InputDecoration(labelText: 'Valor'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese el valor';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        initialValue: _modoPago,
                        decoration:
                            const InputDecoration(labelText: 'Modo de Pago'),
                        onChanged: (value) {
                          _modoPago = value;
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Registrar Entrada y Salida'),
                        value: _registrar,
                        onChanged: (bool? value) {
                          setState(() {
                            _registrar = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Guardar'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final rutSinFormato =
                          _rutController.text.replaceAll(RegExp(r'[^\d]'), '');
                      Navigator.of(context).pop({
                        'rut_cliente': rutSinFormato,
                        'nombre_cliente': _nombreController.text,
                        'patente_cliente': _patenteController.text,
                        'tipo': _tipo,
                        'valor': int.parse(_valorController.text),
                        'modo_pago': _modoPago,
                        'registrar': _registrar,
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
