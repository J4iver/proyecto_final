import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../services/auth_service.dart';
import '../../services/curso_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/asistencia_ui.dart';
import '../../widgets/tarjeta.dart';
import 'detalle_curso_screen.dart';
import 'estudiantes_curso_screen.dart';
import 'sesion_screen.dart';

/// Inicio del docente: las clases de hoy, la que está en curso y las que siguen.
class InicioDocenteTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback alVerCursos; // cambia a la pestaña Cursos

  const InicioDocenteTab({super.key, required this.usuario, required this.alVerCursos});

  @override
  State<InicioDocenteTab> createState() => _InicioDocenteTabState();
}

class _InicioDocenteTabState extends State<InicioDocenteTab> {
  late final Stream<List<Curso>> _cursos = CursoService().cursosDelDocente();
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca cada minuto para que "en curso" e "inicia en" estén al día
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: StreamBuilder<List<Curso>>(
        stream: _cursos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final activos = snapshot.data!.where((c) => c.activo).toList();
          final ahora = DateTime.now();
          final hoy = ahora.weekday;
          final minutos = ahora.hour * 60 + ahora.minute;

          final deHoy = activos.where((c) => c.bloqueDe(hoy) != null).toList()
            ..sort((a, b) => a.bloqueDe(hoy)!.inicio.compareTo(b.bloqueDe(hoy)!.inicio));

          // "En curso": tiene la sesión abierta, o su horario de hoy incluye este momento
          bool enCurso(Curso c) {
            if (c.sesionAbiertaId != null) return true;
            final b = c.bloqueDe(hoy);
            return b != null && minutos >= b.inicio && minutos < b.fin;
          }

          final ahoraMismo = activos.where(enCurso).toList();
          final proximas = deHoy
              .where((c) => !enCurso(c) && c.bloqueDe(hoy)!.inicio > minutos)
              .toList();

          final asignaturas = activos.map((c) => c.claveAsignatura).toSet().length;
          final estudiantesHoy = deHoy.fold<int>(0, (a, c) => a + c.totalEstudiantes);
          final presentes = activos.fold<int>(0, (a, c) => a + c.sumaPresentes);
          final esperados = activos.fold<int>(0, (a, c) => a + c.sumaEsperados);
          final double? general = esperados == 0 ? null : presentes / esperados;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ---------- Saludo ----------
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(formatoDiaLargo(ahora),
                        style: texto.labelSmall?.copyWith(color: AppColors.primario)),
                  ),
                  Pildora('${deHoy.length} ${deHoy.length == 1 ? 'clase hoy' : 'clases hoy'}',
                      fondo: const Color(0xFFDCE9FF), color: AppColors.primario),
                ],
              ),
              const SizedBox(height: 6),
              Text('Hola, Prof. ${widget.usuario.primerNombre}', style: texto.headlineLarge),
              const SizedBox(height: 2),
              Text(
                'Semestre ${semestreActual()} · '
                '$asignaturas ${asignaturas == 1 ? 'asignatura' : 'asignaturas'}, '
                '${activos.length} ${activos.length == 1 ? 'grupo' : 'grupos'}',
                style: texto.bodyMedium,
              ),
              const SizedBox(height: 16),

              if (activos.isEmpty) ...[
                Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Aún no tienes cursos', style: texto.titleMedium),
                      const SizedBox(height: 4),
                      Text('Crea tu primer curso y carga la lista de estudiantes desde un Excel.',
                          style: texto.bodyMedium),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: widget.alVerCursos,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        child: const Text('Ir a Cursos'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ---------- Jornada de hoy ----------
                Tarjeta(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 20, color: AppColors.primario),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Jornada de hoy',
                                style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                          ),
                          if (ahoraMismo.isNotEmpty)
                            const Pildora('En jornada activa',
                                fondo: Color(0xFF6CF8BB),
                                color: Color(0xFF00714D),
                                icono: Icons.circle),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _cifra(
                              texto,
                              'Asistencia',
                              general == null ? '–' : '${(general * 100).toStringAsFixed(1)}%',
                              'acumulada',
                              AppColors.verde,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _cifra(texto, 'Clases hoy', '${deHoy.length}',
                                '${ahoraMismo.length} en curso', AppColors.primario),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _cifra(texto, 'Estudiantes', '$estudiantesHoy', 'programados hoy',
                                AppColors.texto),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---------- Clase en curso ----------
                if (ahoraMismo.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('CLASE EN CURSO · AHORA MISMO',
                          style: texto.labelSmall?.copyWith(color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final c in ahoraMismo) ...[
                    _tarjetaClase(texto, c, hoy, minutos, enCurso: true),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                ],

                // ---------- Próximas ----------
                Row(
                  children: [
                    Expanded(child: Text('Próximas clases de hoy', style: texto.titleMedium)),
                    if (proximas.isNotEmpty)
                      Pildora(
                          '${proximas.length} ${proximas.length == 1 ? 'restante' : 'restantes'}',
                          fondo: const Color(0xFFDCE9FF),
                          color: AppColors.primario),
                  ],
                ),
                const SizedBox(height: 8),
                if (proximas.isEmpty)
                  Tarjeta(
                    child: Text(
                      deHoy.isEmpty
                          ? 'Hoy no tienes clases programadas.'
                          : 'No te quedan más clases por hoy.',
                      style: texto.bodyMedium,
                    ),
                  ),
                for (final c in proximas) ...[
                  _tarjetaClase(texto, c, hoy, minutos, enCurso: false),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cifra(TextTheme texto, String etiqueta, String valor, String pie, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(etiqueta, style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
          Text(valor, style: texto.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(pie,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texto.bodySmall?.copyWith(fontSize: 11, color: AppColors.textoSecundario)),
        ],
      ),
    );
  }

  Widget _tarjetaClase(TextTheme texto, Curso c, int hoy, int minutos, {required bool enCurso}) {
    final bloque = c.bloqueDe(hoy);
    final sesionAbierta = c.sesionAbiertaId != null;
    final color = colorAsignatura(c.claveAsignatura);

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories_outlined, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (c.codigo.isNotEmpty)
                          Pildora(c.codigo,
                              fondo: AppColors.primarioSuave, color: AppColors.primario),
                        if (sesionAbierta)
                          const Pildora('Asistencia abierta',
                              fondo: Color(0xFFFFDAD6),
                              color: Color(0xFF93000A),
                              icono: Icons.circle)
                        else if (!enCurso && bloque != null)
                          Pildora('Inicia en ${formatoFalta(bloque.inicio - minutos)}',
                              fondo: AppColors.primarioSuave,
                              color: AppColors.primario,
                              icono: Icons.schedule),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(c.nombre,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.headlineMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Estudiantes',
                      style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
                  Text('${c.totalEstudiantes}',
                      style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(c.grupo.isEmpty ? 'Grupo único' : c.grupo,
                  style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              const Icon(Icons.event_outlined, size: 15, color: AppColors.verde),
              const SizedBox(width: 4),
              Text(c.diasTexto,
                  style: texto.labelSmall?.copyWith(color: AppColors.verde)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.contorno),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  bloque == null ? c.salon : '${c.salon} • ${bloque.horas}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                ),
              ),
              if (enCurso && bloque != null && minutos < bloque.fin)
                Text('Termina a las ${formatoHora(bloque.fin)}',
                    style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
            ],
          ),
          if (enCurso) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.campo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Asistencia acumulada', style: texto.labelSmall)),
                      Text(
                        c.asistencia == null ? 'Sin clases' : '${(c.asistencia! * 100).round()}%',
                        style: texto.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: c.asistencia == null ? AppColors.contorno : AppColors.verde,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BarraAsistencia(valor: c.asistencia),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _boton(
                  texto,
                  enCurso ? 'Lista de estudiantes' : 'Ver detalle',
                  enCurso ? Icons.list_alt : Icons.visibility_outlined,
                  principal: false,
                  alTocar: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => enCurso
                          ? EstudiantesCursoScreen(curso: c)
                          : DetalleCursoScreen(cursoId: c.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _boton(
                  texto,
                  sesionAbierta ? 'Ver sesión' : 'Tomar asistencia',
                  Icons.qr_code_scanner,
                  principal: true,
                  alTocar: () => abrirSesion(context, c),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boton(TextTheme texto, String t, IconData icono,
      {required bool principal, required VoidCallback alTocar}) {
    return TextButton.icon(
      onPressed: alTocar,
      style: TextButton.styleFrom(
        backgroundColor: principal ? AppColors.primario : const Color(0xFFDCE9FF),
        foregroundColor: principal ? Colors.white : AppColors.primario,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        textStyle: texto.labelMedium,
      ),
      icon: Icon(icono, size: 18),
      label: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
