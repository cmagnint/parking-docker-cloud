import 'dart:io';
import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

const tokenStorage = FlutterSecureStorage();
const storage = FlutterSecureStorage();

class UserInfo {
  String rut = '';
  String dv = '';
  String name = '';
  String password = '';
  String email = '';
  int clienteId = 0;
  int valorParametro = 0;
  int tiempoParametro = 0;
  int montoMinimo = 0;
  int tiempoMinimo = 0;
  bool admin = false;
  bool superadmin = false;

  void clear() {
    rut = '';
    dv = '';
    name = '';
    password = '';
    email = '';
  }
}

class GlobalState {
  File? selectedImage;

  bool alreadyDownloaded = false;
  bool hasResponse = false;
}

final UserInfo userInfo = UserInfo();

final GlobalState globalState = GlobalState();
final Logger loggerGlobal = Logger();

void navigateToScreen(BuildContext context, String routeName) {
  Navigator.pushReplacementNamed(context, routeName);
}
