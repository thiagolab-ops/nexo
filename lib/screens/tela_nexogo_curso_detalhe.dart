import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexogo_lesson_form.dart';
import 'package:nexo/screens/tela_video_player_generica.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';

class TelaNexoGoCursoDetalhe extends StatefulWidget {
  final Curso curso;
  const TelaNexoGoCursoDetalhe({super.key, required this.curso});

  @override
  State<TelaNexoGoCursoDetalhe> createState() => _TelaNexoGoCursoDetalheState();
}

class _TelaNexoGoCursoDetalheState extends State<TelaNexoGoCursoDetalhe> {
  late final FirestoreService _firestoreService;
  late List<Lesson> _lessons; 

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _lessons = [];
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Lesson item = _lessons.removeAt(oldIndex);
    _lessons.insert(newIndex, item);

    setState(() {}); 

    for (int i = 0; i < _lessons.length; i++) {
      _lessons[i].orderIndex = i;
    }
    // Atualiza a ordem na coleção privada
    await _firestoreService.updateLessonOrder(widget.curso.ownerId, widget.curso.id, _lessons);
    
    // Atualiza a ordem na coleção pública também
    final batch = FirebaseFirestore.instance.batch();
    for (var lesson in _lessons) {
      final publicLessonRef = FirebaseFirestore.instance.collection('public_courses').doc(widget.curso.id).collection('lessons').doc(lesson.id);
      batch.update(publicLessonRef, {'orderIndex': lesson.orderIndex});
    }
    await batch.commit();
  }

  void _deleteLesson(Lesson lesson) async {
     final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('daxugo_deleteLessonTitle'.tr()),
        content: Text('daxugo_deleteLessonConfirmation'.tr(namedArgs: {'lessonTitle': lesson.title})),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('cancelButton'.tr())),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('hubDetail_deleteButton'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Deleta da coleção privada
      await _firestoreService.deleteLesson(widget.curso.ownerId, widget.curso.id, lesson.id);
      // Deleta da coleção pública
      await FirebaseFirestore.instance.collection('public_courses').doc(widget.curso.id).collection('lessons').doc(lesson.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.curso.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'daxugo_linkCourseToHub'.tr(),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('daxugo_linkCourseToHub_Soon'.tr())));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Lesson>>(
        stream: _firestoreService.streamLessons(widget.curso.ownerId, widget.curso.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _lessons.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('daxugo_saveError'.tr(namedArgs: {'error': snapshot.error.toString()})));
          }
          if (snapshot.hasData) {
            _lessons = snapshot.data!; 
          }
          if (_lessons.isEmpty) {
            return Center(child: Text('daxugo_noLessons'.tr(), textAlign: TextAlign.center));
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _lessons.length,
            itemBuilder: (context, index) {
              final lesson = _lessons[index];
              final thumbnailUrl = lesson.thumbnailUrl;

              return Card(
                key: ValueKey(lesson.id), 
                child: ListTile(
                  leading: thumbnailUrl.isNotEmpty
                    ? Image.network(thumbnailUrl, width: 100, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.play_circle_fill_outlined, color: Colors.redAccent))
                    : const Icon(Icons.play_circle_fill_outlined, color: Colors.redAccent, size: 40),
                  title: Text(lesson.title),
                  subtitle: Text(lesson.videoUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'daxugo_editLesson'.tr(),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TelaNexoGoLessonForm(
                            cursoId: widget.curso.id,
                            ownerId: widget.curso.ownerId,
                            lessonToEdit: lesson,
                          ),
                        )),
                      ),
                       IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        tooltip: 'daxugo_deleteLessonTitle'.tr(),
                        onPressed: () => _deleteLesson(lesson),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => TelaVideoPlayerGenerica(videoUrl: lesson.videoUrl, videoTitle: lesson.title),
                    ));
                  },
                ),
              );
            },
            onReorder: _onReorder,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => TelaNexoGoLessonForm(
              cursoId: widget.curso.id,
              ownerId: widget.curso.ownerId,
              currentLessonCount: _lessons.length,
            ),
          ));
        },
        tooltip: 'daxugo_addLessonTooltip'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
