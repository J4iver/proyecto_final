import 'package:flutter/material.dart';
import '../models/resumen.dart';
import '../theme/app_theme.dart';
import 'tarjeta.dart';

const _vino = Color(0xFF9B0015);

String textoNivel(Nivel n) {
  switch (n) {
    case Nivel.excelente:
      return 'Excelente';
    case Nivel.cumple:
      return 'Cumple el mínimo';
    case Nivel.atencion:
      return 'Atención: cerca del 80%';
    case Nivel.bajo:
      return 'Por debajo del 80%';
    case Nivel.sinDatos:
      return 'Sin clases aún';
  }
}

Color colorNivel(Nivel n) {
  switch (n) {
    case Nivel.excelente:
    case Nivel.cumple:
      return AppColors.verde;
    case Nivel.atencion:
      return _vino;
    case Nivel.bajo:
      return AppColors.error;
    case Nivel.sinDatos:
      return AppColors.contorno;
  }
}

/// Píldora con el estado de asistencia de un curso.
class PildoraNivel extends StatelessWidget {
  final Nivel nivel;
  const PildoraNivel(this.nivel, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = colorNivel(nivel);
    return Pildora(textoNivel(nivel),
        fondo: color.withValues(alpha: 0.14), color: color, icono: Icons.circle);
  }
}

/// Anillo con el porcentaje de asistencia en el centro.
class AnilloAsistencia extends StatelessWidget {
  final double? valor; // entre 0 y 1, o null si no hay datos
  final double tamano;
  final Color? color;

  const AnilloAsistencia({super.key, required this.valor, this.tamano = 80, this.color});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final v = valor;
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: v ?? 0,
            strokeWidth: tamano * 0.1,
            strokeCap: StrokeCap.round,
            backgroundColor: const Color(0xFFDCE9FF),
            color: color ?? AppColors.primarioContenedor,
          ),
          Center(
            child: Text(
              v == null ? '–' : '${(v * 100).round()}%',
              style: texto.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: tamano * 0.24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso redondeada.
class BarraAsistencia extends StatelessWidget {
  final double? valor;
  final Color color;
  const BarraAsistencia({super.key, required this.valor, this.color = AppColors.verde});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: valor ?? 0,
        minHeight: 8,
        backgroundColor: AppColors.contenedor,
        color: color,
      ),
    );
  }
}
