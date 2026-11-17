import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../perfil_screen.dart';
import 'asistencia_estudiante_tab.dart';
import 'inicio_estudiante_tab.dart';
import 'mis_cursos_estudiante_tab.dart';

/// Contenedor del estudiante: las 4 pestañas con la barra de abajo.
class EstudianteShell extends StatefulWidget {
  final Usuario usuario;
  const EstudianteShell({super.key, required this.usuario});

  @override
  State<EstudianteShell> createState() => _EstudianteShellState();
}

class _EstudianteShellState extends State<EstudianteShell> {
  static const _tabAsistencia = 2;
  static const _tabCursos = 1;
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          InicioEstudianteTab(
            usuario: widget.usuario,
            alEscanear: () => setState(() => _indice = _tabAsistencia),
            alVerCursos: () => setState(() => _indice = _tabCursos),
          ),
          MisCursosEstudianteTab(usuario: widget.usuario),
          // La cámara solo se enciende mientras esta pestaña está a la vista
          AsistenciaEstudianteTab(
            usuario: widget.usuario,
            activa: _indice == _tabAsistencia,
          ),
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
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Cursos'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Asistencia'),
          NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
