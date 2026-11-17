import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/sesion.dart';
import '../../services/curso_service.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/tarjeta.dart';

/// Lista completa de una sesión: todos los estudiantes con su estado.
/// Si la sesión está abierta, el docente puede marcar a mano.
/// Si está cerrada, solo se consulta (es el detalle del historial).
class ListaAsistenciaScreen extends StatefulWidget {
  final Curso curso;
  final Sesion sesion;

  const ListaAsistenciaScreen({super.key, required this.curso, required this.sesion});

  @override
  State<ListaAsistenciaScreen> createState() => _ListaAsistenciaScreenState();
}

class _ListaAsistenciaScreenState extends State<ListaAsistenciaScreen> {
  final _sesiones = SesionService();
  late final Stream<List<EstudianteCurso>> _estudiantes =
      CursoService().estudiantes(widget.curso.id);
  late final Stream<List<Asistencia>> _asistencias =
      _sesiones.asistencias(widget.curso.id, widget.sesion.id);
  late final Stream<Sesion?> _sesion = _sesiones.sesion(widget.curso.id, widget.sesion.id);

  Future<void> _marcar(EstudianteCurso e, Asistencia? actual, bool presente) async {
    try {
      // Tocar el estado que ya tiene lo deja otra vez como pendiente
      if (actual != null && actual.presente == presente) {
        await _sesiones.desmarcar(widget.curso.id, widget.sesion.id, e.codigo);
      } else {
        await _sesiones.marcar(widget.curso.id, widget.sesion.id, e,
            presente: presente, metodo: 'manual');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo guardar el cambio.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Lista de asistencia', style: texto.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<Sesion?>(
          stream: _sesion,
          initialData: widget.sesion,
          builder: (context, snapSesion) {
            final sesion = snapSesion.data ?? widget.sesion;
            return StreamBuilder<List<EstudianteCurso>>(
              stream: _estudiantes,
              builder: (context, snapEst) {
                return StreamBuilder<List<Asistencia>>(
                  stream: _asistencias,
                  builder: (context, snapAsis) {
                    if (!snapEst.hasData || !snapAsis.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final estudiantes = snapEst.data!;
                    final porCodigo = {for (final a in snapAsis.data!) a.codigo: a};
                    final presentes = porCodigo.values.where((a) => a.presente).length;
                    final marcadosAusentes = porCodigo.values.where((a) => !a.presente).length;
                    // En una sesión cerrada, quien no marcó cuenta como ausente
                    final ausentes =
                        sesion.abierta ? marcadosAusentes : estudiantes.length - presentes;
                    final pendientes =
                        sesion.abierta ? estudiantes.length - presentes - marcadosAusentes : 0;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Text(widget.curso.titulo, style: texto.headlineMedium),
                        Text('${sesion.tituloVisible} · ${formatoFecha(sesion.inicio)}',
                            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Pildora('$presentes presentes',
                                fondo: const Color(0x4D6CF8BB), color: const Color(0xFF00714D)),
                            Pildora('$ausentes ausentes',
                                fondo: const Color(0x66FFDAD6), color: const Color(0xFF93000A)),
                            if (sesion.abierta)
                              Pildora('$pendientes pendientes',
                                  fondo: AppColors.contenedor, color: AppColors.textoSecundario),
                          ],
                        ),
                        if (sesion.abierta) ...[
                          const SizedBox(height: 8),
                          Text('Toca ✓ o ✕ para marcar a mano. Tócalo de nuevo para quitar la marca.',
                              style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                        ],
                        const SizedBox(height: 12),
                        for (final e in estudiantes)
                          _fila(texto, e, porCodigo[e.codigo], sesion.abierta),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _fila(TextTheme texto, EstudianteCurso e, Asistencia? a, bool abierta) {
    final presente = a?.presente ?? false;
    final ausente = a != null ? !a.presente : !abierta;

    final String detalle;
    if (presente) {
      detalle = 'Presente · ${a!.metodoTexto} · ${formatoHoraDia(a.hora)}';
    } else if (ausente) {
      detalle = 'Ausente';
    } else {
      detalle = 'Pendiente';
    }
    final color = presente
        ? AppColors.verde
        : ausente
            ? AppColors.error
            : AppColors.contorno;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(iniciales(e.nombre), style: texto.labelMedium?.copyWith(color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                Text('${e.codigo} · $detalle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.bodySmall?.copyWith(color: color)),
              ],
            ),
          ),
          if (abierta) ...[
            IconButton(
              tooltip: 'Ausente',
              visualDensity: VisualDensity.compact,
              icon: Icon(ausente ? Icons.cancel : Icons.cancel_outlined,
                  color: ausente ? AppColors.error : AppColors.contornoSuave),
              onPressed: () => _marcar(e, a, false),
            ),
            IconButton(
              tooltip: 'Presente',
              visualDensity: VisualDensity.compact,
              icon: Icon(presente ? Icons.check_circle : Icons.check_circle_outline,
                  color: presente ? AppColors.verde : AppColors.contornoSuave),
              onPressed: () => _marcar(e, a, true),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(presente ? Icons.check_circle : Icons.cancel, color: color, size: 22),
            ),
        ],
      ),
    );
  }
}
