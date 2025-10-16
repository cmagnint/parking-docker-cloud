import 'package:flutter/material.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class FijarMontosScreen extends StatefulWidget {
  const FijarMontosScreen({super.key});

  @override
  FijarMontosScreenState createState() => FijarMontosScreenState();
}

class FijarMontosScreenState extends State<FijarMontosScreen> {
  final ApiService _apiService = ApiService();
  String montoActual = '';
  String intervaloActual = '';
  String montoMinimo = '';
  String intervaloMinimo = '';
  TextEditingController nuevoMontoController = TextEditingController();
  TextEditingController nuevoIntervaloController = TextEditingController();
  TextEditingController montoMinimoController = TextEditingController();
  TextEditingController intervaloMinimoController = TextEditingController();
  String? montoErrorText;
  String? intervaloErrorText;
  String? montoMinimoErrorText;
  String? intervaloMinimoErrorText;

  @override
  void initState() {
    super.initState();
    _fetchParametros();
  }

  Future<void> _fetchParametros() async {
    try {
      var response =
          await _apiService.get('data_parametros/${userInfo.clienteId}');

      // La respuesta ya está decodificada por _apiService
      setState(() {
        montoActual = response['monto_por_intervalo'].toString();
        intervaloActual = response['intervalo_minutos'].toString();
        montoMinimo = response['monto_minimo'].toString();
        intervaloMinimo = response['intervalo_minimo'].toString();
      });
    } catch (e) {
      // Manejar excepciones
      loggerGlobal.e('Error al obtener parámetros: $e');
      // Puedes mostrar un diálogo de error aquí si lo deseas
    }
  }

  Future<void> _actualizarMontos(int nuevoMonto, int nuevoIntervalo,
      int nuevoMinimo, int nuevotiempoMinimo) async {
    try {
      await _apiService.post('cambiar_parametros/', {
        'id': userInfo.clienteId,
        'nuevo_monto': nuevoMonto,
        'nuevo_intervalo': nuevoIntervalo,
        'nuevo_monto_minimo': nuevoMinimo,
        'nuevo_intervalo_minimo': nuevotiempoMinimo,
      });

      // Si llegamos aquí, la solicitud fue exitosa
      if (mounted) {
        montoActualizado(context);
      }
    } catch (e) {
      // Manejar excepciones
      loggerGlobal.e('Error al actualizar montos: $e');
      // Puedes mostrar un diálogo de error aquí si lo deseas
    }
  }

  void montoActualizado(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡Cambio realizado con exito!'),
          actions: <Widget>[
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
                navigateToScreen(context, '/Mother_Layout');
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
        title: const Text('Fijar Montos'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El monto actual por intervalo es: $montoActual pesos por $intervaloActual minutos',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'El monto minimo antes de los $intervaloMinimo minutos es: $montoMinimo pesos',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: nuevoMontoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto',
                errorText: montoErrorText,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: nuevoIntervaloController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Intervalo (minutos)',
                errorText: intervaloErrorText,
              ),
            ),
            TextFormField(
              controller: montoMinimoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto Minimo',
                errorText: montoMinimoErrorText,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: intervaloMinimoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tiempo Minimo',
                errorText: intervaloMinimoErrorText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Convertir los valores a enteros y validar
                int? nuevoMonto = int.tryParse(nuevoMontoController.text);
                int? nuevoIntervalo =
                    int.tryParse(nuevoIntervaloController.text);
                int? nuevoMontoMinimo =
                    int.tryParse(montoMinimoController.text);
                int? nuevoIntervaloMinimo =
                    int.tryParse(intervaloMinimoController.text);

                // Reiniciar mensajes de error
                setState(() {
                  montoErrorText = nuevoMonto != null && nuevoMonto > 0
                      ? null
                      : 'El monto debe ser mayor a cero!';
                  intervaloErrorText =
                      nuevoIntervalo != null && nuevoIntervalo > 0
                          ? null
                          : 'El intervalo debe ser mayor a cero!';
                  montoMinimoErrorText =
                      nuevoMontoMinimo != null && nuevoMontoMinimo > 0
                          ? null
                          : 'El monto mínimo debe ser mayor a cero!';
                  intervaloMinimoErrorText =
                      nuevoIntervaloMinimo != null && nuevoIntervaloMinimo > 0
                          ? null
                          : 'El tiempo mínimo debe ser mayor a cero!';
                });

                // Solo realizar la actualización si todos los valores son válidos
                if (nuevoMonto != null &&
                    nuevoMonto > 0 &&
                    nuevoIntervalo != null &&
                    nuevoIntervalo > 0 &&
                    nuevoMontoMinimo != null &&
                    nuevoMontoMinimo > 0 &&
                    nuevoIntervaloMinimo != null &&
                    nuevoIntervaloMinimo > 0) {
                  _actualizarMontos(nuevoMonto, nuevoIntervalo,
                      nuevoMontoMinimo, nuevoIntervaloMinimo);
                }
              },
              child: const Text('Ingresar Cambio'),
            ),
          ],
        ),
      ),
    );
  }
}
