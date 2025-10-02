import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/main.dart';
import 'package:nexo/screens/tela_perfil_usuario.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelaCriarPerfil extends StatefulWidget {
  const TelaCriarPerfil({super.key});

  @override
  State<TelaCriarPerfil> createState() => _TelaCriarPerfilState();
}

class _TelaCriarPerfilState extends State<TelaCriarPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _user = FirebaseAuth.instance.currentUser;
  
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  Timer? _debounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameUnique;
  String? _usernameError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _bioController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      _isUsernameUnique = null; 
      _isCheckingUsername = false;
    });

    _debounce = Timer(const Duration(milliseconds: 700), () async {
      final username = _usernameController.text.trim();
      if (username.length < 4) {
        setState(() {
          _usernameError = 'Mínimo de 4 caracteres.';
          _isUsernameUnique = false;
        });
        return;
      }
      
      setState(() => _isCheckingUsername = true);
      final isUnique = await context.read<ProfileService>().isUsernameUnique(username);
      if(mounted) {
        setState(() {
          _isUsernameUnique = isUnique;
          _usernameError = isUnique ? null : 'Este @username já está em uso.';
          _isCheckingUsername = false;
        });
      }
    });
  }

  Future<void> _finalizarCadastro() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isUsernameUnique == null || !_isUsernameUnique!) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escolha um nome de usuário único e válido.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);

    final profileService = context.read<ProfileService>();

    await profileService.createUserProfile(
      uid: _user!.uid,
      username: _usernameController.text.trim(),
      email: _user!.email ?? '',
      bio: _bioController.text.trim(),
      interests: [], 
    );
    
    // --- LÓGICA DE CONVITE E REDIRECIONAMENTO ATUALIZADA ---
    try {
      final prefs = await SharedPreferences.getInstance();
      final referralUsername = prefs.getString('referralUsername');

      if (referralUsername != null && referralUsername.isNotEmpty) {
        // Processa o Co-Nexo automático em segundo plano
        final callable = _functions.httpsCallable('processarConvite');
        callable.call({'referralUsername': referralUsername});
        
        await prefs.remove('referralUsername');
        
        // Busca o ID de quem convidou para fazer o redirecionamento
        final referrerId = await profileService.getUserIdByUsername(referralUsername);
        
        if (referrerId != null && mounted) {
          // Navega DIRETAMENTE para o perfil do amigo, substituindo a tela de login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => TelaPerfilUsuario(userId: referrerId)),
            (route) => false,
          );
          return; // Encerra a função aqui para não navegar para a TelaPrincipal
        }
      }
    } catch (e) {
      print('Erro ao processar convite ou redirecionar: $e');
    }
    
    // Se não houver convite, ou se o amigo não for encontrado, segue o fluxo normal.
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const TelaPrincipal()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu Perfil'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bem-vindo(a) ao Daxu!',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha um nome de usuário para começar.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '@username',
                      prefixText: '@',
                      errorText: _usernameError,
                      suffixIcon: _isCheckingUsername
                          ? const Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2))
                          : _isUsernameUnique == true
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : _isUsernameUnique == false && _usernameController.text.isNotEmpty 
                                ? const Icon(Icons.error, color: Colors.red) 
                                : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 4) {
                        return 'O username precisa ter pelo menos 4 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Sua Bio (Opcional)',
                      hintText: 'Fale um pouco sobre você...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _finalizarCadastro,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Salvar e Entrar no Daxu'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
