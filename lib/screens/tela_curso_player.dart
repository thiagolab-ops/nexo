import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< IMPORT QUE FALTAVA

class TelaCursoPlayer extends StatefulWidget {
  final Curso curso;
  final UserModel profProfile; 

  const TelaCursoPlayer({
    super.key,
    required this.curso,
    required this.profProfile,
  });

  @override
  State<TelaCursoPlayer> createState() => _TelaCursoPlayerState();
}

class _TelaCursoPlayerState extends State<TelaCursoPlayer> {
  late final FirestoreService _firestoreService;
  late final String _currentUserId;
  late YoutubePlayerController _ytController;
  
  List<Lesson> _lessons = [];
  Lesson? _currentLesson;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // --- CORREÇÃO DA API ---
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: 'dQw4w9WgXcQ', // Rick Astley (placeholder)
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        color: 'red',
      ),
    );
    // --- FIM DA CORREÇÃO ---

    _loadInitialLesson();
  }

  @override
  void dispose() {
    _ytController.close();
    super.dispose();
  }

  void _loadInitialLesson() async {
    final lessons = await _firestoreService.streamLessons(widget.curso.ownerId, widget.curso.id).first;
    if (lessons.isNotEmpty) {
      _playLesson(lessons.first, isInitialLoad: true);
    }
  }
  
  void _playLesson(Lesson lesson, {bool isInitialLoad = false}) {
    final videoId = YoutubePlayerController.convertUrlToId(lesson.videoUrl);
    if (videoId != null) {
      if (isInitialLoad) {
        setState(() {
          _currentLesson = lesson;
          // --- CORREÇÃO DA API ---
          _ytController = YoutubePlayerController.fromVideoId(
            videoId: videoId,
            params: const YoutubePlayerParams(
              showControls: true,
              showFullscreenButton: true,
              color: 'red',
            ),
          );
          // --- FIM DA CORREÇÃO ---
        });
      } else {
        // --- CORREÇÃO DA API ---
        // O método correto é 'loadVideoById'
        _ytController.loadVideoById(videoId: videoId);
        // --- FIM DA CORREÇÃO ---
        setState(() {
          _currentLesson = lesson;
        });
      }
    }
  }


  Future<void> _rateCourse(int rating) async {
    try {
       await _firestoreService.rateCurso(
        widget.curso.ownerId, 
        widget.curso.id, 
        _currentUserId, 
        rating
      );
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Você avaliou este curso com $rating estrelas!'), backgroundColor: Colors.green),
         );
       }
    } catch(e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao enviar avaliação: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }
  
  Widget _buildStarRating() {
    // --- CORREÇÃO DO STREAMBUILDER ---
    // O tipo de Stream está correto (DocumentSnapshot<Curso>)
    // A função de serviço AGORA EXISTE.
    return StreamBuilder<DocumentSnapshot<Curso>>(
      stream: _firestoreService.getCursoStream(widget.curso.ownerId, widget.curso.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 40);

        final curso = snapshot.data!.data(); // Pega o objeto Curso
        if (curso == null) return const SizedBox(height: 40);

        final ratings = curso.ratings; // Agora acessa o objeto
        final int myRating = ratings[_currentUserId] ?? 0;
        final int totalRatings = ratings.length;
        final double avgRating = curso.averageRating; // Usa o getter do modelo

        // --- FIM DA CORREÇÃO ---

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avalie este curso', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
             Row(
              children: [
                ...List.generate(5, (index) {
                  final starNum = index + 1;
                  return IconButton(
                    icon: Icon(
                      starNum <= myRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => _rateCourse(starNum),
                  );
                }),
                const SizedBox(width: 12),
                Text('${avgRating.toStringAsFixed(1)} (${totalRatings} avaliações)', style: Theme.of(context).textTheme.bodySmall)
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.curso.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- CORREÇÃO DA API ---
          // O widget correto é 'YoutubePlayer'
          YoutubePlayer(
            controller: _ytController,
            aspectRatio: 16 / 9,
          ),
          // --- FIM DA CORREÇÃO ---
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_currentLesson?.title ?? 'Carregando...', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(username: widget.profProfile.username, photoUrl: widget.profProfile.photoUrl),
                  title: Text('Criado por ${widget.profProfile.username}'),
                ),
                const Divider(height: 24),
                _buildStarRating(), 
                const Divider(height: 24),
                Text('Aulas do Curso', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Lesson>>(
              stream: _firestoreService.streamLessons(widget.curso.ownerId, widget.curso.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.isEmpty) return const Center(child: Text('Este curso ainda não tem aulas.'));

                _lessons = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    final bool isPlaying = _currentLesson?.id == lesson.id;
                    
                    return Card(
                      color: isPlaying ? Theme.of(context).primaryColor.withOpacity(0.3) : null,
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${lesson.orderIndex + 1}')),
                        title: Text(lesson.title),
                        trailing: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill_outlined, color: Colors.redAccent),
                        onTap: () => _playLesson(lesson),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
