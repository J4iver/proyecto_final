import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles de la app. En Firestore se guardan como 'docente' o 'estudiante'.
enum Rol { docente, estudiante }

extension RolTexto on Rol {
  String get etiqueta => this == Rol.docente ? 'Docente' : 'Estudiante';
}

/// Datos del usuario que inició sesión (documento de la colección "usuarios").
class Usuario {
  final String uid;
  final String nombre;
  final String email;
  final String codigo;
  final Rol rol;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.codigo,
    required this.rol,
  });

  /// Primer nombre, para el saludo.
  String get primerNombre => nombre.trim().split(' ').first;
}

/// Error con mensaje en español para mostrar en pantalla.
class AuthError implements Exception {
  final String mensaje;
  AuthError(this.mensaje);
  @override
  String toString() => mensaje;
}

class AuthService {
  static const dominioPermitido = '@udla.edu.co';

  /// Si es true, el estudiante debe abrir el enlace que llega a su correo
  /// antes de poder usar la app. Para probar con correos inventados ponlo en
  /// false (y comenta la línea de "email_verified" en firestore.rules).
  static const exigirCorreoVerificado = true;

  /// Está en true mientras se inicia sesión o se registra.
  /// main.dart espera a que termine antes de mostrar el Home,
  /// así da tiempo de verificar el rol.
  static final ValueNotifier<bool> ocupado = ValueNotifier(false);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get usuarioActual => _auth.currentUser;

  // ---------- Validaciones para los formularios ----------

  static String? validarCorreo(String? valor) {
    final email = valor?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    if (!email.contains('@')) return 'El correo no es válido';
    if (!email.endsWith(dominioPermitido)) {
      return 'Usa tu correo institucional ($dominioPermitido)';
    }
    return null;
  }

  // Reglas de la contraseña (las usa también la lista en vivo del registro)
  static bool tieneLargo(String v) => v.length >= 8;
  static bool tieneMayuscula(String v) => v.contains(RegExp(r'[A-Z]'));
  static bool tieneNumero(String v) => v.contains(RegExp(r'[0-9]'));

  static String? validarContrasena(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (!tieneLargo(v) || !tieneMayuscula(v) || !tieneNumero(v)) {
      return 'Debe tener 8+ caracteres, una mayúscula y un número';
    }
    return null;
  }

  static String? validarCodigo(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu código';
    if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'El código debe tener 10 dígitos';
    return null;
  }

  // ---------- Autenticación ----------

  /// Inicia sesión y verifica que la cuenta tenga el rol elegido.
  Future<void> iniciarSesion(String email, String password, Rol rol) async {
    ocupado.value = true;
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Leer el rol guardado del usuario en Firestore
      final ref = _db.collection('usuarios').doc(cred.user!.uid);
      final doc = await ref.get();
      final rolGuardado = doc.data()?['rol'] as String?;

      if (rolGuardado == null) {
        // Cuenta sin rol (creada antes de agregar roles): se le asigna el elegido
        await ref.set({'rol': rol.name}, SetOptions(merge: true));
      } else if (rolGuardado != rol.name) {
        await _auth.signOut();
        final real = Rol.values.byName(rolGuardado);
        throw AuthError(
            'Esta cuenta está registrada como ${real.etiqueta}. Cambia el rol e inténtalo de nuevo.');
      }
    } on FirebaseAuthException catch (e) {
      throw AuthError(_traducirError(e));
    } on FirebaseException catch (e) {
      await _auth.signOut();
      throw AuthError('Error al consultar la base de datos (${e.code}).');
    } finally {
      ocupado.value = false;
    }
  }

  Future<void> registrar(
      String nombre, String email, String codigo, String password, Rol rol) async {
    ocupado.value = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(nombre.trim());

      // Guarda los datos del usuario en Firestore (colección "usuarios")
      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'nombre': nombre.trim(),
        'email': email.trim().toLowerCase(),
        'codigo': codigo.trim(),
        'rol': rol.name,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      // Envía el enlace para activar la cuenta. Si falla, no se daña el registro:
      // el enlace se puede pedir otra vez desde la pantalla de activación.
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      throw AuthError(_traducirError(e));
    } on FirebaseException catch (e) {
      throw AuthError('Error al guardar en la base de datos (${e.code}).');
    } finally {
      ocupado.value = false;
    }
  }

  Future<void> recuperarContrasena(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthError(_traducirError(e));
    }
  }

  /// Lee nombre y rol del usuario desde Firestore.
  Future<({String nombre, String rol, String codigo})> obtenerPerfil() async {
    final user = _auth.currentUser;
    if (user == null) return (nombre: '', rol: '', codigo: '');
    final datos = (await _db.collection('usuarios').doc(user.uid).get()).data();
    final nombre = datos?['nombre'] ?? user.displayName ?? user.email ?? '';
    final rolTexto = datos?['rol'] as String?;
    final rol = rolTexto == null ? '' : Rol.values.byName(rolTexto).etiqueta;
    final codigo = (datos?['codigo'] ?? '') as String;
    return (nombre: nombre as String, rol: rol, codigo: codigo);
  }

  /// Usuario actual con su rol, leído desde Firestore.
  Future<Usuario?> obtenerUsuario() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final datos = (await _db.collection('usuarios').doc(user.uid).get()).data();
    if (datos == null) return null;
    return Usuario(
      uid: user.uid,
      nombre: (datos['nombre'] ?? user.displayName ?? '') as String,
      email: (datos['email'] ?? user.email ?? '') as String,
      codigo: (datos['codigo'] ?? '') as String,
      rol: Rol.values.byName((datos['rol'] ?? 'estudiante') as String),
    );
  }

  // ---------- Activación de la cuenta ----------

  /// true si el usuario ya abrió el enlace de verificación (según lo último que se sabe).
  bool get correoVerificado => _auth.currentUser?.emailVerified ?? false;

  /// Vuelve a enviar el enlace de activación al correo.
  Future<void> enviarVerificacion() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthError(_traducirError(e));
    }
  }

  /// Le pregunta a Firebase si el correo ya fue verificado.
  /// Si lo fue, renueva la credencial para que las reglas de Firestore también lo vean.
  Future<bool> revisarVerificacion() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final verificado = _auth.currentUser?.emailVerified ?? false;
      if (verificado) await _auth.currentUser?.getIdToken(true);
      return verificado;
    } catch (_) {
      return false; // sin conexión: se intenta de nuevo más tarde
    }
  }

  Future<void> cerrarSesion() => _auth.signOut();

  String _traducirError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña es muy débil.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Ocurrió un error (${e.code}).';
    }
  }
}
