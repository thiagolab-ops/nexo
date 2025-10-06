import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:provider/provider.dart';

class TelaAplicarProfessor extends StatefulWidget {
  const TelaAplicarProfessor({super.key});

  @override
  State<TelaAplicarProfessor> createState() => _TelaAplicarProfessorState();
}

class _TelaAplicarProfessorState extends State<TelaAplicarProfessor> {
  final _formKey = GlobalKey<FormState>();
  final _specialtiesController = TextEditingController();
  final _linksController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);

    final user = context.read<UserModel?>();
    final userId = FirebaseAuth.instance.currentUser!.uid;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Não foi possível identificar seu perfil.'), backgroundColor: Colors.red),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('professor_applications').doc(userId).set({
        'userId': userId,
        'applicantUsername': user.username,
        'specialties': _specialtiesController.text.trim(),
        'socialLinks': _linksController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Aplicação Enviada!'),
            content: const Text('Sua solicitação para se tornar um professor foi enviada com sucesso. Nossa equipe irá analisá-la e você receberá uma notificação em breve.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).pop(); // Fecha o dialog
                  Navigator.of(context).pop(); // Volta para a tela de perfil
                },
              )
            ],
          ),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar aplicação: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicar para Professor'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Conte-nos sobre você',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sua aplicação será analisada por nossa equipe. Preencha os campos abaixo para nos ajudar a te conhecer melhor.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _specialtiesController,
                    decoration: const InputDecoration(
                      labelText: 'Suas Especialidades',
                      hintText: 'Ex: Matemática, Programação, História...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, informe suas especialidades.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _linksController,
                    decoration: const InputDecoration(
                      labelText: 'Links (Redes Sociais, Portfólio, etc)',
                      hintText: 'Cole os links aqui, um por linha.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, informe ao menos um link.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  if (_isSubmitting)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submitApplication,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Enviar Aplicação'),
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
