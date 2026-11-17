import 'package:flutter/material.dart';

/// Iniciales de un nombre: "Laura Gómez Castillo" -> "LG".
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}

/// Minutos desde medianoche a texto: 480 -> "08:00".
String formatoHora(int minutos) {
  final h = (minutos ~/ 60).toString().padLeft(2, '0');
  final m = (minutos % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Semestre según la fecha: enero-junio es I, julio-diciembre es II.
String semestreActual([DateTime? fecha]) {
  final f = fecha ?? DateTime.now();
  return '${f.year}-${f.month <= 6 ? 'I' : 'II'}';
}

const _paleta = [
  Color(0xFF1E40AF), // azul
  Color(0xFF006C49), // verde
  Color(0xFF9B0015), // vino
  Color(0xFF5B3FA8), // violeta
  Color(0xFF8A5A00), // ocre
];

/// Color fijo para cada asignatura, calculado a partir de su código.
/// Así todos los grupos de la misma asignatura comparten color.
Color colorAsignatura(String clave) {
  final suma = clave.toUpperCase().codeUnits.fold<int>(0, (a, b) => a + b);
  return _paleta[suma % _paleta.length];
}

/// Duración como reloj: 14 min 5 s -> "14:05". Nunca baja de 00:00.
String formatoReloj(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Hora de una fecha: "08:05".
String formatoHoraDia(DateTime f) => formatoHora(f.hour * 60 + f.minute);

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Fecha corta: "15 nov 2026 · 08:05".
String formatoFecha(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year} · ${formatoHoraDia(f)}';

const _diasLargos = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Fecha larga: "Lunes, 16 de noviembre".
String formatoDiaLargo(DateTime f) =>
    '${_diasLargos[f.weekday - 1]}, ${f.day} de ${_mesesLargos[f.month - 1]}';

/// Fecha sin hora: "16 nov".
String formatoDiaCorto(DateTime f) => '${f.day} ${_meses[f.month - 1]}';

/// Cuánto falta, en palabras: "45 min", "1 h 30 min".
String formatoFalta(int minutos) {
  if (minutos < 60) return '$minutos min';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}
