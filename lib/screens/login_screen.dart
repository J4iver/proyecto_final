import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_texto.dart';
import '../widgets/selector_rol.dart';
import 'register_screen.dart';
import 'recover_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  Rol _rol = Rol.estudiante;
  bool _cargando = false;
  bool _ocultar = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await _auth.iniciarSesion(_emailCtrl.text, _passCtrl.text, _rol);
      // No hace falta navegar: main.dart detecta la sesión y muestra el Home
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- Logo con brillo ----------
                    Center(child: _logo()),
                    const SizedBox(height: 12),
                    Text('Appsistencia', textAlign: TextAlign.center, style: texto.headlineLarge),
                    const SizedBox(height: 2),
                    Text('Portal Académico Institucional',
                        textAlign: TextAlign.center, style: texto.bodyMedium),
                    const SizedBox(height: 24),

                    // ---------- Docente / Estudiante ----------
                    SelectorRol(
                      valor: _rol,
                      alCambiar: (rol) => setState(() => _rol = rol),
                    ),
                    const SizedBox(height: 24),

                    // ---------- Formulario ----------
                    CampoTexto(
                      etiqueta: 'Correo Institucional',
                      controller: _emailCtrl,
                      icono: Icons.mail_outline,
                      hint: '${_rol.name}${AuthService.dominioPermitido}',
                      tipoTeclado: TextInputType.emailAddress,
                      accionTeclado: TextInputAction.next,
                      validator: AuthService.validarCorreo,
                    ),
                    const SizedBox(height: 16),
                    CampoTexto(
                      etiqueta: 'Contraseña',
                      controller: _passCtrl,
                      icono: Icons.lock_outline,
                      hint: '••••••••••••',
                      oculto: _ocultar,
                      accionTeclado: TextInputAction.done,
                      alEnviar: (_) => _ingresar(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                      sufijo: IconButton(
                        icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off, size: 20),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                      accion: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: texto.labelSmall,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RecoverPasswordScreen()),
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _cargando ? null : _ingresar,
                      child: _cargando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Iniciar Sesión'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                    const SizedBox(height: 32),

                    // ---------- Crear cuenta ----------
                    Text('¿No tienes una cuenta?',
                        textAlign: TextAlign.center, style: texto.bodyMedium),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Crear cuenta'),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          // Brillo azul suave alrededor
          BoxShadow(
            color: AppColors.primarioSuave.withValues(alpha: 0.9),
            blurRadius: 60,
            spreadRadius: 24,
          ),
          // Sombra normal
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          // Si todavía no has puesto el logo, muestra un icono en su lugar
          errorBuilder: (_, _, _) =>
              const Icon(Icons.school, size: 44, color: AppColors.primario),
        ),
      ),
    );
  }
}
