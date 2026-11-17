import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo con la etiqueta arriba (como en el diseño de Stitch).
/// [accion] es algo opcional a la derecha de la etiqueta, p. ej. "¿Olvidaste tu contraseña?".
class CampoTexto extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final IconData icono;
  final String? hint;
  final bool oculto;
  final Widget? sufijo;
  final Widget? accion;
  final String? Function(String?)? validator;
  final TextInputType? tipoTeclado;
  final TextInputAction? accionTeclado;
  final ValueChanged<String>? alEnviar;
  final ValueChanged<String>? alCambiar;
  final List<TextInputFormatter>? formateadores;
  final bool soloLectura;

  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.icono,
    this.hint,
    this.oculto = false,
    this.sufijo,
    this.accion,
    this.validator,
    this.tipoTeclado,
    this.accionTeclado,
    this.alEnviar,
    this.alCambiar,
    this.formateadores,
    this.soloLectura = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
              ),
              ?accion,
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: oculto,
          keyboardType: tipoTeclado,
          textInputAction: accionTeclado,
          onFieldSubmitted: alEnviar,
          onChanged: alCambiar,
          inputFormatters: formateadores,
          readOnly: soloLectura,
          autocorrect: false,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icono, size: 20),
            suffixIcon: sufijo,
          ),
        ),
      ],
    );
  }
}
