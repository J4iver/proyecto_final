import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/formato.dart';

/// Un estudiante dentro de la lista de un curso.
/// Se identifica por su código, tenga o no cuenta en la app.
class EstudianteCurso {
  final String codigo;
  final String nombre;
  final String email;
  final String programa;

  const EstudianteCurso({
    required this.codigo,
    required this.nombre,
    this.email = '',
    this.programa = '',
  });

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'email': email,
        'programa': programa,
      };

  factory EstudianteCurso.fromMap(Map<String, dynamic> m) => EstudianteCurso(
        codigo: (m['codigo'] ?? '') as String,
        nombre: (m['nombre'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        programa: (m['programa'] ?? '') as String,
      );
}

/// Una clase de la semana: un día con su hora de inicio y de fin.
/// Cada día puede tener una duración distinta.
class BloqueHorario {
  final int dia; // 1 = lunes ... 6 = sábado (igual que DateTime.weekday)
  final int inicio; // minutos desde medianoche
  final int fin;

  const BloqueHorario({required this.dia, required this.inicio, required this.fin});

  Map<String, dynamic> toMap() => {'dia': dia, 'inicio': inicio, 'fin': fin};

  factory BloqueHorario.fromMap(Map<String, dynamic> m) => BloqueHorario(
        dia: (m['dia'] ?? 1) as int,
        inicio: (m['inicio'] ?? 0) as int,
        fin: (m['fin'] ?? 0) as int,
      );

  BloqueHorario copiar({int? inicio, int? fin}) =>
      BloqueHorario(dia: dia, inicio: inicio ?? this.inicio, fin: fin ?? this.fin);

  /// "08:00 - 10:00"
  String get horas => '${formatoHora(inicio)} - ${formatoHora(fin)}';
}

/// Un curso = una asignatura + un grupo, con su horario.
class Curso {
  static const nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  static const nombresDiasLargos = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  final String id;
  final String nombre;
  final String codigo;
  final String grupo;
  final String salon;
  final List<BloqueHorario> horario; // un bloque por día de clase, ordenado por día
  final String docenteId;
  final String docenteNombre;
  final bool activo;
  final String semestre;
  final int totalEstudiantes;
  final bool exigirUbicacion;
  final int radioMetros;
  final int sumaPresentes; // se actualizan al cerrar cada sesión
  final int sumaEsperados;
  final int sesionesCerradas; // clases dadas
  final String? sesionAbiertaId; // id de la sesión de asistencia en curso, si hay

  const Curso({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.grupo,
    required this.salon,
    required this.horario,
    required this.docenteId,
    required this.docenteNombre,
    required this.activo,
    required this.semestre,
    required this.totalEstudiantes,
    required this.exigirUbicacion,
    required this.radioMetros,
    required this.sumaPresentes,
    required this.sumaEsperados,
    required this.sesionesCerradas,
    required this.sesionAbiertaId,
  });

  factory Curso.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};

    // Horario: un bloque por día. Los cursos creados antes de este cambio
    // tenían una sola hora para todos los días; se convierten aquí.
    List<BloqueHorario> horario;
    if (m['horario'] is List) {
      horario = (m['horario'] as List)
          .map((b) => BloqueHorario.fromMap(Map<String, dynamic>.from(b as Map)))
          .toList();
    } else {
      final inicio = (m['horaInicio'] ?? 0) as int;
      final fin = (m['horaFin'] ?? 0) as int;
      horario = List<int>.from((m['dias'] ?? const <int>[]) as List)
          .map((d) => BloqueHorario(dia: d, inicio: inicio, fin: fin))
          .toList();
    }
    horario.sort((a, b) => a.dia.compareTo(b.dia));

    return Curso(
      id: doc.id,
      nombre: (m['nombre'] ?? '') as String,
      codigo: (m['codigo'] ?? '') as String,
      grupo: (m['grupo'] ?? '') as String,
      salon: (m['salon'] ?? '') as String,
      horario: horario,
      docenteId: (m['docenteId'] ?? '') as String,
      docenteNombre: (m['docenteNombre'] ?? '') as String,
      activo: (m['activo'] ?? true) as bool,
      semestre: (m['semestre'] ?? '') as String,
      totalEstudiantes: (m['totalEstudiantes'] ?? 0) as int,
      exigirUbicacion: (m['exigirUbicacion'] ?? false) as bool,
      radioMetros: (m['radioMetros'] ?? 50) as int,
      sumaPresentes: (m['sumaPresentes'] ?? 0) as int,
      sumaEsperados: (m['sumaEsperados'] ?? 0) as int,
      sesionesCerradas: (m['sesionesCerradas'] ?? 0) as int,
      sesionAbiertaId: m['sesionAbiertaId'] as String?,
    );
  }

  /// "Programación II - Grupo A"
  String get titulo => grupo.isEmpty ? nombre : '$nombre - $grupo';

  /// Clave para agrupar los grupos de una misma asignatura.
  String get claveAsignatura => '${codigo.toUpperCase()}|${nombre.toLowerCase()}';

  List<int> get dias => horario.map((b) => b.dia).toList();

  /// El bloque de un día de la semana (DateTime.weekday), o null si ese día no hay clase.
  BloqueHorario? bloqueDe(int diaSemana) {
    for (final b in horario) {
      if (b.dia == diaSemana) return b;
    }
    return null;
  }

  /// true si todos los días tienen la misma hora de inicio y de fin.
  bool get horarioUniforme =>
      horario.every((b) => b.inicio == horario.first.inicio && b.fin == horario.first.fin);

  /// "Lun y Mié", "Lun, Mié y Vie"
  String get diasTexto {
    final n = horario.map((b) => nombresDias[b.dia - 1]).toList();
    if (n.isEmpty) return 'Sin días';
    if (n.length == 1) return n.first;
    return '${n.sublist(0, n.length - 1).join(', ')} y ${n.last}';
  }

  /// Horario listo para mostrar.
  /// Misma hora todos los días: ["Mar y Jue · 08:00 - 10:00"]
  /// Horas distintas: ["Mar · 08:00 - 10:00", "Jue · 08:00 - 11:00"]
  List<String> get lineasHorario {
    if (horario.isEmpty) return const ['Sin horario'];
    if (horarioUniforme) return ['$diasTexto · ${horario.first.horas}'];
    return [for (final b in horario) '${nombresDias[b.dia - 1]} · ${b.horas}'];
  }

  /// Asistencia acumulada entre 0 y 1, o null si aún no hay clases cerradas.
  double? get asistencia => sumaEsperados == 0 ? null : sumaPresentes / sumaEsperados;
}
