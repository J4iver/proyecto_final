import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/resumen.dart';
import '../../models/sesion.dart';
import '../../services/auth_service.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/asistencia_ui.dart';
import '../../widgets/tarjeta.dart';
import 'con_datos.dart';

enum _Filtro { todos, asistencias, faltas }

/// Detalle de un curso para el estudiante: su asistencia y el historial clase por clase.
class DetalleCursoEstudianteScreen extends StatefulWidget {
  final Usuario usuario;
  final String cursoId;

  const DetalleCursoEstudianteScreen({super.key, required this.usuario, required this.cursoId});

  @override
  State<DetalleCursoEstudianteScreen> createState() => _DetalleCursoEstudianteScreenState();
}

class _DetalleCursoEstudianteScreenState extends State<DetalleCursoEstudianteScreen> {
  late final Stream<List<Sesion>> _sesiones = SesionService().sesionesDelCurso(widget.cursoId);
  _Filtro _filtro = _Filtro.todos;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Detalle del curso', style: texto.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ConDatos(
          usuario: widget.usuario,
          builder: (context, datos) {
            Curso? curso;
            for (final c in datos.cursos) {
              if (c.id == widget.cursoId) curso = c;
            }
            if (curso == null) {
              return const Center(child: Text('Ya no estás en la lista de este curso.'));
            }
            final resumen = datos.resumen(curso);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _encabezado(texto, curso),
                const SizedBox(height: 12),
                if (datos.sinHistorial) const AvisoSinHistorial(),
                _metricas(texto, resumen),
                const SizedBox(height: 20),
                _historial(texto, datos),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _encabezado(TextTheme texto, Curso c) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Pildora([c.codigo, c.grupo].where((t) => t.isNotEmpty).join(' · '),
                  fondo: const Color(0xFFDCE9FF), color: AppColors.primario),
              const Pildora('Activo',
                  fondo: Color(0xFF6FFBBE), color: Color(0xFF002113), icono: Icons.circle),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.nombre, style: texto.headlineMedium),
          if (c.docenteNombre.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.primario),
                  const SizedBox(width: 4),
                  Text(c.docenteNombre,
                      style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linea in c.lineasHorario)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: AppColors.primario),
                        const SizedBox(width: 6),
                        Text(linea, style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.verde),
                    const SizedBox(width: 6),
                    Text(c.salon, style: texto.labelSmall?.copyWith(color: AppColors.texto)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricas(TextTheme texto, ResumenCurso r) {
    final p = r.porcentaje;
    final color = colorNivel(r.nivel);
    String detalle;
    if (p == null) {
      detalle = 'Este curso aún no tiene clases registradas.';
    } else if (p >= minimoAsistencia) {
      final puntos = ((p - minimoAsistencia) * 100).toStringAsFixed(1);
      detalle = 'Estás $puntos puntos por encima del 80% que exige la universidad.';
    } else {
      final puntos = ((minimoAsistencia - p) * 100).toStringAsFixed(1);
      detalle = 'Te faltan $puntos puntos para llegar al 80% que exige la universidad.';
    }

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Asistencia general', style: texto.titleMedium)),
              PildoraNivel(r.nivel),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                AnilloAsistencia(
                    valor: p, tamano: 88, color: r.nivel == Nivel.sinDatos ? null : color),
                const SizedBox(width: 16),
                Expanded(child: Text(detalle, style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _metrica(texto, '${r.asistidas}', 'Asistencias', Icons.check_circle_outline,
                      AppColors.verde)),
              const SizedBox(width: 8),
              Expanded(
                  child: _metrica(texto, '${r.faltas}', 'Faltas', Icons.block, AppColors.error)),
              const SizedBox(width: 8),
              Expanded(
                  child: _metrica(texto, '${r.total}', 'Clases dadas', Icons.event_available_outlined,
                      AppColors.primario)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrica(TextTheme texto, String numero, String etiqueta, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(height: 4),
          Text(numero, style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texto.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }

  // ---------- Historial ----------

  Widget _historial(TextTheme texto, DatosEstudiante datos) {
    return StreamBuilder<List<Sesion>>(
      stream: _sesiones,
      builder: (context, snapshot) {
        final sesiones = snapshot.data ?? const <Sesion>[];
        bool asistio(Sesion s) => datos.registroDe(s.id)?.presente ?? false;

        final visibles = sesiones.where((s) {
          switch (_filtro) {
            case _Filtro.todos:
              return true;
            case _Filtro.asistencias:
              return asistio(s);
            case _Filtro.faltas:
              return !asistio(s) && !s.abierta;
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('Historial de clases', style: texto.titleMedium),
                  ),
                ),
                Text('${sesiones.length} ${sesiones.length == 1 ? 'sesión' : 'sesiones'}',
                    style: texto.labelSmall?.copyWith(color: AppColors.contorno)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.contenedor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _segmento(texto, 'Todos', _Filtro.todos),
                  _segmento(texto, 'Asistencias', _Filtro.asistencias),
                  _segmento(texto, 'Faltas', _Filtro.faltas),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (visibles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  !snapshot.hasData
                      ? 'Cargando…'
                      : sesiones.isEmpty
                          ? 'Aún no se ha tomado asistencia en este curso.'
                          : 'No hay clases en este filtro.',
                  textAlign: TextAlign.center,
                  style: texto.bodyMedium,
                ),
              ),
            for (final s in visibles) _filaSesion(texto, s, datos.registroDe(s.id)),
          ],
        );
      },
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
              style: texto.labelSmall
                  ?.copyWith(color: activo ? AppColors.primario : AppColors.textoSecundario)),
        ),
      ),
    );
  }

  Widget _filaSesion(TextTheme texto, Sesion s, RegistroAsistencia? r) {
    final presente = r?.presente ?? false;
    final esHoy = DateUtils.isSameDay(s.inicio, DateTime.now());

    final String estado;
    final Color color;
    final String detalle;
    if (presente) {
      estado = 'Presente';
      color = AppColors.verde;
      detalle = '${r!.metodoTexto} · ${formatoHoraDia(r.hora)}';
    } else if (s.abierta) {
      estado = 'En curso';
      color = AppColors.primario;
      detalle = 'La sesión sigue abierta';
    } else {
      estado = 'Ausente';
      color = AppColors.error;
      detalle = 'No registraste asistencia';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tarjeta(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                presente
                    ? (r!.metodo == 'qr' ? Icons.qr_code_2 : Icons.how_to_reg)
                    : (s.abierta ? Icons.timelapse : Icons.close),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(formatoDiaCorto(s.inicio), style: texto.titleMedium),
                      if (esHoy) ...[
                        const SizedBox(width: 6),
                        const Pildora('Hoy', fondo: AppColors.primarioSuave, color: AppColors.primario),
                      ],
                    ],
                  ),
                  Text(
                    s.titulo.isEmpty ? detalle : '${s.titulo} · $detalle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Pildora(estado, fondo: color.withValues(alpha: 0.14), color: color, icono: Icons.circle),
          ],
        ),
      ),
    );
  }
}
