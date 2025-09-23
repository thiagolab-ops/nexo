import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
// import 'package:webview_flutter/webview_flutter.dart'; // Removido
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; 
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  final TextEditingController _commentController = TextEditingController();

  late Stream<List<Lesson>> _lessonsStream;
  Stream<List<LessonComment>>? _commentsStream;
  Lesson? _currentLesson;
  List<Lesson> _allLessons = [];
  bool _isLoadingVideo = true; 
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;

    _lessonsStream = _firestoreService.streamLessons(widget.curso.ownerId, widget.curso.id);
    
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: 'dQw4w9WgXcQ', // Placeholder
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        color: 'red',
      ),
    );
    
    _addPlayerListener();
    _loadInitialLesson();
  }

  void _addPlayerListener() {
     _ytController.listen((event) {
      final bool isReadyToPlay = event.playerState == PlayerState.cued || event.playerState == PlayerState.playing;

      if (isReadyToPlay && _isLoadingVideo) {
        if (mounted) {
          setState(() {
            _isLoadingVideo = false;
          });
        }
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _ytController.close();
    super.dispose();
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
      webBgColor: "linear-gradient(to right, #00b09b, #96c93d)",
      timeInSecForIosWeb: 3,
    );
  }

  void _loadInitialLesson() async {
    final lessons = await _lessonsStream.first;
    if (lessons.isNotEmpty) {
      final firstUncompleted = lessons.firstWhere((l) => !l.completed, orElse: () => lessons.first);
      _playLesson(firstUncompleted, isInitialLoad: true);
    }
  }
  
  void _playLesson(Lesson lesson, {bool isInitialLoad = false}) {
    if (lesson.id == _currentLesson?.id && !isInitialLoad) return; 
    
    final videoId = YoutubePlayerController.convertUrlToId(lesson.videoUrl);
    if (videoId == null) {
       _showToast('Erro: URL do vídeo inválida.');
       return;
    }

    setState(() {
      _isLoadingVideo = true;
      _currentLesson = lesson;
      _commentsStream = _firestoreService.streamLessonComments(
        widget.curso.ownerId, 
        widget.curso.id, 
        lesson.id
      );
    });
    
    if (isInitialLoad) {
      setState(() {
        _ytController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            color: 'red',
          ),
        );
        _addPlayerListener(); 
      });
    } else {
      _ytController.loadVideoById(videoId: videoId);
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
         _showToast('Avaliação enviada!');
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
    return StreamBuilder<DocumentSnapshot<Curso>>(
      stream: _firestoreService.getCursoStream(widget.curso.ownerId, widget.curso.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 40);

        final curso = snapshot.data!.data();
        if (curso == null) return const SizedBox(height: 40);

        final ratings = curso.ratings;
        final int myRating = ratings[_currentUserId] ?? 0;
        final int totalRatings = ratings.length;
        final double avgRating = curso.averageRating;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avalie este CURSO', style: Theme.of(context).textTheme.titleLarge),
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
      body: StreamBuilder<List<Lesson>>(
        stream: _lessonsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          _allLessons = snapshot.data!;
          
          if (_currentLesson == null && _allLessons.isNotEmpty) {
            _playLesson(_allLessons.first, isInitialLoad: true);
            return const Center(child: CircularProgressIndicator());
          }
    
          if (_currentLesson == null) {
            return const Center(child: Text('Este curso ainda não tem aulas.'));
          }
          
          final playerWidget = Stack(
            children: [
              YoutubePlayer(
                controller: _ytController,
                aspectRatio: 16 / 9,
              ),
              if (_isLoadingVideo)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );

          final mainContentWidget = _buildMainContent(context, _currentLesson!);

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isLargeScreen = constraints.maxWidth > 900;
    
              if (isLargeScreen) {
                // --- LAYOUT DESKTOP CORRIGIDO ---
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 320, // Largura fixa
                      color: Theme.of(context).appBarTheme.backgroundColor,
                      height: constraints.maxHeight, // Ocupa a altura do LayoutBuilder
                      child: _buildLessonListSidebar(context, _allLessons),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            playerWidget, 
                            mainContentWidget,
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // --- LAYOUT MOBILE CORRIGIDO ---
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      playerWidget, 
                      mainContentWidget,
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildLessonListSidebar(BuildContext context, List<Lesson> lessons) {
    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.curso.title,
              style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded( 
          child: ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final bool isSelected = lesson.id == _currentLesson!.id;
              return Material(
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent,
                child: ListTile(
                  leading: Icon(
                    lesson.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: lesson.completed ? Colors.greenAccent : Colors.grey,
                  ),
                  title: Text(
                    lesson.title,
                    style: TextStyle(
                      decoration: lesson.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  onTap: () {
                    _playLesson(lesson);
                    if (MediaQuery.of(context).size.width <= 900) {
                      Navigator.pop(context); 
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context, Lesson lesson) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLessonHeader(context, lesson),
          const Divider(height: 48),
          _buildStarRating(),
          const Divider(height: 48),
          _buildCommentsSection(context, lesson), 
        ],
      ),
    );
  }

  Widget _buildLessonHeader(BuildContext context, Lesson lesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lesson.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: lesson.completed
              ? null 
              : () async {
                  lesson.completed = true;
                  await _firestoreService.updateLesson(widget.curso.ownerId, widget.curso.id, lesson);
                  _showToast('Aula marcada como concluída!');
                },
          icon: const Icon(Icons.check_circle_outline),
          label: Text(lesson.completed ? 'Aula Concluída' : 'Marcar como concluída'),
          style: ElevatedButton.styleFrom(
            backgroundColor: lesson.completed ? Colors.grey[700] : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(BuildContext context, Lesson lesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comentários da Aula', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: 'Deixe seu comentário...',
            filled: true,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () async {
              if (_commentController.text.trim().isNotEmpty) {
                final profile = context.read<UserModel?>();
                if (profile == null) return; 
                
                final newComment = LessonComment(
                  id: '', 
                  authorId: profile.id,
                  authorUsername: profile.username,
                  authorPhotoUrl: profile.photoUrl,
                  text: _commentController.text.trim(),
                  createdAt: Timestamp.now(),
                );
                
                await _firestoreService.addLessonComment(
                  widget.curso.ownerId, 
                  widget.curso.id, 
                  lesson.id, 
                  newComment
                );
                
                _commentController.clear();
                _showToast('Comentário publicado!');
              }
            },
            child: const Text('Publicar'),
          ),
        ),
        const SizedBox(height: 32),
        StreamBuilder<List<LessonComment>>(
          stream: _commentsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Text('Carregando comentários...'));
            if (snapshot.data!.isEmpty) return const Center(child: Text('Seja o primeiro a comentar!'));

            final comments = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final comment = comments[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(username: comment.authorUsername, photoUrl: comment.authorPhotoUrl, radius: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comment.authorUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(comment.text),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        )
      ],
    );
  }
}
