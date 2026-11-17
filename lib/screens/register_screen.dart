import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_texto.dart';
import '../widgets/selector_rol.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();
  Rol _rol = Rol.estudiante;
  bool _cargando = false;
  bool _ocultarPass = true;
  bool _ocultarConfirm = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _coinciden =>
      _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _passCtrl.text;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await _auth.registrar(
        _nombreCtrl.text,
        _emailCtrl.text,
        _codigoCtrl.text,
        _passCtrl.text,
        _rol,
      );
      // Al registrarse, Firebase inicia sesión solo. Cerramos esta pantalla
      // y main.dart ya muestra el Home debajo.
      if (mounted) Navigator.pop(context);
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
    final pass = _passCtrl.text;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 160,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          label: const Text('Iniciar Sesión'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- Título ----------
                    Text('Crear Cuenta', style: texto.headlineLarge),
                    const SizedBox(height: 6),
                    Text('Regístrate con tu correo institucional.', style: texto.bodyMedium),
                    const SizedBox(height: 24),

                    // ---------- Rol ----------
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Tipo de usuario', style: texto.labelMedium),
                    ),
                    SelectorRol(
                      valor: _rol,
                      alCambiar: (rol) => setState(() => _rol = rol),
                    ),
                    const SizedBox(height: 20),

                    // ---------- Datos ----------
                    CampoTexto(
                      etiqueta: 'Nombre Completo',
                      controller: _nombreCtrl,
                      icono: Icons.account_circle_outlined,
                      hint: 'Ej. Laura Gómez Castillo',
                      accionTeclado: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    CampoTexto(
                      etiqueta: 'Correo Institucional',
                      controller: _emailCtrl,
                      icono: Icons.mail_outline,
                      hint: '${_rol.name}${AuthService.dominioPermitido}',
                      tipoTeclado: TextInputType.emailAddress,
                      accionTeclado: TextInputAction.next,
                      validator: AuthService.validarCorreo,
                      accion: _etiquetaVerde(AuthService.dominioPermitido, punto: true),
                    ),
                    const SizedBox(height: 16),
                    CampoTexto(
                      etiqueta: 'Código / Carnet Institucional',
                      controller: _codigoCtrl,
                      icono: Icons.pin_outlined,
                      hint: 'Ej. 1234567890',
                      tipoTeclado: TextInputType.number,
                      accionTeclado: TextInputAction.next,
                      formateadores: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: AuthService.validarCodigo,
                    ),
                    const SizedBox(height: 16),

                    // ---------- Contraseña ----------
                    CampoTexto(
                      etiqueta: 'Contraseña',
                      controller: _passCtrl,
                      icono: Icons.lock_outline,
                      hint: '••••••••••••',
                      oculto: _ocultarPass,
                      accionTeclado: TextInputAction.next,
                      alCambiar: (_) => setState(() {}), // actualiza la lista de reglas
                      validator: AuthService.validarContrasena,
                      sufijo: IconButton(
                        icon: Icon(_ocultarPass ? Icons.visibility : Icons.visibility_off,
                            size: 20),
                        onPressed: () => setState(() => _ocultarPass = !_ocultarPass),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _regla('8+ caracteres', AuthService.tieneLargo(pass)),
                        _regla('Mayúscula', AuthService.tieneMayuscula(pass)),
                        _regla('Número', AuthService.tieneNumero(pass)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CampoTexto(
                      etiqueta: 'Confirmar Contraseña',
                      controller: _confirmCtrl,
                      icono: Icons.lock_reset,
                      hint: '••••••••••••',
                      oculto: _ocultarConfirm,
                      accionTeclado: TextInputAction.done,
                      alCambiar: (_) => setState(() {}), // actualiza "Coinciden"
                      alEnviar: (_) => _registrar(),
                      validator: (v) =>
                          v != _passCtrl.text ? 'Las contraseñas no coinciden' : null,
                      accion: _coinciden ? _etiquetaVerde('Coinciden', icono: Icons.check) : null,
                      sufijo: IconButton(
                        icon: Icon(_ocultarConfirm ? Icons.visibility : Icons.visibility_off,
                            size: 20),
                        onPressed: () => setState(() => _ocultarConfirm = !_ocultarConfirm),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ---------- Botón ----------
                    FilledButton(
                      onPressed: _cargando ? null : _registrar,
                      child: _cargando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Crear Cuenta'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('¿Ya tienes una cuenta?', style: texto.bodyMedium),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Inicia Sesión'),
                        ),
                      ],
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

  /// Una regla de la contraseña: gris si no se cumple, verde si sí.
  Widget _regla(String texto, bool cumple) {
    final color = cumple ? AppColors.verde : AppColors.textoSecundario;
    return Expanded(
      child: Row(
        children: [
          Icon(cumple ? Icons.check_circle : Icons.check_circle_outline, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  /// Etiqueta verde pequeña a la derecha del nombre del campo.
  Widget _etiquetaVerde(String texto, {IconData? icono, bool punto = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (punto)
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
          ),
        if (icono != null) Icon(icono, size: 14, color: AppColors.verde),
        const SizedBox(width: 4),
        Text(texto,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.verde)),
      ],
    );
  }
}
