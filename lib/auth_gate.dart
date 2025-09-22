import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'screens/tela_criar_perfil.dart';
import 'screens/tela_login.dart';
import 'services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <<< IMPORTADO
import 'dart:html' as html; // <<< IMPORTADO

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {

  @override
  void initState() {
    super.initState();
    _checkReferralLink(); // Verifica o link de referência ao iniciar o app
  }

  // --- NOVA FUNÇÃO PARA LER A URL ---
  Future<void> _checkReferralLink() async {
    // Pega a URL atual do navegador
    final uri = Uri.tryParse(html.window.location.href);
    if (uri != null && uri.queryParameters.containsKey('ref')) {
      final referralUsername = uri.queryParameters['ref'];
      if (referralUsername != null && referralUsername.isNotEmpty) {
        // Salva o username de referência localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('referralUsername', referralUsername);
        print('Referência salva: $referralUsername');
      }
    }
  }
  // --- FIM DA NOVA FUNÇÃO ---

  @override
  Widget build(BuildContext context) {
    return Consumer<User?>(
      builder: (context, user, _) {
        if (user == null) {
          return const TelaLogin();
        }
        
        // A lógica de verificação de perfil existente permanece
        return FutureBuilder<UserModel?>(
          future: context.read<ProfileService>().getUserProfile(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (snapshot.hasData && snapshot.data != null) {
              return const TelaPrincipal();
            } else {
              return const TelaCriarPerfil();
            }
          },
        );
      },
    );
  }
}
