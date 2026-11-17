import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/verificar_correo_screen.dart';
import 'screens/docente/docente_shell.dart';
import 'screens/estudiante/estudiante_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Conecta la app con el proyecto de Firebase (usa firebase_options.dart)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appsistencia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      // Escucha si hay sesión iniciada: si la hay entra a la app, si no, Login
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _Cargando();
          }
          // Mientras se verifica el rol, se sigue mostrando el Login
          return ValueListenableBuilder<bool>(
            valueListenable: AuthService.ocupado,
            builder: (context, ocupado, _) {
              final haySesion = snapshot.hasData && !ocupado;
              if (!haySesion) return const LoginScreen();
              // La key hace que se vuelva a cargar si entra otra cuenta
              return _Entrada(key: ValueKey(snapshot.data!.uid));
            },
          );
        },
      ),
    );
  }
}

/// Lee el rol del usuario y lo manda a la parte de la app que le corresponde.
class _Entrada extends StatefulWidget {
  const _Entrada({super.key});

  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada> {
  late final Future<Usuario?> _usuario = AuthService().obtenerUsuario();
  bool _verificado = AuthService().correoVerificado;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Usuario?>(
      future: _usuario,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Cargando();
        final usuario = snapshot.data;
        if (usuario == null) {
          // Cuenta sin datos en Firestore: se cierra la sesión para no quedar atascado
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudieron cargar los datos de tu cuenta.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: AuthService().cerrarSesion,
                      child: const Text('Volver al inicio de sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (usuario.rol == Rol.docente) return DocenteShell(usuario: usuario);

        // El estudiante debe activar su cuenta desde el enlace que llega a su correo
        if (AuthService.exigirCorreoVerificado && !_verificado) {
          return VerificarCorreoScreen(
            usuario: usuario,
            alVerificar: () => setState(() => _verificado = true),
          );
        }
        return EstudianteShell(usuario: usuario);
      },
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
