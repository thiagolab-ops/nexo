import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'screens/tela_criar_perfil.dart';
import 'screens/tela_login.dart';
import 'services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _checkReferralLink();
  }

  Future<void> _checkReferralLink() async {
    final uri = Uri.tryParse(html.window.location.href);
    if (uri != null && uri.queryParameters.containsKey('ref')) {
      final referralUsername = uri.queryParameters['ref'];
      if (referralUsername != null && referralUsername.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('referralUsername', referralUsername);
        print('Referência salva: $referralUsername');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<User?>(context);

    if (firebaseUser == null) {
      return const TelaLogin();
    }

    final userProfile = Provider.of<UserModel?>(context);

    if (userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userProfile.hasCompletedOnboarding) {
      return const TelaPrincipal();
    } else {
      return const TelaCriarPerfil();
    }
  }
}
