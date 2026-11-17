import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/curso.dart';
import '../utils/formato.dart';

class CursoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _porLote = 15;

  CollectionReference<Map<String, dynamic>> get _cursos => _db.collection('cursos');

  /// Cursos del docente que inició sesión, en vivo.
  Stream<List<Curso>> cursosDelDocente() {
    final uid = _auth.currentUser!.uid;
    return _cursos.where('docenteId', isEqualTo: uid).snapshots().map((snap) {
      final lista = snap.docs.map(Curso.fromDoc).toList();
      lista.sort((a, b) {
        final porNombre = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
        return porNombre != 0 ? porNombre : a.grupo.compareTo(b.grupo);
      });
      return lista;
    });
  }

  /// Crea el curso y su lista de estudiantes.
  /// Se guarda por lotes de 15 estudiantes: cada escritura hace que las reglas
  /// de seguridad consulten el curso, y Firestore limita esas consultas por lote.
  Future<void> crearCurso({
    required String nombre,
    required String codigo,
    required String grupo,
    required String salon,
    required List<BloqueHorario> horario,
    required bool exigirUbicacion,
    required int radioMetros,
    required List<EstudianteCurso> estudiantes,
  }) async {
    final uid = _auth.currentUser!.uid;
    final ref = _cursos.doc();
    final List<BloqueHorario> ordenado = List<BloqueHorario>.of(horario);
    ordenado.sort((BloqueHorario a, BloqueHorario b) => a.dia.compareTo(b.dia));
    var lote = _db.batch();

    lote.set(ref, {
      'nombre': nombre.trim(),
      'codigo': codigo.trim().toUpperCase(),
      'grupo': grupo.trim(),
      'salon': salon.trim(),
      // Un bloque por día, cada uno con su propia hora de inicio y de fin
      'horario': [for (final BloqueHorario b in ordenado) b.toMap()],
      // Lista de días aparte: sirve para buscar "cursos que tienen clase hoy"
      'dias': [for (final BloqueHorario b in ordenado) b.dia],
      'docenteId': uid,
      'docenteNombre': _auth.currentUser!.displayName ?? '',
      'activo': true,
      'semestre': semestreActual(),
      'totalEstudiantes': estudiantes.length,
      // Lista de códigos: sirve para que cada estudiante encuentre sus cursos
      'codigosEstudiantes': estudiantes.map((e) => e.codigo).toList(),
      'exigirUbicacion': exigirUbicacion,
      'radioMetros': radioMetros,
      'sumaPresentes': 0,
      'sumaEsperados': 0,
      'sesionesCerradas': 0,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    var enLote = 0;
    for (final e in estudiantes) {
      lote.set(ref.collection('estudiantes').doc(e.codigo), e.toMap());
      enLote++;
      if (enLote == _porLote) {
        await lote.commit();
        lote = _db.batch();
        enLote = 0;
      }
    }
    if (enLote > 0 || estudiantes.isEmpty) await lote.commit();
  }

  /// Un curso en vivo (null si no existe).
  Stream<Curso?> curso(String cursoId) {
    return _cursos.doc(cursoId).snapshots().map((d) => d.exists ? Curso.fromDoc(d) : null);
  }

  /// Lista de estudiantes del curso, en vivo y ordenada por nombre.
  Stream<List<EstudianteCurso>> estudiantes(String cursoId) {
    return _cursos.doc(cursoId).collection('estudiantes').snapshots().map(_ordenar);
  }

  /// Lista de estudiantes leída una sola vez.
  Future<List<EstudianteCurso>> leerEstudiantes(String cursoId) async {
    return _ordenar(await _cursos.doc(cursoId).collection('estudiantes').get());
  }

  List<EstudianteCurso> _ordenar(QuerySnapshot<Map<String, dynamic>> snap) {
    final lista = snap.docs.map((d) => EstudianteCurso.fromMap(d.data())).toList();
    lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return lista;
  }

  /// Agrega un estudiante a un curso ya creado.
  Future<void> agregarEstudiante(String cursoId, EstudianteCurso e) {
    final ref = _cursos.doc(cursoId);
    final lote = _db.batch();
    lote.set(ref.collection('estudiantes').doc(e.codigo), e.toMap());
    lote.update(ref, {
      'codigosEstudiantes': FieldValue.arrayUnion([e.codigo]),
      'totalEstudiantes': FieldValue.increment(1),
    });
    return lote.commit();
  }

  /// Quita un estudiante del curso. Sus asistencias anteriores no se borran.
  Future<void> eliminarEstudiante(String cursoId, String codigo) {
    final ref = _cursos.doc(cursoId);
    final lote = _db.batch();
    lote.delete(ref.collection('estudiantes').doc(codigo));
    lote.update(ref, {
      'codigosEstudiantes': FieldValue.arrayRemove([codigo]),
      'totalEstudiantes': FieldValue.increment(-1),
    });
    return lote.commit();
  }

  /// Archiva (activo = false) o reactiva un curso. No borra nada.
  Future<void> cambiarEstado(String cursoId, {required bool activo}) {
    return _cursos.doc(cursoId).update({'activo': activo});
  }
}
