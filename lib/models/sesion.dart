import 'package:cloud_firestore/cloud_firestore.dart';

/// Una sesión de asistencia: una clase en la que se toma lista.
class Sesion {
  final String id;
  final String cursoId;
  final String titulo;
  final String modo; // 'qr' o 'cards': cómo se inició
  final DateTime inicio;
  final DateTime cierraEn; // a esta hora se cierra sola
  final bool abierta;
  final String token; // lo que lleva el QR; cambia cada 15 segundos
  final String tokenAnterior; // el token justo anterior, todavía aceptado
  final bool exigirUbicacion; // si se valida el GPS del estudiante
  final int radioMetros; // distancia máxima al docente
  final double? lat; // ubicación del docente al abrir la sesión
  final double? lng;
  final int total; // estudiantes esperados
  final int presentes; // se guarda al cerrar

  const Sesion({
    required this.id,
    required this.cursoId,
    required this.titulo,
    required this.modo,
    required this.inicio,
    required this.cierraEn,
    required this.abierta,
    required this.token,
    required this.tokenAnterior,
    required this.exigirUbicacion,
    required this.radioMetros,
    required this.lat,
    required this.lng,
    required this.total,
    required this.presentes,
  });

  factory Sesion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc, String cursoId) {
    final m = doc.data() ?? {};
    final inicio = (m['inicio'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Sesion(
      id: doc.id,
      cursoId: cursoId,
      titulo: (m['titulo'] ?? '') as String,
      modo: (m['modo'] ?? 'qr') as String,
      inicio: inicio,
      cierraEn: (m['cierraEn'] as Timestamp?)?.toDate() ?? inicio,
      abierta: (m['abierta'] ?? false) as bool,
      token: (m['token'] ?? '') as String,
      tokenAnterior: (m['tokenAnterior'] ?? '') as String,
      exigirUbicacion: (m['exigirUbicacion'] ?? false) as bool,
      radioMetros: (m['radioMetros'] ?? 50) as int,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      total: (m['total'] ?? 0) as int,
      presentes: (m['presentes'] ?? 0) as int,
    );
  }

  String get tituloVisible => titulo.isEmpty ? 'Clase normal' : titulo;

  /// Texto que va dentro del QR.
  String get contenidoQr => 'APPSISTENCIA|$cursoId|$id|$token';
}

/// El registro de un estudiante en una sesión.
class Asistencia {
  final String codigo;
  final String nombre;
  final String estado; // 'presente' o 'ausente'
  final String metodo; // 'qr', 'codigo', 'manual' o 'cards'
  final DateTime hora;

  const Asistencia({
    required this.codigo,
    required this.nombre,
    required this.estado,
    required this.metodo,
    required this.hora,
  });

  factory Asistencia.fromMap(Map<String, dynamic> m) => Asistencia(
        codigo: (m['codigo'] ?? '') as String,
        nombre: (m['nombre'] ?? '') as String,
        estado: (m['estado'] ?? 'presente') as String,
        metodo: (m['metodo'] ?? 'manual') as String,
        hora: (m['hora'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  bool get presente => estado == 'presente';

  String get metodoTexto {
    switch (metodo) {
      case 'qr':
        return 'QR';
      case 'codigo':
        return 'Código';
      case 'cards':
        return 'Llamado';
      default:
        return 'Manual';
    }
  }
}

/// Un registro de asistencia visto desde el estudiante:
/// además del estado, sabe a qué curso y sesión pertenece.
class RegistroAsistencia {
  final String cursoId;
  final String sesionId;
  final String estado;
  final String metodo;
  final DateTime hora;

  const RegistroAsistencia({
    required this.cursoId,
    required this.sesionId,
    required this.estado,
    required this.metodo,
    required this.hora,
  });

  /// El curso y la sesión se sacan de la ruta del documento:
  /// cursos/{cursoId}/sesiones/{sesionId}/asistencias/{codigo}
  factory RegistroAsistencia.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    final sesionRef = doc.reference.parent.parent;
    final cursoRef = sesionRef?.parent.parent;
    return RegistroAsistencia(
      cursoId: cursoRef?.id ?? (m['cursoId'] ?? '') as String,
      sesionId: sesionRef?.id ?? (m['sesionId'] ?? '') as String,
      estado: (m['estado'] ?? 'presente') as String,
      metodo: (m['metodo'] ?? 'manual') as String,
      hora: (m['hora'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get presente => estado == 'presente';

  String get metodoTexto {
    switch (metodo) {
      case 'qr':
        return 'QR dinámico';
      case 'codigo':
        return 'Código del docente';
      case 'cards':
        return 'Llamado a lista';
      default:
        return 'Marcado por el docente';
    }
  }
}
