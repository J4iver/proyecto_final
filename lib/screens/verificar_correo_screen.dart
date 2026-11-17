import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de activación: el estudiante debe abrir el enlace que llegó a su
/// correo institucional. Revisa sola cada pocos segundos y deja entrar apenas se verifica.
class VerificarCorreoScreen extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback alVerificar;

  const VerificarCorreoScreen({super.key, required this.usuario, required this.alVerificar});

  @override
  State<VerificarCorreoScreen> createState() => _VerificarCorreoScreenState();
}

class _VerificarCorreoScreenState extends State<VerificarCorreoScreen> {
  static const _espera = 60; // segundos antes de poder reenviar

  final _auth = AuthService();
  Timer? _reloj;
  int _segundos = 0; // cuenta regresiva del reenvío
  int _tics = 0;
  bool _revisando = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _tics++;
      if (_segundos > 0) setState(() => _segundos--);
      // Cada 4 segundos le pregunta a Firebase si ya se verificó
      if (_tics % 4 == 0) _revisar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _revisar({bool silencioso = false}) async {
    if (_revisando) return;
    _revisando = true;
    if (!silencioso && mounted) setState(() {});
    final verificado = await _auth.revisarVerificacion();
    _revisando = false;
    if (!mounted) return;
    if (verificado) {
      _reloj?.cancel();
      widget.alVerificar();
    } else if (!silencioso) {
      setState(() {});
      _aviso('Todavía no aparece verificado. Abre el enlace del correo e inténtalo de nuevo.');
    }
  }

  Future<void> _reenviar() async {
    setState(() => _enviando = true);
    try {
      await _auth.enviarVerificacion();
      if (!mounted) return;
      setState(() => _segundos = _espera);
      _aviso('Enlace enviado. Revisa tu correo.');
    } catch (e) {
      _aviso(e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String get _tiempo => '0:${_segundos.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final puedeReenviar = _segundos <= 0 && !_enviando;
    final verificando = _revisando;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Icono ----------
                  Center(
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                                color: AppColors.contenedor, shape: BoxShape.circle),
                            child: const Icon(Icons.mark_email_unread_outlined,
                                size: 36, color: AppColors.primarioContenedor),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                  color: AppColors.verdeClaro, shape: BoxShape.circle),
                              child: const Icon(Icons.verified_user,
                                  size: 16, color: AppColors.verdeOscuro),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Activa tu cuenta', textAlign: TextAlign.center, style: texto.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Te enviamos un enlace de verificación a:',
                    textAlign: TextAlign.center,
                    style: texto.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.usuario.email,
                      textAlign: TextAlign.center,
                      style: texto.titleMedium?.copyWith(color: AppColors.primario)),
                  const SizedBox(height: 20),

                  // ---------- Pasos ----------
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _paso(texto, '1', 'Abre tu correo institucional.'),
                        const SizedBox(height: 10),
                        _paso(texto, '2',
                            'Busca el mensaje de Appsistencia. Si no aparece, revisa el correo no deseado.'),
                        const SizedBox(height: 10),
                        _paso(texto, '3',
                            'Toca el enlace del mensaje y vuelve a la app: entrarás automáticamente.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  FilledButton(
                    onPressed: verificando ? null : _revisar,
                    child: verificando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Ya abrí el enlace'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: puedeReenviar ? _reenviar : null,
                    icon: Icon(puedeReenviar ? Icons.refresh : Icons.schedule, size: 18),
                    label: Text(puedeReenviar ? 'Reenviar el enlace' : 'Reenviar en $_tiempo'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _auth.cerrarSesion,
                    style: TextButton.styleFrom(foregroundColor: AppColors.textoSecundario),
                    child: const Text('Usar otra cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paso(TextTheme texto, String numero, String t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.primarioSuave,
          child: Text(numero, style: texto.labelSmall?.copyWith(color: AppColors.primario)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(t, style: texto.bodyMedium?.copyWith(color: AppColors.texto))),
      ],
    );
  }
}
