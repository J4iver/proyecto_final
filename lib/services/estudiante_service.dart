import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/curso.dart';
import '../models/sesion.dart';
import 'auth_service.dart';
import 'ubicacion_service.dart';

/// Lo que se muestra en la pantalla de confirmación.
class ResultadoMarca {
  final Curso curso;
  final Sesion sesion;
  final DateTime hora;
  final String metodo; // 'qr' o 'codigo'
  final double? distancia; // metros hasta el docente, si se validó el GPS

  const ResultadoMarca({
    required this.curso,
    required this.sesion,
    required this.hora,
    required this.metodo,
    this.distancia,
  });
}

/// Motivo por el que no se pudo registrar la asistencia.
class MarcaError implements Exception {
  final String mensaje;
  MarcaError(this.mensaje);
  @override
  String toString() => mensaje;
}

class EstudianteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _curso(String id) => _db.collection('cursos').doc(id);

  /// Cursos activos en los que aparece el código del estudiante.
  Stream<List<Curso>> misCursos(String codigo) {
    return _db
        .collection('cursos')
        .where('codigosEstudiantes', arrayContains: codigo)
        .snapshots()
        .map((snap) {
      final lista = snap.docs.map(Curso.fromDoc).where((c) => c.activo).toList();
      lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return lista;
    });
  }

  /// Todos los registros de asistencia del estudiante, en todos sus cursos.
  /// Es una consulta de "grupo de colecciones": busca en las subcolecciones
  /// `asistencias` de todas las sesiones a la vez. Necesita un índice en Firebase.
  Stream<List<RegistroAsistencia>> misAsistencias(String codigo) {
    return _db
        .collectionGroup('asistencias')
        .where('codigo', isEqualTo: codigo)
        .snapshots()
        .map((snap) => snap.docs.map(RegistroAsistencia.fromDoc).toList());
  }

  // ---------- Marcar con QR ----------

  /// Registra la asistencia a partir del texto leído del QR.
  Future<ResultadoMarca> marcarConQr(Usuario estudiante, String contenido) async {
    final partes = contenido.split('|');
    if (partes.length != 4 || partes[0] != 'APPSISTENCIA') {
      throw MarcaError('Ese código QR no es de Appsistencia.');
    }
    final cursoId = partes[1];
    final sesionId = partes[2];
    final token = partes[3];

    final (curso, sesion) = await _leerYValidar(estudiante, cursoId, sesionId);

    if (token != sesion.token && token != sesion.tokenAnterior) {
      throw MarcaError('Ese QR ya venció. Escanea el que está en pantalla en este momento.');
    }

    // GPS: se compara con la ubicación que guardó el docente al abrir la sesión
    double? distancia;
    final lat = sesion.lat;
    final lng = sesion.lng;
    if (sesion.exigirUbicacion && lat != null && lng != null) {
      final double metros;
      try {
        final yo = await UbicacionService.actual();
        metros = UbicacionService.distancia(lat, lng, yo.latitude, yo.longitude);
      } on UbicacionError catch (e) {
        throw MarcaError('${e.mensaje} Si no funciona, pídele al docente un código.');
      }
      if (metros > sesion.radioMetros) {
        throw MarcaError(
            'Estás a ${metros.round()} m del docente y el máximo es ${sesion.radioMetros} m. '
            'Si estás en el salón, pídele un código.');
      }
      distancia = metros;
    }

    final hora = DateTime.now();
    try {
      await _asistencia(cursoId, sesionId, estudiante.codigo).set({
        ..._datos(estudiante, cursoId, sesionId, hora),
        'metodo': 'qr',
        'token': token,
        if (distancia != null) 'distancia': distancia.round(),
      });
    } on FirebaseException catch (e) {
      throw MarcaError(_errorAlGuardar(e));
    }
    return ResultadoMarca(
        curso: curso, sesion: sesion, hora: hora, metodo: 'qr', distancia: distancia);
  }

  // ---------- Marcar con código de un solo uso ----------

  /// Registra la asistencia con el código de 6 dígitos que dicta el docente.
  /// No pide GPS: el docente lo entrega en persona.
  Future<ResultadoMarca> marcarConCodigo(Usuario estudiante, Curso curso, String pin) async {
    final sesionId = curso.sesionAbiertaId;
    if (sesionId == null) throw MarcaError('Ese curso no tiene una sesión abierta.');

    final (cursoActual, sesion) = await _leerYValidar(estudiante, curso.id, sesionId);
    final refPin = _curso(curso.id).collection('sesiones').doc(sesionId).collection('codigos').doc(pin);
    final hora = DateTime.now();

    // Transacción: quemar el código y registrar la asistencia pasan juntos o no pasan
    String? motivo; // por qué se rechazó el código, si se rechazó
    try {
      await _db.runTransaction((tx) async {
        final doc = await tx.get(refPin);
        final datos = doc.data();
        final expira = (datos?['expira'] as Timestamp?)?.toDate();
        if (!doc.exists || datos == null) {
          motivo = 'Código incorrecto.';
        } else if ((datos['usado'] ?? false) as bool) {
          motivo = 'Ese código ya fue usado.';
        } else if (expira == null || !DateTime.now().isBefore(expira)) {
          motivo = 'Ese código ya venció. Pídele otro al docente.';
        }
        if (motivo != null) throw StateError('codigo rechazado');

        tx.update(refPin, {'usado': true, 'usadoPor': estudiante.codigo});
        tx.set(_asistencia(curso.id, sesionId, estudiante.codigo), {
          ..._datos(estudiante, curso.id, sesionId, hora),
          'metodo': 'codigo',
          'pin': pin,
        });
      });
    } catch (e) {
      final rechazo = motivo;
      if (rechazo != null) throw MarcaError(rechazo);
      if (e is FirebaseException) {
        throw MarcaError(e.code == 'permission-denied' ? 'Código incorrecto.' : _errorAlGuardar(e));
      }
      throw MarcaError('No se pudo registrar la asistencia.');
    }
    return ResultadoMarca(curso: cursoActual, sesion: sesion, hora: hora, metodo: 'codigo');
  }

  // ---------- Comunes ----------

  DocumentReference<Map<String, dynamic>> _asistencia(
          String cursoId, String sesionId, String codigo) =>
      _curso(cursoId).collection('sesiones').doc(sesionId).collection('asistencias').doc(codigo);

  Map<String, dynamic> _datos(Usuario e, String cursoId, String sesionId, DateTime hora) => {
        'cursoId': cursoId,
        'sesionId': sesionId,
        'codigo': e.codigo,
        'nombre': e.nombre,
        'uid': e.uid,
        'estado': 'presente',
        'hora': Timestamp.fromDate(hora),
      };

  /// Revisa lo que aplica a los dos métodos: que el estudiante esté en la lista,
  /// que la sesión siga abierta y que no haya marcado ya.
  Future<(Curso, Sesion)> _leerYValidar(Usuario estudiante, String cursoId, String sesionId) async {
    final DocumentSnapshot<Map<String, dynamic>> docCurso;
    final DocumentSnapshot<Map<String, dynamic>> docSesion;
    final DocumentSnapshot<Map<String, dynamic>> docPrevia;
    try {
      docCurso = await _curso(cursoId).get();
      docSesion = await _curso(cursoId).collection('sesiones').doc(sesionId).get();
      docPrevia = await _asistencia(cursoId, sesionId, estudiante.codigo).get();
    } on FirebaseException {
      throw MarcaError('No se pudo consultar la sesión. Revisa tu conexión.');
    }

    if (!docCurso.exists || !docSesion.exists) {
      throw MarcaError('No se encontró la sesión de ese QR.');
    }
    final codigos = List<String>.from((docCurso.data()?['codigosEstudiantes'] ?? const []) as List);
    if (!codigos.contains(estudiante.codigo)) {
      throw MarcaError('No estás en la lista de este curso. Pídele al docente que te agregue.');
    }

    final curso = Curso.fromDoc(docCurso);
    final sesion = Sesion.fromDoc(docSesion, cursoId);
    if (!sesion.abierta || !DateTime.now().isBefore(sesion.cierraEn)) {
      throw MarcaError('La sesión de asistencia ya está cerrada.');
    }

    final previa = docPrevia.data();
    if (previa != null) {
      throw MarcaError(previa['estado'] == 'presente'
          ? 'Ya habías registrado tu asistencia en esta sesión.'
          : 'El docente te marcó como ausente en esta sesión. Habla con él para corregirlo.');
    }
    return (curso, sesion);
  }

  String _errorAlGuardar(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'No se pudo registrar: el QR venció o la sesión se cerró. Inténtalo de nuevo.';
    }
    if (e.code == 'unavailable') return 'Sin conexión a internet.';
    return 'No se pudo registrar la asistencia (${e.code}).';
  }
}
