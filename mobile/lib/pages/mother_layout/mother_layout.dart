import 'package:flutter/material.dart';
import 'package:parking/pages/mother_layout/administracion/administrar_usuarios.dart';
import 'package:parking/pages/mother_layout/administracion/parametros.dart';
import 'package:parking/pages/mother_layout/administracion/modificar_registro.dart';
import 'package:parking/pages/mother_layout/estacionamiento/crear_registro_cliente.dart';
import 'package:parking/pages/mother_layout/estacionamiento/historial.dart';
import 'package:parking/pages/mother_layout/estacionamiento/ingreso.dart';
import 'package:parking/pages/mother_layout/inicio.dart';
import 'package:parking/pages/mother_layout/servicios/administrar_clientes_servicios.dart';
import 'package:parking/pages/mother_layout/servicios/administrar_servicios.dart';
import 'package:parking/pages/mother_layout/servicios/asociar_servicios.dart';
import 'package:parking/pages/superadministracion/administrar_cliente.dart';
import 'package:parking/pages/superadministracion/registro_superadmin.dart';
import 'package:parking/services/parking_service.dart';
import 'package:parking/utils/globals.dart';

class MotherLayout extends StatefulWidget {
  const MotherLayout({super.key});

  @override
  MotherLayoutState createState() => MotherLayoutState();
}

