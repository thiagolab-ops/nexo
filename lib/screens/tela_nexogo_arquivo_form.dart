import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class TelaNexoGoArquivoForm extends StatefulWidget {
  final VideoNexo? videoToEdit;
  const TelaNexoGoArquivoForm({super.key, this.videoToEdit});

  @override
  _TelaNexoGoArquivoFormState createState() => _TelaNexoGoArquivoFormState();
}

class _TelaNexoGoArquivoFormState extends State<TelaNexoGoArquivoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _videoUrlController;
  bool _isSaving = false;
  final Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.videoToEdit?.title);
    _subjectController = TextEditingController(text: widget.videoToEdit?.subject);
    _descriptionController = TextEditingController(text: widget.videoToEdit?.description);
    _videoUrlController = TextEditingController(text: widget.videoToEdit?.videoUrl);
  }

  Future<void> _saveVideo() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    final firestoreService = context.read<FirestoreService>();
    final userId = context.read<User>().uid;

    try {
      if (widget.videoToEdit != null) {
        final updatedVideo = VideoNexo(
          id: widget.videoToEdit!.id,
          ownerId: userId,
          title: _titleController.text,
          subject: _subjectController.text,
          description: _descriptionController.text,
          videoUrl: _videoUrlController.text,
          createdAt: widget.videoToEdit!.createdAt,
        );
        await firestoreService.updateVideo(updatedVideo);
      } else {
        final newVideo = VideoNexo(
          id: _uuid.v4(),
          ownerId: userId,
          title: _titleController.text,
          subject: _subjectController.text,
          description: _descriptionController.text,
          videoUrl: _videoUrlController.text,
          createdAt: Timestamp.now(),
        );
        await firestoreService.addVideo(newVideo);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoToEdit == null ? 'Adicionar Vídeo' : 'Editar Vídeo'),
        actions: [
          if (_isSaving) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else IconButton(icon: const Icon(Icons.save), onPressed: _saveVideo),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
              ),
              // ... (resto do formulário)
            ],
          ),
        ),
      ),
    );
  }
}
