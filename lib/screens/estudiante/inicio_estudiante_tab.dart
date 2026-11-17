import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/resumen.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/asistencia_ui.dart';
import '../../widgets/cuenta_regresiva.dart';
import '../../widgets/tarjeta.dart';
import 'con_datos.dart';

class InicioEstudianteTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback alEscanear; // cambia a la pestaña Asistencia
  final VoidCallback alVerCursos; // cambia a la pestaña Cursos

  const InicioEstudianteTab({
    super.key,
    required this.usuario,
    required this.alEscanear,
    required this.alVerCursos,
  });

  @override
  State<InicioEstudianteTab> createState() => _InicioEstudianteTabState();
}

class _InicioEstudianteTabState extends State<InicioEstudianteTab> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca cada minuto para que "En curso" y "En 20 min" no se queden viejos
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
      child: ConDatos(
        usuario: widget.usuario,
        builder: (context, datos) {
          final ahora = DateTime.now();
          final minutosAhora = ahora.hour * 60 + ahora.minute;
          final deHoy = datos.cursos.where((c) => c.bloqueDe(ahora.weekday) != null).toList()
            ..sort((a, b) =>
                a.bloqueDe(ahora.weekday)!.inicio.compareTo(b.bloqueDe(ahora.weekday)!.inicio));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ---------- Saludo ----------
              Text('Hola, ${widget.usuario.primerNombre}', style: texto.headlineLarge),
              const SizedBox(height: 2),
              Text('Estudiante · Semestre ${semestreActual()}', style: texto.bodyMedium),
              const SizedBox(height: 16),

              if (datos.sinHistorial) const AvisoSinHistorial(),

              if (datos.cursos.isEmpty)
                Tarjeta(
                  color: AppColors.campo,
                  child: Text(
                    'Tu código ${widget.usuario.codigo} todavía no está en la lista de ningún curso. '
                    'Pídele a tu docente que te agregue.',
                    style: texto.bodyMedium,
                  ),
                ),

              // ---------- Asistencia abierta ----------
              for (final c in datos.porMarcar) ...[
                _tarjetaAbierta(texto, c, ahora.weekday),
                const SizedBox(height: 12),
              ],

              // ---------- Resumen global ----------
              if (datos.cursos.isNotEmpty) ...[
                _tarjetaResumen(texto, datos),
                const SizedBox(height: 20),

                // ---------- Cursos de hoy ----------
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cursos de hoy', style: texto.titleMedium),
                          Text(formatoDiaLargo(ahora),
                              style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                        ],
                      ),
                    ),
                    Pildora('${deHoy.length} ${deHoy.length == 1 ? 'clase' : 'clases'}',
                        fondo: AppColors.contenedor, color: AppColors.textoSecundario),
                  ],
                ),
                const SizedBox(height: 10),
                if (deHoy.isEmpty)
                  Tarjeta(child: Text('Hoy no tienes clases.', style: texto.bodyMedium)),
                for (final c in deHoy) ...[
                  _tarjetaHoy(texto, c, c.bloqueDe(ahora.weekday)!, minutosAhora),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: widget.alVerCursos,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.campo,
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                    textStyle: texto.labelMedium,
                  ),
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: Text('Ver todos mis cursos (${datos.cursos.length})'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _tarjetaAbierta(TextTheme texto, Curso c, int hoy) {
    final bloque = c.bloqueDe(hoy);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Pildora('ASISTENCIA ABIERTA AHORA',
                  fondo: Color(0x666FFBBE), color: Color(0xFF002113), icono: Icons.circle),
              const Spacer(),
              CuentaRegresiva(cursoId: c.id, sesionId: c.sesionAbiertaId!),
            ],
          ),
          const SizedBox(height: 12),
          Text(c.titulo, style: texto.titleMedium),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Pildora(c.salon,
                  fondo: AppColors.contenedor, color: AppColors.primario, icono: Icons.domain),
              if (bloque != null)
                Pildora(bloque.horas,
                    fondo: AppColors.contenedor,
                    color: AppColors.textoSecundario,
                    icono: Icons.schedule),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.alEscanear,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: const Text('Escanear QR de clase'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen(TextTheme texto, DatosEstudiante datos) {
    final p = datos.porcentaje;
    final cumple = p != null && p >= minimoAsistencia;
    return Tarjeta(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 20, color: AppColors.primario),
              const SizedBox(width: 8),
              Expanded(child: Text('Mi asistencia', style: texto.labelLarge?.copyWith(color: AppColors.texto))),
              if (p != null)
                Pildora(cumple ? 'Cumples el mínimo' : 'Bajo el mínimo',
                    fondo: (cumple ? AppColors.verde : AppColors.error).withValues(alpha: 0.14),
                    color: cumple ? AppColors.verde : AppColors.error,
                    icono: cumple ? Icons.check_circle : Icons.warning_amber),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AnilloAsistencia(valor: p, color: cumple || p == null ? null : AppColors.error),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p == null
                          ? 'Aún no hay clases registradas'
                          : '${(p * 100).toStringAsFixed(1)}% en el semestre',
                      style: texto.labelLarge?.copyWith(color: AppColors.texto),
                    ),
                    Text('El mínimo de la universidad es 80%',
                        style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _mini(texto, '${datos.asistidas}', 'asistencias', AppColors.verde)),
                        const SizedBox(width: 8),
                        Expanded(child: _mini(texto, '${datos.faltas}', 'faltas', AppColors.error)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(TextTheme texto, String numero, String etiqueta, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Container(
              width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(numero, style: texto.labelMedium),
          const SizedBox(width: 4),
          Flexible(
            child: Text(etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaHoy(TextTheme texto, Curso c, BloqueHorario b, int ahora) {
    final String estado;
    final bool enCurso = ahora >= b.inicio && ahora < b.fin;
    if (enCurso) {
      estado = 'En curso';
    } else if (ahora < b.inicio) {
      estado = 'En ${formatoFalta(b.inicio - ahora)}';
    } else {
      estado = 'Terminó';
    }
    final color = colorAsignatura(c.claveAsignatura);

    return Tarjeta(
      child: Row(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                Text('${b.horas} · ${c.salon}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                if (c.docenteNombre.isNotEmpty)
                  Text(c.docenteNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.bodySmall?.copyWith(color: AppColors.contorno)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pildora(estado,
              fondo: enCurso ? AppColors.primarioSuave : AppColors.contenedor,
              color: enCurso ? AppColors.primario : AppColors.textoSecundario),
        ],
      ),
    );
  }
}
