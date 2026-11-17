import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/sesion.dart';
import '../../services/curso_service.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tarjeta.dart';
import 'estudiantes_curso_screen.dart';
import 'historial_screen.dart';
import 'sesion_screen.dart';

class DetalleCursoScreen extends StatefulWidget {
  final String cursoId;
  const DetalleCursoScreen({super.key, required this.cursoId});

  @override
  State<DetalleCursoScreen> createState() => _DetalleCursoScreenState();
}

class _DetalleCursoScreenState extends State<DetalleCursoScreen> {
  final _cursos = CursoService();
  final _tituloCtrl = TextEditingController();
  late final Stream<Curso?> _curso = _cursos.curso(widget.cursoId);
  late final Stream<List<Sesion>> _recientes =
      SesionService().sesionesDelCurso(widget.cursoId, limite: 4);
  bool _iniciando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciar(Curso curso, {required bool cards}) async {
    if (_iniciando) return;
    FocusScope.of(context).unfocus();
    setState(() => _iniciando = true);
    await abrirSesion(context, curso, titulo: _tituloCtrl.text, cards: cards);
    _tituloCtrl.clear();
    if (mounted) setState(() => _iniciando = false);
  }

  Future<void> _cambiarEstado(Curso curso) async {
    final archivar = curso.activo;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(archivar ? '¿Archivar curso?' : '¿Reactivar curso?'),
        content: Text(archivar
            ? 'El curso pasará a Finalizados y ya no aceptará nuevas asistencias. El historial se conserva.'
            : 'El curso volverá a estar activo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(archivar ? 'Archivar' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _cursos.cambiarEstado(curso.id, activo: !archivar);
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return StreamBuilder<Curso?>(
      stream: _curso,
      builder: (context, snapshot) {
        final curso = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.fondo,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: curso == null
                ? null
                : Column(
                    children: [
                      Text(curso.nombre, style: texto.titleMedium),
                      Text(
                        '${curso.grupo.isEmpty ? '' : '${curso.grupo} · '}${curso.totalEstudiantes} estudiantes',
                        style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                      ),
                    ],
                  ),
            actions: [
              if (curso != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (_) => _cambiarEstado(curso),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'estado',
                      child: Text(curso.activo ? 'Archivar curso' : 'Reactivar curso'),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : curso == null
                    ? const Center(child: Text('No se encontró el curso.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _resumen(texto, curso),
                          const SizedBox(height: 12),
                          _filaEstudiantes(texto, curso),
                          const SizedBox(height: 12),
                          if (curso.sesionAbiertaId != null)
                            _sesionEnCurso(texto, curso)
                          else if (curso.activo)
                            _habilitar(texto, curso)
                          else
                            Tarjeta(
                              color: AppColors.campo,
                              child: Text(
                                'Este curso está finalizado. Reactívalo desde el menú ⋯ para tomar asistencia.',
                                style: texto.bodyMedium,
                              ),
                            ),
                          const SizedBox(height: 20),
                          _sesionesRecientes(texto, curso),
                        ],
                      ),
          ),
        );
      },
    );
  }

  // ---------- Resumen ----------

  Widget _resumen(TextTheme texto, Curso curso) {
    final asistencia = curso.asistencia;
    final clases = curso.sesionesCerradas;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (curso.codigo.isNotEmpty) ...[
                Pildora(curso.codigo, fondo: AppColors.primarioSuave, color: AppColors.primario),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(curso.salon,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.labelMedium),
              ),
              Pildora(curso.semestre, fondo: AppColors.contenedor, color: AppColors.textoSecundario),
            ],
          ),
          const SizedBox(height: 8),
          for (final linea in curso.lineasHorario)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.primario),
                  const SizedBox(width: 6),
                  Text(linea, style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: asistencia ?? 0,
                        strokeWidth: 5,
                        backgroundColor: const Color(0xFFDCE9FF),
                        color: AppColors.verde,
                      ),
                      Center(
                        child: Text(
                          asistencia == null ? '–' : '${(asistencia * 100).round()}%',
                          style: texto.labelSmall?.copyWith(color: AppColors.texto),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asistencia == null
                            ? 'Sin clases registradas'
                            : '${(asistencia * 100).toStringAsFixed(1)}% de asistencia',
                        style: texto.titleMedium,
                      ),
                      Text(
                        '$clases ${clases == 1 ? 'clase dada' : 'clases dadas'} este semestre',
                        style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaEstudiantes(TextTheme texto, Curso curso) {
    return Tarjeta(
      padding: EdgeInsets.zero,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.groups_outlined, color: AppColors.primario),
        title: Text('Estudiantes (${curso.totalEstudiantes})',
            style: texto.labelLarge?.copyWith(color: AppColors.texto)),
        subtitle: Text('Ver la lista, agregar o eliminar',
            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.contornoSuave),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EstudiantesCursoScreen(curso: curso)),
        ),
      ),
    );
  }

  // ---------- Sesión ----------

  Widget _sesionEnCurso(TextTheme texto, Curso curso) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Pildora('EN VIVO · SESIÓN EN CURSO',
                fondo: Color(0x666CF8BB), color: Color(0xFF00714D), icono: Icons.circle),
          ),
          const SizedBox(height: 10),
          Text('Hay una sesión de asistencia abierta', style: texto.titleMedium),
          Text('Entra para ver el QR, el progreso y cerrarla.', style: texto.bodySmall),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => abrirSesion(context, curso),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), elevation: 0),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Gestionar sesión activa'),
          ),
        ],
      ),
    );
  }

  Widget _habilitar(TextTheme texto, Curso curso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Habilitar asistencia', style: texto.headlineMedium),
        ),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nombre de la sesión (opcional)', style: texto.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _tituloCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ej. Parcial 2 o Salida al museo',
                  prefixIcon: Icon(Icons.edit_note, size: 20),
                ),
              ),
              const SizedBox(height: 4),
              Text('Si lo dejas vacío queda como "Clase normal".',
                  style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
              const SizedBox(height: 16),

              // ---------- QR ----------
              _opcion(
                texto,
                icono: Icons.qr_code_2,
                titulo: 'Código QR dinámico',
                descripcion: 'Los estudiantes escanean desde su celular. '
                    'El código cambia cada ${SesionService.segundosQr} segundos.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _iniciando ? null : () => _iniciar(curso, cards: false),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), elevation: 0),
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Iniciar con QR'),
              ),
              const Divider(height: 32, color: AppColors.contenedor),

              // ---------- Cards ----------
              _opcion(
                texto,
                icono: Icons.style_outlined,
                titulo: 'Llamado por cards',
                descripcion: 'Llamas a lista uno por uno: deslizas hacia arriba si está '
                    'y hacia la izquierda si no llegó.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _iniciando ? null : () => _iniciar(curso, cards: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primario,
                  backgroundColor: const Color(0xFFDCE9FF),
                  side: BorderSide.none,
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                  textStyle: texto.labelLarge,
                ),
                icon: const Icon(Icons.swipe_up_outlined, size: 20),
                label: const Text('Iniciar modo cards'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _opcion(TextTheme texto,
      {required IconData icono, required String titulo, required String descripcion}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primarioSuave,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icono, size: 26, color: AppColors.primario),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: texto.titleMedium),
              Text(descripcion, style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Sesiones recientes ----------

  Widget _sesionesRecientes(TextTheme texto, Curso curso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Sesiones recientes', style: texto.titleMedium),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistorialScreen(curso: curso)),
              ),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        StreamBuilder<List<Sesion>>(
          stream: _recientes,
          builder: (context, snapshot) {
            final sesiones = snapshot.data ?? const <Sesion>[];
            if (sesiones.isEmpty) {
              return Tarjeta(
                child: Text(
                  snapshot.hasData
                      ? 'Aún no se ha tomado asistencia en este curso.'
                      : 'Cargando sesiones…',
                  style: texto.bodyMedium,
                ),
              );
            }
            return Tarjeta(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < sesiones.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.campo),
                    FilaSesion(curso: curso, sesion: sesiones[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
