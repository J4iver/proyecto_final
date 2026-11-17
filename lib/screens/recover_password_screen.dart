import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_texto.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  static const _espera = 45; // segundos antes de poder reenviar

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _auth = AuthService();
  bool _cargando = false;
  bool _enviado = false;
  int _segundos = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Envía (o reenvía) el enlace y arranca el contador.
  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await _auth.recuperarContrasena(_emailCtrl.text);
      if (!mounted) return;
      setState(() => _enviado = true);
      _iniciarContador();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace enviado. Revisa tu correo.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _iniciarContador() {
    _timer?.cancel();
    setState(() => _segundos = _espera);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundos <= 1) t.cancel();
      setState(() => _segundos--);
    });
  }

  /// Volver a escribir otro correo
  void _cambiarCorreo() {
    _timer?.cancel();
    setState(() {
      _enviado = false;
      _segundos = 0;
    });
  }

  String get _tiempo => '0:${_segundos.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

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
                    // ---------- Icono y título ----------
                    Center(child: _icono()),
                    const SizedBox(height: 16),
                    Text('¿Olvidaste tu contraseña?',
                        textAlign: TextAlign.center, style: texto.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa tu correo institucional y te enviaremos un enlace '
                      'para crear una contraseña nueva.',
                      textAlign: TextAlign.center,
                      style: texto.bodyMedium,
                    ),
                    const SizedBox(height: 28),

                    // ---------- Correo ----------
                    CampoTexto(
                      etiqueta: 'Correo Institucional',
                      controller: _emailCtrl,
                      icono: Icons.alternate_email,
                      hint: 'tu.nombre${AuthService.dominioPermitido}',
                      tipoTeclado: TextInputType.emailAddress,
                      accionTeclado: TextInputAction.done,
                      alEnviar: (_) => _enviado ? null : _enviar(),
                      validator: AuthService.validarCorreo,
                      soloLectura: _enviado,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 1),
                          child: Icon(Icons.info_outline, size: 16, color: AppColors.primarioContenedor),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Revisa tu bandeja universitaria y también la carpeta de correo no deseado.',
                            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---------- Estado: enviado ----------
                    if (_enviado) ...[
                      _tarjetaEnviado(texto),
                      const SizedBox(height: 20),
                    ],

                    // ---------- Botones ----------
                    if (!_enviado)
                      FilledButton(
                        onPressed: _cargando ? null : _enviar,
                        child: _cargando
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Enviar enlace'),
                                ],
                              ),
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Volver al Inicio de Sesión'),
                      ),
                    if (_enviado)
                      TextButton(
                        onPressed: _cambiarCorreo,
                        child: const Text('Usar otro correo'),
                      ),
                    const SizedBox(height: 28),

                    // ---------- Ayuda ----------
                    _tarjetaAyuda(texto),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Candado en círculo con el escudito verde.
  Widget _icono() {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: AppColors.contenedor, shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarioContenedor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset, size: 32, color: AppColors.primarioContenedor),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: AppColors.verdeClaro, shape: BoxShape.circle),
              child: const Icon(Icons.verified_user, size: 16, color: AppColors.verdeOscuro),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta "Enlace enviado" con el contador para reenviar.
  Widget _tarjetaEnviado(TextTheme texto) {
    final puedeReenviar = _segundos <= 0 && !_cargando;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Enlace enviado', style: texto.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Si ${_emailCtrl.text.trim()} tiene una cuenta, te llegará un correo '
            'con el enlace para restablecer tu contraseña.',
            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('¿No lo recibiste?', style: texto.bodySmall)),
              TextButton.icon(
                onPressed: puedeReenviar ? _enviar : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: texto.labelSmall,
                ),
                icon: Icon(puedeReenviar ? Icons.refresh : Icons.schedule, size: 14),
                label: Text(puedeReenviar ? 'Reenviar ahora' : 'Reenviar en $_tiempo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Contactos de soporte de la universidad.
  Widget _tarjetaAyuda(TextTheme texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.contenedor, shape: BoxShape.circle),
            child: const Icon(Icons.support_agent, size: 20, color: AppColors.primarioContenedor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Necesitas ayuda?', style: texto.labelMedium),
                const SizedBox(height: 2),
                Text('Si no tienes acceso a tu correo institucional, contacta a:',
                    style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                const SizedBox(height: 10),
                _contacto(texto, 'Mesa de Servicios', 'mesadeservicios@udla.edu.co'),
                const SizedBox(height: 8),
                _contacto(texto, 'Oficina de Tecnologías de la Información',
                    'cinternet@uniamazonia.edu.co'),
                const SizedBox(height: 10),
                Text('Lunes a viernes, 7:30 a. m. – 11:30 a. m. y 1:30 p. m. – 5:30 p. m.',
                    style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                const SizedBox(height: 2),
                Text('Bloque 1, segundo piso, sede Porvenir, Florencia.',
                    style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Un contacto: nombre + correo que se copia al tocarlo.
  Widget _contacto(TextTheme texto, String nombre, String correo) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: correo));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Correo copiado: $correo')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: texto.bodySmall?.copyWith(color: AppColors.texto)),
                  Text(correo,
                      style: texto.labelSmall?.copyWith(color: AppColors.primarioContenedor)),
                ],
              ),
            ),
            const Icon(Icons.copy, size: 16, color: AppColors.primarioContenedor),
          ],
        ),
      ),
    );
  }
}
