import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/resumen.dart';
import '../../models/sesion.dart';
import '../../services/auth_service.dart';
import '../../services/estudiante_service.dart';
import '../../theme/app_theme.dart';

/// Carga en vivo los cursos y registros del estudiante y se los pasa a [builder].
/// Lo usan Inicio, Mis cursos, el detalle y el historial.
class ConDatos extends StatefulWidget {
  final Usuario usuario;
  final Widget Function(BuildContext context, DatosEstudiante datos) builder;

  const ConDatos({super.key, required this.usuario, required this.builder});

  @override
  State<ConDatos> createState() => _ConDatosState();
}

class _ConDatosState extends State<ConDatos> {
  final _servicio = EstudianteService();
  late final Stream<List<Curso>> _cursos = _servicio.misCursos(widget.usuario.codigo);
  late final Stream<List<RegistroAsistencia>> _registros =
      _servicio.misAsistencias(widget.usuario.codigo);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Curso>>(
      stream: _cursos,
      builder: (context, snapCursos) {
        if (snapCursos.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se pudieron cargar tus cursos.', textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapCursos.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<List<RegistroAsistencia>>(
          stream: _registros,
          builder: (context, snapRegistros) {
            // Si falla (por ejemplo, falta el índice en Firebase) la pantalla
            // igual se muestra, solo que sin el historial.
            if (!snapRegistros.hasData && !snapRegistros.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            return widget.builder(
              context,
              DatosEstudiante(
                cursos: snapCursos.data!,
                registros: snapRegistros.data ?? const [],
                sinHistorial: snapRegistros.hasError,
              ),
            );
          },
        );
      },
    );
  }
}

/// Aviso que se muestra cuando no se pudo cargar el historial.
class AvisoSinHistorial extends StatelessWidget {
  const AvisoSinHistorial({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x66FFDAD6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudo cargar tu historial de asistencia. '
              'Falta crear el índice de "asistencias" en Firebase.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF93000A)),
            ),
          ),
        ],
      ),
    );
  }
}
