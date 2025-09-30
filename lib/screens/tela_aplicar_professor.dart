import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:provider/provider.dart';

class TelaAplicarProfessor extends StatefulWidget {
  const TelaAplicarProfessor({super.key});

  @override
  State<TelaAplicarProfessor> createState() => _TelaAplicarProfessorState();
}

class _TelaAplicarProfessorState extends State<TelaAplicarProfessor> {
  final _formKey = GlobalKey<FormState>();
  final _specialtiesController = TextEditingController();
  final _socialLinksController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Pega o perfil do usuário atual do Provider
    final currentUser = Provider.of<UserModel?>(context, listen: false);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Não foi possível identificar o usuário.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<ProfileService>().applyToBeProfessor(
        userId: currentUser.id,
        username: currentUser.username, // <-- Passando o username
        specialties: _specialtiesController.text,
        socialLinks: _socialLinksController.text,
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Solicitação Enviada!'),
            content: const Text('Sua solicitação para se tornar um professor foi enviada. Nossa equipe analisará seu perfil e entrará em contato em breve. Obrigado!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); 
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar solicitação: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Status de Professor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Por que você quer ser um Professor no Daxu?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Professores têm acesso a ferramentas exclusivas, como postar no Daxu Feed e criar Cursos no Daxu Go. Analisamos todas as solicitações para manter a alta qualidade da nossa comunidade.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _specialtiesController,
                decoration: const InputDecoration(
                  labelText: 'O que você ensina?',
                  hintText: 'Ex: Inglês para iniciantes, Cálculo, Direito Penal...',
                ),
                maxLines: 3,
                validator: (val) => val!.trim().isEmpty ? 'Este campo é obrigatório.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _socialLinksController,
                decoration: const InputDecoration(
                  labelText: 'Links (Redes Sociais, Portfólio)',
                  hintText: 'Ex: LinkedIn, Instagram, site pessoal...',
                ),
                maxLines: 2,
                validator: (val) => val!.trim().isEmpty ? 'Este campo é obrigatório.' : null,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submitApplication,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('ENVIAR SOLICITAÇÃO'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
