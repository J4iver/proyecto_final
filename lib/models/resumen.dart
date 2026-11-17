import 'curso.dart';
import 'sesion.dart';

/// Mínimo de asistencia que exige la universidad.
const minimoAsistencia = 0.80;

enum Nivel { sinDatos, excelente, cumple, atencion, bajo }

/// Asistencia de un estudiante en un curso.
class ResumenCurso {
  final Curso curso;
  final int asistidas;
  final int total; // sesiones que cuentan

  const ResumenCurso({required this.curso, required this.asistidas, required this.total});

  int get faltas => total - asistidas;

  /// Entre 0 y 1, o null si el curso aún no tiene clases.
  double? get porcentaje => total == 0 ? null : asistidas / total;

  Nivel get nivel {
    final p = porcentaje;
    if (p == null) return Nivel.sinDatos;
    if (p < minimoAsistencia) return Nivel.bajo;
    if (p < minimoAsistencia + 0.05) return Nivel.atencion; // a menos de 5 puntos del mínimo
    if (p >= 0.95) return Nivel.excelente;
    return Nivel.cumple;
  }

  bool get conAlerta => nivel == Nivel.bajo || nivel == Nivel.atencion;
}

/// Todo lo que las pantallas del estudiante necesitan: sus cursos y sus registros.
class DatosEstudiante {
  final List<Curso> cursos;
  final List<RegistroAsistencia> registros;
  final bool sinHistorial; // true si no se pudieron cargar los registros

  const DatosEstudiante({
    required this.cursos,
    required this.registros,
    this.sinHistorial = false,
  });

  /// Registro del estudiante en una sesión, si existe.
  RegistroAsistencia? registroDe(String sesionId) {
    for (final r in registros) {
      if (r.sesionId == sesionId) return r;
    }
    return null;
  }

  ResumenCurso resumen(Curso curso) {
    final asistidas = registros.where((r) => r.cursoId == curso.id && r.presente).length;
    // Cuentan las sesiones ya cerradas. Si el estudiante marcó en una que sigue
    // abierta, esa también cuenta para que el número no quede por encima del total.
    final total = asistidas > curso.sesionesCerradas ? asistidas : curso.sesionesCerradas;
    return ResumenCurso(curso: curso, asistidas: asistidas, total: total);
  }

  List<ResumenCurso> get resumenes => cursos.map(resumen).toList();

  int get asistidas => resumenes.fold(0, (a, r) => a + r.asistidas);
  int get total => resumenes.fold(0, (a, r) => a + r.total);
  int get faltas => total - asistidas;
  double? get porcentaje => total == 0 ? null : asistidas / total;

  /// Cursos con sesión abierta en la que el estudiante todavía no ha marcado.
  List<Curso> get porMarcar => cursos.where((c) {
        final sesionId = c.sesionAbiertaId;
        return sesionId != null && registroDe(sesionId) == null;
      }).toList();
}
