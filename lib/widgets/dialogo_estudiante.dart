import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/curso.dart';
import '../services/auth_service.dart';
import 'campo_texto.dart';

/// Ventana para agregar un estudiante a mano.
class DialogoEstudiante extends StatefulWidget {
  final Set<String> codigosExistentes;
  const DialogoEstudiante({super.key, required this.codigosExistentes});

  @override
  State<DialogoEstudiante> createState() => _DialogoEstudianteState();
}

class _DialogoEstudianteState extends State<DialogoEstudiante> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _agregar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EstudianteCurso(
        codigo: _codigoCtrl.text.trim(),
        nombre: _nombreCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar estudiante'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CampoTexto(
                etiqueta: 'Nombre completo',
                controller: _nombreCtrl,
                icono: Icons.account_circle_outlined,
                accionTeclado: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Código',
                controller: _codigoCtrl,
                icono: Icons.pin_outlined,
                tipoTeclado: TextInputType.number,
                accionTeclado: TextInputAction.next,
                formateadores: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  final error = AuthService.validarCodigo(v);
                  if (error != null) return error;
                  if (widget.codigosExistentes.contains(v!.trim())) {
                    return 'Ese código ya está en la lista';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Correo (opcional)',
                controller: _emailCtrl,
                icono: Icons.mail_outline,
                tipoTeclado: TextInputType.emailAddress,
                accionTeclado: TextInputAction.done,
                alEnviar: (_) => _agregar(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? null : AuthService.validarCorreo(v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: _agregar, child: const Text('Agregar')),
      ],
    );
  }
}
