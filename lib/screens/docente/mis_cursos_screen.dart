import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../services/curso_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import 'crear_curso_screen.dart';
import 'detalle_curso_screen.dart';
import 'sesion_screen.dart';

class MisCursosScreen extends StatefulWidget {
  const MisCursosScreen({super.key});

  @override
  State<MisCursosScreen> createState() => _MisCursosScreenState();
}

class _MisCursosScreenState extends State<MisCursosScreen> {
  final _servicio = CursoService();
  late final Stream<List<Curso>> _cursos = _servicio.cursosDelDocente();
  bool _verActivos = true;

  void _nuevoCurso() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearCursoScreen()));
  }

  void _verDetalle(Curso curso) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleCursoScreen(cursoId: curso.id)),
    );
  }

  Future<void> _cambiarEstado(Curso curso) async {
    final archivar = curso.activo;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(archivar ? '¿Archivar curso?' : '¿Reactivar curso?'),
        content: Text(archivar
            ? '"${curso.nombre} · ${curso.grupo}" pasará a Finalizados. '
                'El registro de asistencias se conserva, pero el curso ya no aceptará nuevas asistencias.'
            : '"${curso.nombre} · ${curso.grupo}" volverá a estar activo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: archivar ? TextButton.styleFrom(foregroundColor: AppColors.error) : null,
            child: Text(archivar ? 'Archivar' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _servicio.cambiarEstado(curso.id, activo: !archivar);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo actualizar el curso.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: StreamBuilder<List<Curso>>(
        stream: _cursos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar los cursos.\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final todos = snapshot.data!;
          final activos = todos.where((c) => c.activo).toList();
          final finalizados = todos.where((c) => !c.activo).toList();
          final visibles = _verActivos ? activos : finalizados;

          // Agrupar por asignatura conservando el orden
          final grupos = <String, List<Curso>>{};
          for (final c in visibles) {
            grupos.putIfAbsent(c.claveAsignatura, () => []).add(c);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ---------- Encabezado ----------
              Row(
                children: [
                  Expanded(child: Text('Mis cursos', style: texto.headlineLarge)),
                  _pildora(texto, 'Semestre ${semestreActual()}'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                activos.isEmpty
                    ? 'Aún no tienes cursos activos'
                    : '${activos.length} ${activos.length == 1 ? 'curso activo' : 'cursos activos'}',
                style: texto.bodyMedium,
              ),
              const SizedBox(height: 16),

              // ---------- Nuevo curso ----------
              _bannerNuevo(texto),
              const SizedBox(height: 16),

              // ---------- Filtros ----------
              Row(
                children: [
                  _filtro('Activos (${activos.length})', _verActivos, () {
                    setState(() => _verActivos = true);
                  }),
                  const SizedBox(width: 8),
                  _filtro('Finalizados (${finalizados.length})', !_verActivos, () {
                    setState(() => _verActivos = false);
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // ---------- Lista ----------
              if (visibles.isEmpty)
                _vacio(texto)
              else
                for (final lista in grupos.values) ...[
                  _encabezadoAsignatura(texto, lista),
                  const SizedBox(height: 10),
                  for (final curso in lista) ...[
                    _TarjetaCurso(
                      curso: curso,
                      alVerDetalle: () => _verDetalle(curso),
                      alPasarLista: () => abrirSesion(context, curso),
                      alCambiarEstado: () => _cambiarEstado(curso),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _pildora(TextTheme texto, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primarioSuave,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(t, style: texto.labelSmall?.copyWith(color: AppColors.primario)),
      );

  Widget _bannerNuevo(TextTheme texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primario, AppColors.primarioContenedor, Color(0xFF3755C3)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agregar un curso', style: texto.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                Text('Carga la lista de estudiantes desde un Excel',
                    style: texto.bodySmall?.copyWith(color: const Color(0xFFB8C4FF))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _nuevoCurso,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primario,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: texto.labelMedium,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Nuevo curso'),
          ),
        ],
      ),
    );
  }

  Widget _filtro(String t, bool activo, VoidCallback alTocar) {
    return ChoiceChip(
      label: Text(t),
      selected: activo,
      onSelected: (_) => alTocar(),
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide(color: activo ? Colors.transparent : AppColors.contornoSuave),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primario,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: activo ? Colors.white : AppColors.textoSecundario,
          ),
    );
  }

  Widget _vacio(TextTheme texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 44, color: AppColors.contornoSuave),
          const SizedBox(height: 12),
          Text(_verActivos ? 'Crea tu primer curso' : 'No hay cursos finalizados',
              style: texto.titleMedium),
          if (_verActivos) ...[
            const SizedBox(height: 4),
            Text('Toca "Nuevo curso" para empezar.', style: texto.bodyMedium),
          ],
        ],
      ),
    );
  }

  /// Título de la asignatura: agrupa visualmente todos sus grupos.
  Widget _encabezadoAsignatura(TextTheme texto, List<Curso> lista) {
    final primero = lista.first;
    final color = colorAsignatura(primero.claveAsignatura);
    final total = lista.fold<int>(0, (a, c) => a + c.totalEstudiantes);
    return Row(
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
              Text(primero.nombre,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.titleMedium),
              Text(
                '${primero.codigo.isEmpty ? '' : '${primero.codigo} · '}'
                '${lista.length} ${lista.length == 1 ? 'grupo' : 'grupos'} · $total estudiantes',
                style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de un curso (un grupo de una asignatura).
class _TarjetaCurso extends StatelessWidget {
  final Curso curso;
  final VoidCallback alVerDetalle;
  final VoidCallback alPasarLista;
  final VoidCallback alCambiarEstado;

  const _TarjetaCurso({
    required this.curso,
    required this.alVerDetalle,
    required this.alPasarLista,
    required this.alCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final color = colorAsignatura(curso.claveAsignatura);
    final asistencia = curso.asistencia;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: curso.activo ? Colors.white : AppColors.campo,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja con el color de la asignatura
                Container(width: 5, color: curso.activo ? color : AppColors.contornoSuave),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------- Grupo, estudiantes y menú ----------
                        Row(
                          children: [
                            Flexible(
                              child: Text(curso.grupo.isEmpty ? 'Grupo único' : curso.grupo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.contenedor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${curso.totalEstudiantes} estudiantes',
                                  style: texto.labelSmall?.copyWith(color: AppColors.primario)),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz, color: AppColors.contorno),
                              onSelected: (_) => alCambiarEstado(),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'estado',
                                  child: Text(curso.activo ? 'Archivar curso' : 'Reactivar curso'),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // ---------- Días, salón y horario ----------
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Una línea si todos los días tienen la misma hora,
                              // o una por día si las duraciones son distintas
                              for (final linea in curso.lineasHorario) ...[
                                _linea(texto, Icons.event_outlined, linea,
                                    color: AppColors.verde, negrita: true),
                                const SizedBox(height: 4),
                              ],
                              _linea(texto, Icons.meeting_room_outlined,
                                  curso.salon.isEmpty ? 'Sin salón' : curso.salon),
                              const SizedBox(height: 12),

                              // ---------- Asistencia acumulada ----------
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: curso.activo ? AppColors.campo : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child:
                                              Text('Asistencia acumulada', style: texto.labelSmall),
                                        ),
                                        Text(
                                          asistencia == null
                                              ? 'Sin clases'
                                              : '${(asistencia * 100).round()}%',
                                          style: texto.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: asistencia == null
                                                ? AppColors.contorno
                                                : AppColors.verde,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: asistencia ?? 0,
                                        minHeight: 8,
                                        backgroundColor: const Color(0xFFDCE9FF),
                                        color: AppColors.verde,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ---------- Acciones ----------
                              if (curso.activo) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _boton(
                                        texto,
                                        'Ver detalle',
                                        Icons.visibility_outlined,
                                        alVerDetalle,
                                        principal: false,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _boton(
                                        texto,
                                        curso.sesionAbiertaId == null ? 'Pasar lista' : 'Ver sesión',
                                        curso.sesionAbiertaId == null
                                            ? Icons.checklist
                                            : Icons.qr_code_scanner,
                                        alPasarLista,
                                        principal: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linea(TextTheme texto, IconData icono, String t, {Color? color, bool negrita = false}) {
    final c = color ?? AppColors.textoSecundario;
    return Row(
      children: [
        Icon(icono, size: 16, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texto.bodySmall?.copyWith(
              color: c,
              fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _boton(TextTheme texto, String t, IconData icono, VoidCallback alTocar,
      {required bool principal}) {
    return TextButton.icon(
      onPressed: alTocar,
      style: TextButton.styleFrom(
        backgroundColor: principal ? AppColors.primario : const Color(0xFFDCE9FF),
        foregroundColor: principal ? Colors.white : AppColors.primario,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: texto.labelMedium,
      ),
      icon: Icon(icono, size: 18),
      label: Text(t),
    );
  }
}
