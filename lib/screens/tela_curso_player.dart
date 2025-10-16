import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

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
  final TextEditingController _commentController = TextEditingController();

  late Stream<List<Lesson>> _lessonsStream;
  Stream<List<LessonComment>>? _commentsStream;

  Lesson? _currentLesson;
  List<Lesson> _allLessons = [];
  final String _iframeId = 'course-player-iframe-${DateTime.now().microsecondsSinceEpoch}';
  // Referência ao IFrame para podermos alterar o src diretamente
  late final html.IFrameElement _iframeElement;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    _iframeElement = html.IFrameElement()
      ..id = _iframeId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..allowFullscreen = true
      ..allow = 'autoplay; fullscreen; picture-in-picture';

    ui.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) {
        final div = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%';
        div.append(_iframeElement);
        return div;
      },
    );
    
    _lessonsStream = FirebaseFirestore.instance
        .collection('public_courses')
        .doc(widget.curso.id)
        .collection('lessons')
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Lesson.fromFirestore(doc)).toList());
        
    _loadInitialLesson();
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
  
  String _formatUrl(String url) {
    String videoUrl = url;
    if ((videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) && !videoUrl.contains('embed')) {
      String? videoId;
      if (videoUrl.contains('youtu.be/')) { videoId = videoUrl.split('youtu.be/').last.split('?').first.split('&').first; } 
      else if (videoUrl.contains('watch?v=')) { videoId = videoUrl.split('watch?v=').last.split('?').first.split('&').first; }
      if (videoId != null) { videoUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1&fs=1'; }
    } else if (!videoUrl.contains('autoplay=1')) {
       videoUrl = videoUrl.contains('?') ? '$videoUrl&autoplay=1' : '$videoUrl?autoplay=1';
    }
    return videoUrl;
  }

  void _selectLesson(Lesson lesson) {
    if (lesson.id == _currentLesson?.id) return;
    String videoUrl = _formatUrl(lesson.videoUrl);
    _iframeElement.src = videoUrl;

    if (mounted) {
      setState(() {
        _currentLesson = lesson;
        _commentsStream = FirebaseFirestore.instance
            .collection('public_courses')
            .doc(widget.curso.id)
            .collection('lessons')
            .doc(lesson.id)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) => LessonComment.fromFirestore(doc)).toList());
      });
    }
  }

  Future<void> _rateCourse(int rating) async {
    try {
        await _firestoreService.rateCurso(widget.curso.ownerId, widget.curso.id, _currentUserId, rating);
        if (mounted) _showToast('daxugo_rateSuccess'.tr());
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('daxugo_rateError'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red));
    }
  }
  
  Widget _buildStarRating() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('public_courses').doc(widget.curso.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox(height: 40);
        final curso = Curso.fromFirestore(snapshot.data as DocumentSnapshot<Map<String, dynamic>>);
        final ratings = curso.ratings;
        final int myRating = ratings[_currentUserId] ?? 0;
        final int totalRatings = ratings.length;
        final double avgRating = curso.averageRating;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('daxugo_rateCourse'.tr(), style: Theme.of(context).textTheme.titleLarge),
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
                Text('daxugo_ratingFeedback'.tr(namedArgs: {'avgRating': avgRating.toStringAsFixed(1), 'totalRatings': totalRatings.toString()}), style: Theme.of(context).textTheme.bodySmall)
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 1280;

    return Scaffold(
      appBar: isLargeScreen ? null : AppBar(title: Text(widget.curso.title)),
      body: StreamBuilder<List<Lesson>>(
        stream: _lessonsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
              return Center(child: Text('daxugo_saveError'.tr(namedArgs: {'error': snapshot.error.toString()})));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('daxugo_noLessonsInCourse'.tr()));
          }
          
          _allLessons = snapshot.data!;
          if (_currentLesson == null && _allLessons.isNotEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (_currentLesson == null) {
            return Center(child: Text('daxugo_lessonLoadError'.tr()));
          }

          if (isLargeScreen) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding( // AQUI ESTÁ A MUDANÇA PRINCIPAL
                    padding: const EdgeInsets.symmetric(horizontal: 48.0), // Adiciona margens laterais
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final videoHeight = constraints.maxWidth * (9 / 16);
                        return Column(
                          children: [
                            SizedBox(
                              width: constraints.maxWidth,
                              height: videoHeight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0), // Apenas padding superior para o vídeo
                                child: HtmlElementView(viewType: _iframeId),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildContentBelowVideo(_currentLesson!),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                _buildLessonListSidebar(context, _allLessons),
              ],
            );
          } else {
            return _buildMainContent(context, _currentLesson!);
          }
        },
      ),
      drawer: !isLargeScreen ? Drawer(child: _buildLessonListSidebar(context, _allLessons)) : null,
    );
  }

  Widget _buildLessonListSidebar(BuildContext context, List<Lesson> lessons) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 1280;
    return Container(
      width: 320, 
      color: Theme.of(context).appBarTheme.backgroundColor, 
      height: MediaQuery.of(context).size.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLargeScreen)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(), 
                    ),
                  if (isLargeScreen) const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 8.0 : 0),
                    child: Text(widget.curso.title, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF374151)),
          Expanded(
            child: ListView.builder(
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                final bool isSelected = _currentLesson != null && lesson.id == _currentLesson!.id;
                return Material(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent,
                  child: ListTile(
                    leading: Icon(lesson.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: lesson.completed ? Colors.greenAccent : Colors.grey),
                    title: Text(lesson.title, style: TextStyle(color: Colors.white, decoration: lesson.completed ? TextDecoration.lineThrough : TextDecoration.none)),
                    onTap: () {
                      _selectLesson(lesson);
                      if (!isLargeScreen) { Navigator.pop(context); }
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AspectRatio( 
              aspectRatio: 16 / 9,
              child: HtmlElementView(viewType: _iframeId),
            ),
          ),
          _buildContentBelowVideo(lesson),
        ],
      ),
    );
  }

  Widget _buildContentBelowVideo(Lesson lesson) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLessonHeader(context, lesson),
          const Divider(height: 48),
          _buildStarRating(), 
          const Divider(height: 48),
          _buildCommentsSection(context, lesson), 
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildLessonHeader(BuildContext context, Lesson lesson) {
    final isOwner = _currentUserId == widget.curso.ownerId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if (isOwner)
          ElevatedButton.icon(
            onPressed: lesson.completed ? null : () async {
              setState(() {
                lesson.completed = true;
              });
              await _firestoreService.updateLesson(widget.curso.ownerId, widget.curso.id, lesson);
              _showToast('daxugo_lessonCompleteToast'.tr());
            },
            icon: const Icon(Icons.check_circle_outline),
            label: Text(lesson.completed ? 'daxugo_lessonCompleted'.tr() : 'daxugo_markLessonComplete'.tr()),
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
        Text('daxugo_lessonComments'.tr(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        TextField(controller: _commentController, decoration: InputDecoration(hintText: 'daxugo_leaveCommentHint'.tr(), filled: true, border: const OutlineInputBorder(borderSide: BorderSide.none)), maxLines: 3),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () async {
              if (_commentController.text.trim().isNotEmpty) {
                if (currentUserProfile == null) return; 
                final newComment = LessonComment(id: '', authorId: currentUserProfile.id, authorUsername: currentUserProfile.username, authorPhotoUrl: currentUserProfile.photoUrl, text: _commentController.text.trim(), createdAt: Timestamp.now());
                await FirebaseFirestore.instance
                  .collection('public_courses').doc(widget.curso.id)
                  .collection('lessons').doc(lesson.id)
                  .collection('comments').add(newComment.toMap());
                _commentController.clear();
                _showToast('daxugo_commentSuccess'.tr());
              }
            },
            child: Text('daxugo_publishCommentButton'.tr()),
          ),
        ),
        const SizedBox(height: 32),
        StreamBuilder<List<LessonComment>>(
          stream: _commentsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.active || !snapshot.hasData) {
              return Center(child: Text('daxugo_loadingComments'.tr()));
            }
            if (snapshot.data!.isEmpty) return Center(child: Text('daxugo_noComments'.tr()));
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
