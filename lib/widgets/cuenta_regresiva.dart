import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sesion.dart';
import '../services/sesion_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import 'tarjeta.dart';

/// Tiempo que le queda a una sesión de asistencia, actualizado cada segundo.
class CuentaRegresiva extends StatefulWidget {
  final String cursoId;
  final String sesionId;
  const CuentaRegresiva({super.key, required this.cursoId, required this.sesionId});

  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<CuentaRegresiva> {
  late final Stream<Sesion?> _sesion = SesionService().sesion(widget.cursoId, widget.sesionId);
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Sesion?>(
      stream: _sesion,
      builder: (context, snapshot) {
        final s = snapshot.data;
        if (s == null) return const SizedBox.shrink();
        return Pildora(
          formatoReloj(s.cierraEn.difference(DateTime.now())),
          fondo: AppColors.campo,
          color: AppColors.primario,
          icono: Icons.timer_outlined,
        );
      },
    );
  }
}
