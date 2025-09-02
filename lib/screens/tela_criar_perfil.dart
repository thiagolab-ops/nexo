import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class TelaCriarPerfil extends StatefulWidget {
  const TelaCriarPerfil({super.key});

  @override
  State<TelaCriarPerfil> createState() => _TelaCriarPerfilState();
}

class _TelaCriarPerfilState extends State<TelaCriarPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _interestsController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não autenticado.");
      }
      
      final username = _usernameController.text.trim();
      final isUnique = await _profileService.isUsernameUnique(username);

      if (!isUnique) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.redAccent, content: Text('Este @username já está em uso.')),
          );
        }
        return; 
      }

      final interestsString = _interestsController.text.trim();
      final interestsList = interestsString.split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

      await _profileService.createUserProfile(
        uid: user.uid,
        username: username,
        email: user.email ?? '',
        bio: _bioController.text.trim(),
        interests: interestsList,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao salvar perfil: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Complete o seu Perfil'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '@username',
                      hintText: 'ex: ada_lovelace',
                      prefixText: '@',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'O @username deve ter no mínimo 3 caracteres.';
                      }
                      if (value.contains(' ')) {
                        return 'Não pode conter espaços.';
                      }
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                        return 'Apenas letras minúsculas, números e _';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Fale um pouco sobre você...',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 150,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _interestsController,
                    decoration: const InputDecoration(
                      labelText: 'Interesses',
                      hintText: 'flutter, srs, matemática...',
                      helperText: 'Separe os interesses por vírgula',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      onPressed: _salvarPerfil,
                      label: const Text('Salvar e Entrar no Nexo'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
