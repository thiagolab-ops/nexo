import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'screens/tela_criar_perfil.dart';
import 'screens/tela_login.dart';
import 'services/profile_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Usando o Consumer para ouvir o Stream de User do Provider
    return Consumer<User?>(
      builder: (context, user, _) {
        // Se não há usuário logado, mostra a tela de login.
        if (user == null) {
          return const TelaLogin();
        }

        // Se há um usuário, usa um FutureBuilder para fazer uma verificação ÚNICA.
        return FutureBuilder<UserModel?>(
          future: context.read<ProfileService>().getUserProfile(user.uid),
          builder: (context, snapshot) {
            // Enquanto verifica, mostra uma tela de carregamento.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Se o perfil existe (não é nulo), o usuário está pronto.
            if (snapshot.hasData && snapshot.data != null) {
              return const TelaPrincipal();
            } else {
            // Se o perfil NÃO existe, leva para o onboarding.
              return const TelaCriarPerfil();
            }
          },
        );
      },
    );
  }
}
