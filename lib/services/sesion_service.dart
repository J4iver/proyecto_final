import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/curso.dart';
import '../models/sesion.dart';

class SesionService {
  static const duracionMinutos = 15; // la sesión se cierra sola a los 15 minutos
  static const extraMinutos = 5; // lo que suma el botón "+5 min"
  static const segundosQr = 15; // cada cuánto cambia el QR
  static const minutosCodigo = 5; // validez del código de un solo uso

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _azar = Random.secure();

  DocumentReference<Map<String, dynamic>> _curso(String cursoId) =>
      _db.collection('cursos').doc(cursoId);

  DocumentReference<Map<String, dynamic>> _sesion(String cursoId, String sesionId) =>
      _curso(cursoId).collection('sesiones').doc(sesionId);

  String _nuevoToken() {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(10, (_) => letras[_azar.nextInt(letras.length)]).join();
  }

  // ---------- Sesiones ----------

  /// Abre una sesión de asistencia. Si el curso ya tiene una abierta, devuelve esa.
  /// [lat] y [lng] son la ubicación del docente; si vienen, se valida el GPS del estudiante.
  Future<String> iniciar(
    Curso curso, {
    String titulo = '',
    String modo = 'qr',
    double? lat,
    double? lng,
  }) async {
    final abierta = curso.sesionAbiertaId;
    if (abierta != null) return abierta;

    final ref = _curso(curso.id).collection('sesiones').doc();
    final ahora = DateTime.now();
    final lote = _db.batch();
    lote.set(ref, {
      'titulo': titulo.trim(),
      'modo': modo,
      'docenteId': _auth.currentUser!.uid,
      'inicio': Timestamp.fromDate(ahora),
      'cierraEn': Timestamp.fromDate(ahora.add(const Duration(minutes: duracionMinutos))),
      'abierta': true,
      'token': _nuevoToken(),
      'tokenAnterior': '',
      'tokenEn': Timestamp.fromDate(ahora),
      'total': curso.totalEstudiantes,
      'presentes': 0,
      'exigirUbicacion': curso.exigirUbicacion && lat != null && lng != null,
      'radioMetros': curso.radioMetros,
      'lat': lat,
      'lng': lng,
    });
    lote.update(_curso(curso.id), {
      'sesionAbiertaId': ref.id,
      // Los cursos creados antes no tenían el nombre del docente: se completa aquí
      'docenteNombre': _auth.currentUser!.displayName ?? curso.docenteNombre,
    });
    await lote.commit();
    return ref.id;
  }

  Stream<Sesion?> sesion(String cursoId, String sesionId) {
    return _sesion(cursoId, sesionId)
        .snapshots()
        .map((d) => d.exists ? Sesion.fromDoc(d, cursoId) : null);
  }

  /// Sesiones del curso, de la más reciente a la más antigua.
  Stream<List<Sesion>> sesionesDelCurso(String cursoId, {int? limite}) {
    Query<Map<String, dynamic>> consulta =
        _curso(cursoId).collection('sesiones').orderBy('inicio', descending: true);
    if (limite != null) consulta = consulta.limit(limite);
    return consulta
        .snapshots()
        .map((snap) => snap.docs.map((d) => Sesion.fromDoc(d, cursoId)).toList());
  }

  /// Cambia el token del QR. El anterior se guarda un momento,
  /// por si alguien escaneó justo antes del cambio.
  Future<void> rotarToken(String cursoId, String sesionId, String tokenActual) {
    return _sesion(cursoId, sesionId).update({
      'token': _nuevoToken(),
      'tokenAnterior': tokenActual,
      'tokenEn': Timestamp.now(),
    });
  }

  /// Da más tiempo a la sesión.
  Future<void> extender(Sesion s) {
    final base = s.cierraEn.isAfter(DateTime.now()) ? s.cierraEn : DateTime.now();
    return _sesion(s.cursoId, s.id).update({
      'cierraEn': Timestamp.fromDate(base.add(const Duration(minutes: extraMinutos))),
    });
  }

  /// Cierra la sesión y suma sus números a la asistencia acumulada del curso.
  /// Quien no quedó como presente cuenta como ausente.
  Future<void> cerrar({
    required String cursoId,
    required String sesionId,
    required int presentes,
    required int total,
  }) {
    final lote = _db.batch();
    lote.update(_sesion(cursoId, sesionId), {
      'abierta': false,
      'cerradaEn': Timestamp.now(),
      'presentes': presentes,
      'total': total,
    });
    lote.update(_curso(cursoId), {
      'sesionAbiertaId': FieldValue.delete(),
      'sumaPresentes': FieldValue.increment(presentes),
      'sumaEsperados': FieldValue.increment(total),
      'sesionesCerradas': FieldValue.increment(1),
    });
    return lote.commit();
  }

  // ---------- Asistencias ----------

  Stream<List<Asistencia>> asistencias(String cursoId, String sesionId) {
    return _sesion(cursoId, sesionId)
        .collection('asistencias')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Asistencia.fromMap(d.data())).toList());
  }

  /// Marca a un estudiante como presente o ausente (lo hace el docente).
  Future<void> marcar(
    String cursoId,
    String sesionId,
    EstudianteCurso e, {
    required bool presente,
    required String metodo,
  }) {
    return _sesion(cursoId, sesionId).collection('asistencias').doc(e.codigo).set({
      'cursoId': cursoId,
      'sesionId': sesionId,
      'codigo': e.codigo,
      'nombre': e.nombre,
      'estado': presente ? 'presente' : 'ausente',
      'metodo': metodo,
      'hora': Timestamp.now(),
    });
  }

  /// Quita la marca: el estudiante vuelve a quedar pendiente.
  Future<void> desmarcar(String cursoId, String sesionId, String codigo) {
    return _sesion(cursoId, sesionId).collection('asistencias').doc(codigo).delete();
  }

  // ---------- Códigos de un solo uso ----------

  /// Crea un código de 6 dígitos válido por 5 minutos y para un solo estudiante.
  Future<({String codigo, DateTime expira})> generarCodigo(String cursoId, String sesionId) async {
    final codigo = _azar.nextInt(1000000).toString().padLeft(6, '0');
    final expira = DateTime.now().add(const Duration(minutes: minutosCodigo));
    await _sesion(cursoId, sesionId).collection('codigos').doc(codigo).set({
      'usado': false,
      'expira': Timestamp.fromDate(expira),
      'creadoEn': Timestamp.now(),
    });
    return (codigo: codigo, expira: expira);
  }

  /// true cuando el código ya fue canjeado por un estudiante.
  Stream<bool> codigoUsado(String cursoId, String sesionId, String codigo) {
    return _sesion(cursoId, sesionId)
        .collection('codigos')
        .doc(codigo)
        .snapshots()
        .map((d) => (d.data()?['usado'] ?? false) as bool);
  }
}
