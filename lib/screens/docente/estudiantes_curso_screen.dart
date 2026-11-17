import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../services/curso_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/dialogo_estudiante.dart';

/// Lista de estudiantes de un curso: agregar o eliminar a mano.
class EstudiantesCursoScreen extends StatefulWidget {
  final Curso curso;
  const EstudiantesCursoScreen({super.key, required this.curso});

  @override
  State<EstudiantesCursoScreen> createState() => _EstudiantesCursoScreenState();
}

class _EstudiantesCursoScreenState extends State<EstudiantesCursoScreen> {
  final _servicio = CursoService();
  late final Stream<List<EstudianteCurso>> _estudiantes = _servicio.estudiantes(widget.curso.id);

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _agregar(List<EstudianteCurso> actuales) async {
    final nuevo = await showDialog<EstudianteCurso>(
      context: context,
      builder: (_) => DialogoEstudiante(
        codigosExistentes: actuales.map((e) => e.codigo).toSet(),
      ),
    );
    if (nuevo == null) return;
    try {
      await _servicio.agregarEstudiante(widget.curso.id, nuevo);
      _aviso('${nuevo.nombre} se agregó al curso.');
    } catch (_) {
      _aviso('No se pudo agregar al estudiante.');
    }
  }

  Future<void> _eliminar(EstudianteCurso e) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar del curso?'),
        content: Text('${e.nombre} ya no aparecerá en la lista. '
            'Sus asistencias anteriores se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _servicio.eliminarEstudiante(widget.curso.id, e.codigo);
    } catch (_) {
      _aviso('No se pudo eliminar al estudiante.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return StreamBuilder<List<EstudianteCurso>>(
      stream: _estudiantes,
      builder: (context, snapshot) {
        final lista = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.fondo,
            surfaceTintColor: Colors.transparent,
            title: Text('Estudiantes', style: texto.titleMedium),
            centerTitle: true,
          ),
          floatingActionButton: lista == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _agregar(lista),
                  backgroundColor: AppColors.primarioContenedor,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Agregar'),
                ),
          body: SafeArea(
            top: false,
            child: lista == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      Text(widget.curso.titulo, style: texto.headlineMedium),
                      Text('${lista.length} estudiantes', style: texto.bodyMedium),
                      const SizedBox(height: 12),
                      if (lista.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text('Este curso aún no tiene estudiantes.',
                              textAlign: TextAlign.center, style: texto.bodyMedium),
                        ),
                      for (final e in lista)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primarioSuave,
                                child: Text(iniciales(e.nombre),
                                    style: texto.labelMedium?.copyWith(color: AppColors.primario)),
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
                                    Text(
                                      e.email.isEmpty ? e.codigo : '${e.codigo} · ${e.email}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: texto.bodySmall
                                          ?.copyWith(color: AppColors.textoSecundario),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar del curso',
                                icon: const Icon(Icons.person_remove_outlined,
                                    size: 20, color: AppColors.contorno),
                                onPressed: () => _eliminar(e),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
