import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Importado para kIsWeb
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'screens/tela_criar_perfil.dart';
import 'screens/tela_login.dart';
import 'services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Apenas importa 'dart:html' se estivermos na web
import 'dart:html' as html;


class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {

  @override
  void initState() {
    super.initState();
    // A verificação de link de referência só deve acontecer na web
    if (kIsWeb) {
      _checkReferralLink();
    }
  }

  Future<void> _checkReferralLink() async {
    try {
      final uri = Uri.tryParse(html.window.location.href);
      if (uri != null && uri.queryParameters.containsKey('ref')) {
        final referralUsername = uri.queryParameters['ref'];
        if (referralUsername != null && referralUsername.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('referralUsername', referralUsername);
        }
      }
    } catch (e) {
      print("Erro ao checar link de referência (ignorado em não-web): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<User?>(context);

    if (firebaseUser == null) {
      return const TelaLogin();
    }

    // Tenta obter o perfil do usuário do Stream, que é rápido.
    final userProfileFromStream = Provider.of<UserModel?>(context);

    // Se o Stream já nos deu um perfil, usamos ele.
    if (userProfileFromStream != null) {
      return _handleOnboarding(userProfileFromStream);
    }

    // Se o Stream ainda não emitiu um perfil (o caso do "spin infinito"),
    // usamos um FutureBuilder para ativamente BUSCAR o perfil uma única vez.
    return FutureBuilder<UserModel?>(
      future: context.read<ProfileService>().getUserProfile(firebaseUser.uid),
      builder: (context, snapshot) {
        // Enquanto busca, mostramos o spinner.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userProfile = snapshot.data;
        
        // Se, após a busca, o perfil AINDA for nulo, significa que ele é
        // um usuário verdadeiramente novo e precisa criar o perfil.
        if (userProfile == null) {
          return const TelaCriarPerfil();
        }

        // Se encontrou o perfil, procede normalmente.
        return _handleOnboarding(userProfile);
      },
    );
  }

  // Widget auxiliar para não repetir a lógica de onboarding.
  Widget _handleOnboarding(UserModel userProfile) {
    if (userProfile.hasCompletedOnboarding) {
      return const TelaPrincipal();
    } else {
      return const TelaCriarPerfil();
    }
  }
}
