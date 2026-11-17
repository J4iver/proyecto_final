import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: auth.cerrarSesion,
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder(
          future: auth.obtenerPerfil(), // lee nombre y rol desde Firestore
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final perfil = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¡Hola, ${perfil.nombre}!', style: texto.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  perfil.codigo.isEmpty ? perfil.rol : '${perfil.rol} · ${perfil.codigo}',
                  style: texto.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
