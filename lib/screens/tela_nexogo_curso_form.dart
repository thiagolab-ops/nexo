import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
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
        updatedCurso.title = _titleController.text.trim();
        updatedCurso.description = _descriptionController.text.trim();
        
        // Atualiza na coleção privada
        await _firestoreService.updateCurso(userId, updatedCurso);
        // Atualiza a cópia pública
        await FirebaseFirestore.instance.collection('public_courses').doc(updatedCurso.id).set(updatedCurso.toMap());
      } else {
        // Cria na coleção privada e obtém o curso com o ID
        final newCurso = await _firestoreService.createCursoFromForm(
          ownerId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
        );
        // Cria a cópia pública com o mesmo ID
        await FirebaseFirestore.instance.collection('public_courses').doc(newCurso.id).set(newCurso.toMap());
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('daxugo_saveSuccess'.tr()), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop();
      }
    } catch (e) {
       setState(() => _isLoading = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('daxugo_saveError'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'daxugo_editCourse'.tr() : 'daxugo_createCourse'.tr()),
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
                decoration: InputDecoration(labelText: 'daxugo_courseTitle'.tr()),
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'daxugo_courseDescription'.tr()),
                maxLines: 5,
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveCurso,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('daxugo_saveCourseButton'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
