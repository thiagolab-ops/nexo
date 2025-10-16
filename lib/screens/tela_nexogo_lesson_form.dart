import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TelaNexoGoLessonForm extends StatefulWidget {
  final String cursoId;
  final String ownerId;
  final Lesson? lessonToEdit;
  final int currentLessonCount;

  const TelaNexoGoLessonForm({
    super.key, 
    required this.cursoId,
    required this.ownerId,
    this.lessonToEdit,
    this.currentLessonCount = 0,
  });

  @override
  State<TelaNexoGoLessonForm> createState() => _TelaNexoGoLessonFormState();
}

class _TelaNexoGoLessonFormState extends State<TelaNexoGoLessonForm> {
  final _formKey = GlobalKey<FormState>();
  late final FirestoreService _firestoreService;
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  bool _isLoading = false;

  bool get _isEditing => widget.lessonToEdit != null;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _titleController = TextEditingController(text: widget.lessonToEdit?.title ?? '');
    _urlController = TextEditingController(text: widget.lessonToEdit?.videoUrl ?? '');
  }

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updatedLesson = widget.lessonToEdit!;
        updatedLesson.title = _titleController.text.trim();
        updatedLesson.videoUrl = _urlController.text.trim();
        
        await _firestoreService.updateLesson(widget.ownerId, widget.cursoId, updatedLesson);
        await FirebaseFirestore.instance.collection('public_courses').doc(widget.cursoId).collection('lessons').doc(updatedLesson.id).set(updatedLesson.toMap());

      } else {
        final tempLesson = Lesson(
          id: '', // será gerado
          title: _titleController.text.trim(),
          videoUrl: _urlController.text.trim(),
          orderIndex: widget.currentLessonCount,
          createdAt: Timestamp.now(),
        );
        final docRef = await _firestoreService.addLesson(widget.ownerId, widget.cursoId, tempLesson);
        
        final finalLesson = Lesson(
          id: docRef.id,
          title: tempLesson.title,
          videoUrl: tempLesson.videoUrl,
          orderIndex: tempLesson.orderIndex,
          createdAt: tempLesson.createdAt,
        );
        await FirebaseFirestore.instance.collection('public_courses').doc(widget.cursoId).collection('lessons').doc(finalLesson.id).set(finalLesson.toMap());
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('daxugo_saveLessonSuccess'.tr()), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop();
      }
    } catch (e) {
       setState(() => _isLoading = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('daxugo_saveLessonError'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'daxugo_editLesson'.tr() : 'daxugo_newLesson'.tr()),
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
                decoration: InputDecoration(labelText: 'daxugo_lessonTitle'.tr()),
                validator: (val) => val!.trim().isEmpty ? 'daxugo_requiredField'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(labelText: 'daxugo_lessonUrl'.tr()),
                validator: (val) => val!.trim().isEmpty ? 'daxugo_urlRequired'.tr() : null,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveLesson,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('daxugo_saveLessonButton'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
