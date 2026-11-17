import 'package:flutter/material.dart';
import '../../models/resumen.dart';
import '../../models/sesion.dart';
import '../../services/auth_service.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/asistencia_ui.dart';
import '../../widgets/tarjeta.dart';
import 'con_datos.dart';
import 'detalle_curso_estudiante_screen.dart';

enum _Filtro { todos, alerta, alDia }

class MisCursosEstudianteTab extends StatefulWidget {
  final Usuario usuario;
  const MisCursosEstudianteTab({super.key, required this.usuario});

  @override
  State<MisCursosEstudianteTab> createState() => _MisCursosEstudianteTabState();
}

class _MisCursosEstudianteTabState extends State<MisCursosEstudianteTab> {
  _Filtro _filtro = _Filtro.todos;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: ConDatos(
        usuario: widget.usuario,
        builder: (context, datos) {
          final todos = datos.resumenes;
          final conAlerta = todos.where((r) => r.conAlerta).toList();
          final alDia = todos.where((r) => !r.conAlerta).toList();
          final visibles = switch (_filtro) {
            _Filtro.todos => todos,
            _Filtro.alerta => conAlerta,
            _Filtro.alDia => alDia,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Mis cursos', style: texto.headlineLarge)),
                  Pildora('Semestre ${semestreActual()}',
                      fondo: AppColors.primarioSuave, color: AppColors.primario),
                ],
              ),
              const SizedBox(height: 4),
              Text('${todos.length} ${todos.length == 1 ? 'curso inscrito' : 'cursos inscritos'}',
                  style: texto.bodyMedium),
              const SizedBox(height: 14),
              if (datos.sinHistorial) const AvisoSinHistorial(),

              // ---------- Filtros ----------
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE9FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    _segmento(texto, 'Todos (${todos.length})', _Filtro.todos),
                    _segmento(texto, 'Con alerta (${conAlerta.length})', _Filtro.alerta),
                    _segmento(texto, 'Al día (${alDia.length})', _Filtro.alDia),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (visibles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    todos.isEmpty
                        ? 'Todavía no estás en la lista de ningún curso.'
                        : 'No hay cursos en este filtro.',
                    textAlign: TextAlign.center,
                    style: texto.bodyMedium,
                  ),
                ),
              for (final r in visibles) ...[
                _TarjetaCursoEstudiante(
                  resumen: r,
                  datos: datos,
                  alVerDetalle: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleCursoEstudianteScreen(
                          usuario: widget.usuario, cursoId: r.curso.id),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _segmento(TextTheme texto, String t, _Filtro f) {
    final activo = _filtro == f;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _filtro = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texto.labelSmall
                  ?.copyWith(color: activo ? AppColors.primario : AppColors.textoSecundario)),
        ),
      ),
    );
  }
}

class _TarjetaCursoEstudiante extends StatefulWidget {
  final ResumenCurso resumen;
  final DatosEstudiante datos;
  final VoidCallback alVerDetalle;

  const _TarjetaCursoEstudiante({
    required this.resumen,
    required this.datos,
    required this.alVerDetalle,
  });

  @override
  State<_TarjetaCursoEstudiante> createState() => _TarjetaCursoEstudianteState();
}

class _TarjetaCursoEstudianteState extends State<_TarjetaCursoEstudiante> {
  // Las últimas 5 sesiones del curso, para los puntos de "Últimas clases"
  late final Stream<List<Sesion>> _ultimas =
      SesionService().sesionesDelCurso(widget.resumen.curso.id, limite: 5);

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final r = widget.resumen;
    final c = r.curso;
    final p = r.porcentaje;
    final color = colorNivel(r.nivel);
    final colorCurso = colorAsignatura(c.claveAsignatura);

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorCurso.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_stories_outlined, size: 26, color: colorCurso),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [c.codigo, c.grupo].where((t) => t.isNotEmpty).join(' • '),
                      style: texto.labelSmall?.copyWith(color: AppColors.primario),
                    ),
                    Text(c.nombre,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.titleMedium),
                    if (c.docenteNombre.isNotEmpty)
                      Text(c.docenteNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: PildoraNivel(r.nivel)),
          const SizedBox(height: 10),

          // ---------- Porcentaje y barra ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(p == null ? '–' : '${(p * 100).toStringAsFixed(1)}%',
                  style: texto.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: r.conAlerta ? color : AppColors.texto)),
              const SizedBox(width: 6),
              Text('asistencia',
                  style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
              const Spacer(),
              Text('${r.asistidas} de ${r.total} sesiones',
                  style: texto.labelMedium?.copyWith(color: AppColors.textoSecundario)),
            ],
          ),
          const SizedBox(height: 6),
          BarraAsistencia(valor: p, color: r.nivel == Nivel.sinDatos ? AppColors.verde : color),
          const SizedBox(height: 10),

          // ---------- Últimas clases ----------
          StreamBuilder<List<Sesion>>(
            stream: _ultimas,
            builder: (context, snapshot) {
              // De la más antigua a la más reciente, como se lee una línea de tiempo
              final sesiones = (snapshot.data ?? const <Sesion>[]).reversed.toList();
              if (sesiones.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  Expanded(
                    child: Text('Últimas ${sesiones.length} clases:',
                        style: texto.labelSmall?.copyWith(color: AppColors.contorno)),
                  ),
                  for (final s in sesiones)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _punto(s),
                    ),
                ],
              );
            },
          ),

          if (r.nivel == Nivel.atencion || r.nivel == Nivel.bajo) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.nivel == Nivel.bajo
                          ? 'Estás por debajo del 80% que exige la universidad.'
                          : 'Estás cerca del 80% mínimo: procura no faltar.',
                      style: texto.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.alVerDetalle,
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.contenedor,
              minimumSize: const Size.fromHeight(44),
              shape: const StadiumBorder(),
              textStyle: texto.labelMedium,
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Ver detalle'),
          ),
        ],
      ),
    );
  }

  /// Verde = presente, rojo = ausente, gris = sesión que sigue abierta.
  Widget _punto(Sesion s) {
    final registro = widget.datos.registroDe(s.id);
    final Color color;
    final String ayuda;
    if (registro != null && registro.presente) {
      color = AppColors.verde;
      ayuda = 'Presente';
    } else if (s.abierta) {
      color = AppColors.contornoSuave;
      ayuda = 'En curso';
    } else {
      color = AppColors.error;
      ayuda = 'Ausente';
    }
    return Tooltip(
      message: '${formatoDiaCorto(s.inicio)} · $ayuda',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
