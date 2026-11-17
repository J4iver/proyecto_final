import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/resumen.dart';
import '../../models/sesion.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/tarjeta.dart';
import 'con_datos.dart';

/// "Sesiones asistidas": todos los registros del estudiante, con filtro por curso.
class HistorialEstudiante extends StatefulWidget {
  final Usuario usuario;
  const HistorialEstudiante({super.key, required this.usuario});

  @override
  State<HistorialEstudiante> createState() => _HistorialEstudianteState();
}

class _HistorialEstudianteState extends State<HistorialEstudiante> {
  String? _cursoId; // null = todos los cursos

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ConDatos(
      usuario: widget.usuario,
      builder: (context, datos) {
        final porId = {for (final c in datos.cursos) c.id: c};
        // Solo cuentan los registros de cursos en los que sigue inscrito
        final asistidas = datos.registros
            .where((r) => r.presente && porId.containsKey(r.cursoId))
            .where((r) => _cursoId == null || r.cursoId == _cursoId)
            .toList()
          ..sort((a, b) => b.hora.compareTo(a.hora));

        final seleccionado = _cursoId == null ? null : porId[_cursoId];
        final int hechas;
        final int total;
        if (seleccionado != null) {
          final r = datos.resumen(seleccionado);
          hechas = r.asistidas;
          total = r.total;
        } else {
          hechas = datos.asistidas;
          total = datos.total;
        }
        final double? porcentaje = total == 0 ? null : hechas / total;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (datos.sinHistorial) const AvisoSinHistorial(),

            // ---------- Resumen ----------
            Row(
              children: [
                Expanded(
                  child: _cifra(
                    texto,
                    'Asistencia',
                    porcentaje == null ? '–' : '${(porcentaje * 100).round()}%',
                    porcentaje == null
                        ? 'Sin clases'
                        : porcentaje >= minimoAsistencia
                            ? 'Cumple'
                            : 'Bajo el 80%',
                    porcentaje != null && porcentaje < minimoAsistencia
                        ? AppColors.error
                        : AppColors.primario,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: _cifra(texto, 'Asistidas', '$hechas', 'de $total', AppColors.texto)),
                const SizedBox(width: 8),
                Expanded(
                    child: _cifra(texto, 'Faltas', '${total - hechas}', 'en el semestre',
                        AppColors.texto)),
              ],
            ),
            const SizedBox(height: 16),

            // ---------- Filtro por curso ----------
            if (datos.cursos.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(texto, 'Todos los cursos', null),
                    for (final c in datos.cursos) _chip(texto, c.nombre, c.id),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Text('Historial de registro', style: texto.titleMedium),
            const SizedBox(height: 8),
            if (asistidas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Aún no tienes asistencias registradas.',
                    textAlign: TextAlign.center, style: texto.bodyMedium),
              ),
            for (final r in asistidas) _fila(texto, r, porId[r.cursoId]!),
          ],
        );
      },
    );
  }

  Widget _cifra(TextTheme texto, String etiqueta, String valor, String pie, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(etiqueta, style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
          Text(valor,
              style: texto.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(pie,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
        ],
      ),
    );
  }

  Widget _chip(TextTheme texto, String t, String? cursoId) {
    final activo = _cursoId == cursoId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(t),
        selected: activo,
        onSelected: (_) => setState(() => _cursoId = cursoId),
        showCheckmark: false,
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFDCE9FF),
        selectedColor: AppColors.primario,
        labelStyle:
            texto.labelMedium?.copyWith(color: activo ? Colors.white : AppColors.textoSecundario),
      ),
    );
  }

  Widget _fila(TextTheme texto, RegistroAsistencia r, Curso c) {
    final esHoy = DateUtils.isSameDay(r.hora, DateTime.now());
    final color = colorAsignatura(c.claveAsignatura);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tarjeta(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.auto_stories_outlined, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nombre,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.titleMedium),
                      Text(
                        c.docenteNombre.isEmpty ? c.salon : '${c.salon} · ${c.docenteNombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Pildora('Presente',
                    fondo: Color(0xFF6CF8BB), color: Color(0xFF00714D), icono: Icons.circle),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.campo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(r.metodo == 'qr' ? Icons.qr_code_2 : Icons.how_to_reg,
                      size: 18, color: AppColors.verde),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.metodoTexto, style: texto.labelMedium)),
                  Text(
                    esHoy ? 'Hoy, ${formatoHoraDia(r.hora)}' : formatoFecha(r.hora),
                    style: texto.labelSmall
                        ?.copyWith(color: esHoy ? AppColors.primario : AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
