import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.videoToEdit?.title ?? '');
    _subjectController = TextEditingController(text: widget.videoToEdit?.subject ?? '');
    _descriptionController = TextEditingController(text: widget.videoToEdit?.description ?? '');
    _videoUrlController = TextEditingController(text: widget.videoToEdit?.videoUrl ?? '');
  }

  Future<void> _saveVideo() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    final firestoreService = context.read<FirestoreService>();
    final userId = context.read<User>().uid;

    try {
      if (widget.videoToEdit != null) {
        // Editando um vídeo existente
        final updatedVideo = VideoNexo(
          id: widget.videoToEdit!.id,
          ownerId: userId,
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          videoUrl: _videoUrlController.text.trim(),
          createdAt: widget.videoToEdit!.createdAt,
        );
        // Atualiza na coleção privada
        await firestoreService.updateVideo(updatedVideo);
        // Atualiza a cópia pública
        await FirebaseFirestore.instance.collection('public_videos').doc(updatedVideo.id).set(updatedVideo.toMap());
      } else {
        // Criando um novo vídeo
        final newVideo = await firestoreService.addVideoFromForm(
          ownerId: userId,
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          videoUrl: _videoUrlController.text.trim(),
        );
        // Cria a cópia pública
        await FirebaseFirestore.instance.collection('public_videos').doc(newVideo.id).set(newVideo.toMap());
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Lidar com o erro
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoToEdit == null ? 'daxugo_addVideo'.tr() : 'daxugo_editVideo'.tr()),
        actions: [
          if (_isSaving) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else IconButton(icon: const Icon(Icons.save), onPressed: _saveVideo, tooltip: 'saveButton'.tr()),
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
                decoration: InputDecoration(labelText: 'daxugo_videoTitle'.tr()),
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(labelText: 'daxugo_videoSubject'.tr()),
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _videoUrlController,
                decoration: InputDecoration(labelText: 'daxugo_videoUrl'.tr()),
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'daxugo_videoDescription'.tr()),
                maxLines: 5,
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
