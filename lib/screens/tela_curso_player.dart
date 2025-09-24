import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

class TelaCursoPlayer extends StatefulWidget {
  final Curso curso;
  final UserModel profProfile;
  final FirestoreService firestoreService;

  // --- CORREÇÃO DEFINITIVA USANDO INICIALIZADOR ---
  // O parâmetro 'firestoreService' agora é opcional e nullable
  TelaCursoPlayer({
    super.key,
    required this.curso,
    required this.profProfile,
    FirestoreService? firestoreService,
  }) : firestoreService = firestoreService ?? FirestoreService(); // O valor padrão é atribuído aqui

  @override
  State<TelaCursoPlayer> createState() => _TelaCursoPlayerState();
}

class _TelaCursoPlayerState extends State<TelaCursoPlayer> {
  late final String _currentUserId;
  late final WebViewController _webViewController;
  final TextEditingController _commentController = TextEditingController();

  late Stream<List<Lesson>> _lessonsStream;
  Stream<List<LessonComment>>? _commentsStream;

  Lesson? _currentLesson;
  List<Lesson> _allLessons = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;

    _webViewController = WebViewController();

    if (!kIsWeb) {
      _webViewController
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000));
    }

    _lessonsStream = widget.firestoreService.streamLessons(widget.curso.ownerId, widget.curso.id);
    _loadInitialLesson();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showToast(String message) {
    Fluttertoast.showToast(msg: message, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, backgroundColor: Colors.green, textColor: Colors.white, fontSize: 16.0, webBgColor: "linear-gradient(to right, #00b09b, #96c93d)", timeInSecForIosWeb: 3);
  }

  void _loadInitialLesson() async {
    final lessons = await _lessonsStream.first;
    if (lessons.isNotEmpty && mounted) {
      final firstUncompleted = lessons.firstWhere((l) => !l.completed, orElse: () => lessons.first);
      _selectLesson(firstUncompleted);
    }
  }
  
  void _selectLesson(Lesson lesson) {
    if (lesson.id == _currentLesson?.id) return;
    
    String videoUrl = lesson.videoUrl;
    if ((videoUrl.contains('youtube.com') || videoUrl.contains('vimeo.com')) && !videoUrl.contains('autoplay=1')) {
       videoUrl = videoUrl.contains('?') ? '${videoUrl}&autoplay=1' : '${videoUrl}?autoplay=1';
    }
    if ((videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) && !videoUrl.contains('embed')) {
      String? videoId;
      if (videoUrl.contains('youtu.be/')) { videoId = videoUrl.split('youtu.be/').last.split('?').first.split('&').first; } 
      else if (videoUrl.contains('watch?v=')) { videoId = videoUrl.split('watch?v=').last.split('?').first.split('&').first; }
      if (videoId != null) { videoUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1'; }
    }
    _webViewController.loadRequest(Uri.parse(videoUrl));
    if (mounted) {
      setState(() {
        _currentLesson = lesson;
        _commentsStream = widget.firestoreService.streamLessonComments(widget.curso.ownerId, widget.curso.id, lesson.id);
      });
    }
  }

  Future<void> _rateCourse(int rating) async {
    try {
        await widget.firestoreService.rateCurso(widget.curso.ownerId, widget.curso.id, _currentUserId, rating);
        if (mounted) _showToast('Avaliação enviada!');
    } catch(e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar avaliação: $e'), backgroundColor: Colors.red));
    }
  }
  
  Widget _buildStarRating() {
    return StreamBuilder<DocumentSnapshot<Curso>>(
      stream: widget.firestoreService.getCursoStream(widget.curso.ownerId, widget.curso.id),
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
                    icon: Icon(starNum <= myRating ? Icons.star : Icons.star_border, color: Colors.amber),
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
    return StreamBuilder<List<Lesson>>(
      stream: _lessonsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        _allLessons = snapshot.data!;
        if (_currentLesson == null && _allLessons.isNotEmpty) {
          _loadInitialLesson();
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator(color: Colors.white,)));
        }
        if (_currentLesson == null) {
          return Scaffold(appBar: AppBar(title: Text(widget.curso.title)), body: const Center(child: Text('Este curso ainda não tem aulas.')));
        }

        bool isLargeScreen = MediaQuery.of(context).size.width > 900;
        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLessonListSidebar(context, _allLessons),
                Expanded(child: _buildMainContent(context, _currentLesson!)),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: Text(_currentLesson!.title, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis)),
            drawer: Drawer(child: _buildLessonListSidebar(context, _allLessons)),
            body: _buildMainContent(context, _currentLesson!),
          );
        }
      },
    );
  }

  Widget _buildLessonListSidebar(BuildContext context, List<Lesson> lessons) {
    return Container(
      width: 320, 
      color: Theme.of(context).appBarTheme.backgroundColor, 
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          SafeArea(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(widget.curso.title, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)))),
          const Divider(height: 1, color: Color(0xFF374151)),
          Expanded(
            child: ListView.builder(
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                final bool isSelected = lesson.id == _currentLesson!.id;
                return Material(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent,
                  child: ListTile(
                    leading: Icon(lesson.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: lesson.completed ? Colors.greenAccent : Colors.grey),
                    title: Text(lesson.title, style: TextStyle(color: Colors.white, decoration: lesson.completed ? TextDecoration.lineThrough : TextDecoration.none)),
                    onTap: () {
                      _selectLesson(lesson);
                      if (MediaQuery.of(context).size.width <= 900) { Navigator.pop(context); }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, Lesson lesson) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: WebViewWidget(controller: _webViewController)),
          Padding(
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
          ),
        ],
      ),
    );
  }

  Widget _buildLessonHeader(BuildContext context, Lesson lesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: lesson.completed ? null : () async {
            lesson.completed = true;
            await widget.firestoreService.updateLesson(widget.curso.ownerId, widget.curso.id, lesson);
            _showToast('Aula marcada como concluída!');
          },
          icon: const Icon(Icons.check_circle_outline),
          label: Text(lesson.completed ? 'Aula Concluída' : 'Marcar como concluída'),
          style: ElevatedButton.styleFrom(backgroundColor: lesson.completed ? Colors.grey[700] : Colors.green, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(BuildContext context, Lesson lesson) {
    final currentUserProfile = context.watch<UserModel?>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comentários da Aula', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        TextField(controller: _commentController, decoration: const InputDecoration(hintText: 'Deixe seu comentário...', filled: true, border: OutlineInputBorder(borderSide: BorderSide.none)), maxLines: 3),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () async {
              if (_commentController.text.trim().isNotEmpty) {
                if (currentUserProfile == null) return; 
                final newComment = LessonComment(id: '', authorId: currentUserProfile.id, authorUsername: currentUserProfile.username, authorPhotoUrl: currentUserProfile.photoUrl, text: _commentController.text.trim(), createdAt: Timestamp.now());
                await widget.firestoreService.addLessonComment(widget.curso.ownerId, widget.curso.id, lesson.id, newComment);
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