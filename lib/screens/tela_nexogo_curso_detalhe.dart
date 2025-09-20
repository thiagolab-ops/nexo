import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexogo_lesson_form.dart';
import 'package:nexo/screens/tela_video_player_generica.dart'; // <<< IMPORTADO
import 'package:nexo/services/firestore_service.dart';
import 'package:provider/provider.dart';
// url_launcher não é mais necessário aqui

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
    // ... (lógica de reordenar, sem mudanças)
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Lesson item = _lessons.removeAt(oldIndex);
    _lessons.insert(newIndex, item);

    setState(() {}); 

    for (int i = 0; i < _lessons.length; i++) {
      _lessons[i].orderIndex = i;
    }
    await _firestoreService.updateLessonOrder(widget.curso.ownerId, widget.curso.id, _lessons);
  }

  void _deleteLesson(Lesson lesson) async {
    // ... (lógica de deletar, sem mudanças)
     final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Aula'),
        content: Text('Tem certeza que deseja excluir "${lesson.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestoreService.deleteLesson(widget.curso.ownerId, widget.curso.id, lesson.id);
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
            tooltip: 'Ligar este Curso a um Hub',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Em breve: Ligar Cursos a Hubs!')));
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
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            _lessons = snapshot.data!; 
          }
          if (_lessons.isEmpty) {
            return const Center(child: Text('Nenhuma aula adicionada.\nClique em + para criar a primeira aula.', textAlign: TextAlign.center));
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
                        onPressed: () => _deleteLesson(lesson),
                      ),
                    ],
                  ),
                  // --- ONTAP ATUALIZADO PARA O PLAYER GENÉRICO ---
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
        tooltip: 'Adicionar Aula',
        child: const Icon(Icons.add),
      ),
    );
  }
}
