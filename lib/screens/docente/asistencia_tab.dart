import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../services/curso_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/tarjeta.dart';
import 'sesion_screen.dart';

/// Pestaña Asistencia: retomar la sesión abierta o iniciar una nueva.
class AsistenciaTab extends StatefulWidget {
  const AsistenciaTab({super.key});

  @override
  State<AsistenciaTab> createState() => _AsistenciaTabState();
}

class _AsistenciaTabState extends State<AsistenciaTab> {
  late final Stream<List<Curso>> _cursos = CursoService().cursosDelDocente();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: StreamBuilder<List<Curso>>(
        stream: _cursos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final activos = snapshot.data!.where((c) => c.activo).toList();
          final abiertas = activos.where((c) => c.sesionAbiertaId != null).toList();
          final sinSesion = activos.where((c) => c.sesionAbiertaId == null).toList();

          // Primero los cursos que tienen clase hoy
          final hoy = DateTime.now().weekday;
          final deHoy = sinSesion.where((c) => c.bloqueDe(hoy) != null).toList()
            ..sort((a, b) => a.bloqueDe(hoy)!.inicio.compareTo(b.bloqueDe(hoy)!.inicio));
          final otros = sinSesion.where((c) => c.bloqueDe(hoy) == null).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Asistencia', style: texto.headlineLarge),
              const SizedBox(height: 4),
              Text(
                abiertas.isEmpty ? 'Elige un curso para tomar asistencia' : 'Tienes una sesión en curso',
                style: texto.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (activos.isEmpty)
                Tarjeta(
                  child: Text('Crea un curso en la pestaña Cursos para empezar a tomar asistencia.',
                      style: texto.bodyMedium),
                ),
              for (final c in abiertas) ...[
                _tarjeta(texto, c, enCurso: true),
                const SizedBox(height: 10),
              ],
              if (deHoy.isNotEmpty) ...[
                _titulo(texto, 'Clases de hoy'),
                for (final c in deHoy) ...[
                  _tarjeta(texto, c, detalle: 'Hoy · ${c.bloqueDe(hoy)!.horas}'),
                  const SizedBox(height: 10),
                ],
              ],
              if (otros.isNotEmpty) ...[
                _titulo(texto, deHoy.isEmpty ? 'Tus cursos' : 'Otros cursos'),
                for (final c in otros) ...[
                  _tarjeta(texto, c, detalle: c.lineasHorario.join(' · ')),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _titulo(TextTheme texto, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(t, style: texto.titleMedium),
      );

  Widget _tarjeta(TextTheme texto, Curso c, {bool enCurso = false, String detalle = ''}) {
    final color = colorAsignatura(c.claveAsignatura);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories_outlined, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.titulo,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.titleMedium),
                    Text(
                      enCurso ? '${c.salon} · ${c.totalEstudiantes} estudiantes' : detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                    ),
                  ],
                ),
              ),
              if (enCurso)
                const Pildora('EN VIVO',
                    fondo: Color(0x666CF8BB), color: Color(0xFF00714D), icono: Icons.circle),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => abrirSesion(context, c),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              elevation: 0,
              textStyle: texto.labelLarge,
              backgroundColor: enCurso ? AppColors.verde : AppColors.primarioContenedor,
            ),
            icon: Icon(enCurso ? Icons.qr_code_scanner : Icons.play_circle_outline, size: 18),
            label: Text(enCurso ? 'Volver a la sesión' : 'Iniciar asistencia'),
          ),
        ],
      ),
    );
  }
}
