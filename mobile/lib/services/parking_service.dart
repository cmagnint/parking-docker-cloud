import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parking/utils/globals.dart';

class ApiService {
  final String baseUrl = 'http://34.176.183.88:8484/parking_app/';
//  final String baseUrl = 'http://parking.terramobile.cl/parking_app/';

  Future<Map<String, dynamic>> get(String endpoint,
      {bool requiresAuth = true}) async {
    return _sendRequest('GET', endpoint, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data,
      {bool requiresAuth = true}) async {
    return _sendRequest('POST', endpoint,
        data: data, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data,
      {bool requiresAuth = true}) async {
    return _sendRequest('PUT', endpoint,
        data: data, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> delete(String endpoint,
      {Map<String, dynamic>? data, bool requiresAuth = true}) async {
    return _sendRequest('DELETE', endpoint,
        data: data, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> _sendRequest(String method, String endpoint,
      {Map<String, dynamic>? data, bool requiresAuth = true}) async {
    String? accessToken;
    if (requiresAuth) {
      accessToken = await storage.read(key: 'authToken');
      if (accessToken == null) {
        throw Exception('No hay token de autenticación disponible');
      }
    }

    var url = Uri.parse(baseUrl + endpoint);
    loggerGlobal.d('Sending $method request to: $url');
    if (requiresAuth) {
      loggerGlobal.d('Authorization: Bearer $accessToken');
    } else {
      loggerGlobal.d('Request without authentication');
    }
    if (data != null) loggerGlobal.d('Data: $data');

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(url,
              headers: _getHeaders(accessToken, requiresAuth));
          break;
        case 'POST':
          response = await http.post(url,
              headers: _getHeaders(accessToken, requiresAuth),
              body: json.encode(data));
          break;
        case 'PUT':
          response = await http.put(url,
              headers: _getHeaders(accessToken, requiresAuth),
              body: json.encode(data));
          break;
        case 'DELETE':
          response = await http.delete(url,
              headers: _getHeaders(accessToken, requiresAuth),
              body: data != null ? json.encode(data) : null);
          break;
        default:
          throw Exception('Método HTTP no soportado: $method');
      }
      loggerGlobal.d('Response status: ${response.statusCode}');
      loggerGlobal.d('Response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      loggerGlobal.e('Error en la solicitud $method a $url: $e');
      rethrow;
    }
  }

  Map<String, String> _getHeaders(String? accessToken, bool requiresAuth) {
    Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };

    if (requiresAuth && accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204) {
        // Solo 204 No Content retorna un map vacío
        return {};
      }
      // Para 200, 201, etc. parseamos el body si existe
      if (response.body.isNotEmpty) {
        try {
          return json.decode(response.body);
        } catch (e) {
          loggerGlobal.e('Error al decodificar la respuesta JSON: $e');
          throw Exception('Error al decodificar la respuesta JSON: $e');
        }
      } else {
        return {};
      }
    } else {
      loggerGlobal
          .e('Error en la respuesta: ${response.statusCode}, ${response.body}');
      throw Exception('Error: ${response.statusCode}, ${response.body}');
    }
  }
}