class MotherLayoutState extends State<MotherLayout>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  ApiService apiService = ApiService();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  final List<Widget> _pages = [
    const Inicio(), // _selectedIndex = 0 INICIO
    //SUPERADMIN
    const AdministrarCliente(), // _selectedIndex = 1 CREAR CLIENTES
    const SuperRegistro(), // _selectedIndex = 2 REGISTRO SUPERADMIN
    //ADMINISTRACION
    const AdministrarUsuarios(), // _selectedIndex = 3 CREAR USUARIO
    const AdministrarUsuarios(), // _selectedIndex = 4 MODIFICAR USUARIO
    const ParametrosScreen(), // _selectedIndex = 5 FIJAR MONTOS
    const ModificarRegistro(), // _selectedIndex = 6 MODIFICAR REGISTRO
    //ESTACIONAMIENTO
    const RegistroVehiculoScreen(), // _selectedIndex = 7 REGISTRAR VEHICULOS
    const HistorialScreen(), // _selectedIndex = 8 HISTORIAL
    const ClientesScreen(), //_selectedIndex = 9 CREAR CLIENTE
    //SERVICIOS
    const AdministrarServicioPage(), //_selectedIndex = 10 ADMINISTRAR SERVICIOS
    const AgendarServicioPage(), //_selectedIndex = 11
    const AdministrarClienteServicios(), // _selectedIndex = 12
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void cerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.logout,
                color: Color(0xFF2F4858), // Azul petróleo
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                '¿Desea cerrar sesión?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: const Text(
            'Se cerrará su sesión actual y será redirigido al login.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A085), // Verde esmeralda
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                UserInfo user = UserInfo();
                await storage.deleteAll();
                user.clear();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  navigateToScreen(context, '/Login');
                }
              },
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected
            ? const Color(0xFF00B894).withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? const Color(0xFF00B894)
              : const Color(0xFF2F4858).withValues(alpha: 0.1),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
                isSelected ? const Color(0xFF00B894) : const Color(0xFF2F4858),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2F4858).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          icon,
          color: const Color(0xFF2F4858),
          size: 22,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2F4858),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        iconColor: const Color(0xFF00A085),
        collapsedIconColor: const Color(0xFF2F4858).withValues(alpha: 0.7),
        childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
        children: children,
      ),
    );
  }

  void _onFabPressed() {
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF00B894), // Verde esmeralda claro
                Color(0xFF00A085), // Verde esmeralda medio
                Color(0xFF2F4858), // Azul petróleo
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_parking,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'TERRAPARKING',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              height: 200,
              width: 310,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00B894), // Verde esmeralda claro
                    Color(0xFF00A085), // Verde esmeralda medio
                    Color(0xFF2F4858), // Azul petróleo
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userInfo.name.isNotEmpty ? userInfo.name : 'Usuario',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userInfo.superadmin
                          ? 'Superadministrador'
                          : userInfo.admin
                              ? 'Administrador'
                              : 'Usuario',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: <Widget>[
                  const SizedBox(height: 8),
                  if (userInfo.superadmin)
                    _buildExpansionTile(
                      icon: Icons.admin_panel_settings,
                      title: 'Superadmin',
                      children: <Widget>[
                        _buildDrawerTile(
                          icon: Icons.business,
                          title: 'Administrar Clientes',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 1;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 1,
                        ),
                        _buildDrawerTile(
                          icon: Icons.analytics,
                          title: 'Registro Global',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 2;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 2,
                        ),
                      ],
                    ),
                  if (userInfo.admin)
                    _buildExpansionTile(
                      icon: Icons.manage_accounts,
                      title: 'Administración',
                      children: <Widget>[
                        _buildDrawerTile(
                          icon: Icons.person_add,
                          title: 'Administrar Usuarios',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 3;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 3,
                        ),
                        _buildDrawerTile(
                          icon: Icons.attach_money,
                          title: 'Parametros',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 5;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 5,
                        ),
                        _buildDrawerTile(
                          icon: Icons.history,
                          title: 'Historial de Registros',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 6;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 6,
                        ),
                      ],
                    ),
                  if (!userInfo.superadmin)
                    _buildExpansionTile(
                      icon: Icons.local_parking,
                      title: 'Estacionamiento',
                      children: <Widget>[
                        _buildDrawerTile(
                          icon: Icons.directions_car,
                          title: 'Ingresar Vehículo',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 7;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 7,
                        ),
                        _buildDrawerTile(
                          icon: Icons.person_add_alt_1,
                          title: 'Crear Cliente',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 9;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 9,
                        ),
                      ],
                    ),
                  if (!userInfo.superadmin)
                    _buildExpansionTile(
                      icon: Icons.room_service,
                      title: 'Servicios',
                      children: <Widget>[
                        _buildDrawerTile(
                          icon: Icons.people,
                          title: 'Administrar Clientes Servicios',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 12;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 12,
                        ),
                        _buildDrawerTile(
                          icon: Icons.build,
                          title: 'Administrar Servicios',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 10;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 10,
                        ),
                        _buildDrawerTile(
                          icon: Icons.event,
                          title: 'Asociar Servicios',
                          onTap: () {
                            setState(() {
                              _selectedIndex = 11;
                            });
                            Navigator.pop(context);
                          },
                          isSelected: _selectedIndex == 11,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2F4858).withValues(alpha: 0.05),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF2F4858).withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'by ®Terrasoft',
                    style: TextStyle(
                      color: const Color(0xFF2F4858).withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'V 1.2.5',
                    style: TextStyle(
                      color: const Color(0xFF2F4858).withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF00B894).withValues(alpha: 0.05),
                  Colors.white,
                  const Color(0xFF2F4858).withValues(alpha: 0.05),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: _pages.elementAt(_selectedIndex),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00B894)
                        .withValues(alpha: 0.9), // Verde esmeralda
                    const Color(0xFF00A085), // Verde esmeralda medio
                    const Color(0xFF2F4858), // Azul petróleo
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomAppBar(
                color: Colors.transparent,
                shape: const CircularNotchedRectangle(),
                notchMargin: 8.0,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Builder(
                        builder: (context) {
                          return IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          );
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        onPressed: () {
                          cerrarSesion(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 28,
            child: ScaleTransition(
              scale: _fabScaleAnimation,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF00B894), // Verde esmeralda
                elevation: 8,
                onPressed: _onFabPressed,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00B894), // Verde esmeralda claro
                        Color(0xFF00A085), // Verde esmeralda medio
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B894).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
