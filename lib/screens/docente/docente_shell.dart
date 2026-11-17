import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../perfil_screen.dart';
import 'asistencia_tab.dart';
import 'inicio_docente_tab.dart';
import 'mis_cursos_screen.dart';

/// Contenedor del docente: las 4 pestañas con la barra de abajo.
class DocenteShell extends StatefulWidget {
  final Usuario usuario;
  const DocenteShell({super.key, required this.usuario});

  @override
  State<DocenteShell> createState() => _DocenteShellState();
}

class _DocenteShellState extends State<DocenteShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene viva cada pestaña al cambiar entre ellas
      body: IndexedStack(
        index: _indice,
        children: [
          InicioDocenteTab(
            usuario: widget.usuario,
            alVerCursos: () => setState(() => _indice = 1),
          ),
          const MisCursosScreen(),
          const AsistenciaTab(),
          PerfilScreen(usuario: widget.usuario),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarioSuave,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Cursos'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Asistencia'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
