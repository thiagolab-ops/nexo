import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TelaNexoGoCursoForm extends StatefulWidget {
  final Curso? cursoToEdit;
  const TelaNexoGoCursoForm({super.key, this.cursoToEdit});

  @override
  State<TelaNexoGoCursoForm> createState() => _TelaNexoGoCursoFormState();
}

class _TelaNexoGoCursoFormState extends State<TelaNexoGoCursoForm> {
  final _formKey = GlobalKey<FormState>();
  late final FirestoreService _firestoreService;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  bool get _isEditing => widget.cursoToEdit != null;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _titleController = TextEditingController(text: widget.cursoToEdit?.title ?? '');
    _descriptionController = TextEditingController(text: widget.cursoToEdit?.description ?? '');
  }

  Future<void> _saveCurso() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      if (_isEditing) {
        final updatedCurso = widget.cursoToEdit!;
        updatedCurso.title = _titleController.text;
        updatedCurso.description = _descriptionController.text;
        
        await _firestoreService.updateCurso(userId, updatedCurso);
      } else {
        final newCurso = Curso(
          id: '', // será gerado
          ownerId: userId,
          title: _titleController.text,
          description: _descriptionController.text,
          createdAt: Timestamp.now(),
        );
        await _firestoreService.createCurso(newCurso);
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Curso salvo com sucesso!'), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop();
      }
    } catch (e) {
       setState(() => _isLoading = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Curso' : 'Criar Novo Curso'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título do Curso'),
                validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição do Curso'),
                maxLines: 5,
                 validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveCurso,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('SALVAR CURSO'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
