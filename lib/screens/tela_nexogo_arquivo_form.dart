import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';

// Este arquivo era o 'tela_video_form.dart' e foi renomeado e adaptado
class TelaNexoGoArquivoForm extends StatefulWidget {
  final VideoNexo? videoToEdit;
  const TelaNexoGoArquivoForm({super.key, this.videoToEdit});

  @override
  State<TelaNexoGoArquivoForm> createState() => _TelaNexoGoArquivoFormState();
}

class _TelaNexoGoArquivoFormState extends State<TelaNexoGoArquivoForm> {
  final _formKey = GlobalKey<FormState>();
  late final FirestoreService _firestoreService;
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _urlController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  bool get _isEditing => widget.videoToEdit != null;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _titleController = TextEditingController(text: widget.videoToEdit?.title ?? '');
    _subjectController = TextEditingController(text: widget.videoToEdit?.subject ?? '');
    _urlController = TextEditingController(text: widget.videoToEdit?.videoUrl ?? '');
    _descriptionController = TextEditingController(text: widget.videoToEdit?.description ?? '');
  }

  Future<void> _saveVideo() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      if (_isEditing) {
        final updatedVideo = VideoNexo(
          id: widget.videoToEdit!.id,
          ownerId: widget.videoToEdit!.ownerId,
          title: _titleController.text,
          subject: _subjectController.text,
          description: _descriptionController.text,
          videoUrl: _urlController.text,
          createdAt: widget.videoToEdit!.createdAt,
        );
        await _firestoreService.updateVideo(updatedVideo);
      } else {
        final newVideo = VideoNexo(
          ownerId: userId,
          title: _titleController.text,
          subject: _subjectController.text,
          description: _descriptionController.text,
          videoUrl: _urlController.text,
          createdAt: Timestamp.now(),
        );
        await _firestoreService.addVideo(newVideo);
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Vídeo salvo no Arquivo!'), backgroundColor: Colors.green),
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
        title: Text(_isEditing ? 'Editar Vídeo do Arquivo' : 'Novo Vídeo no Arquivo'),
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
                decoration: const InputDecoration(labelText: 'Título do Vídeo'),
                validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Matéria (ex: Inglês, Cálculo, etc)'),
                validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
               TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL (YouTube ou Vimeo)'),
                validator: (val) => val!.isEmpty ? 'URL é obrigatória' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 5,
                 validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveVideo,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('SALVAR NO ARQUIVO'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
