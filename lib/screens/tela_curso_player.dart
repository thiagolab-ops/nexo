import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaCursoPlayer extends StatefulWidget {
  final Curso curso;
  final UserModel profProfile; // Precisamos do perfil do professor

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

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _launchVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link do vídeo.')),
        );
      }
    }
  }

  Future<void> _rateCourse(int rating) async {
    // Atualiza a avaliação no Firebase
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

  @override
  Widget build(BuildContext context) {
    // A avaliação do usuário atual e a média
    final int myRating = widget.curso.ratings[_currentUserId] ?? 0;
    final double avgRating = widget.curso.averageRating;
    final int totalRatings = widget.curso.ratings.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.curso.title),
      ),
      body: ListView(
        children: [
          // --- CABEÇALHO DO CURSO ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.curso.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(username: widget.profProfile.username, photoUrl: widget.profProfile.photoUrl),
                  title: Text('Criado por ${widget.profProfile.username}'),
                  subtitle: Text('Matéria Principal'), // TODO: Adicionar matéria ao modelo Curso se necessário
                ),
                const SizedBox(height: 12),
                Text(widget.curso.description),
                const Divider(height: 24),
                // --- SISTEMA DE AVALIAÇÃO ---
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
                    Text('$avgRating (${totalRatings} avaliações)', style: Theme.of(context).textTheme.bodySmall)
                  ],
                ),
                const Divider(height: 24),
                Text('Aulas do Curso', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),

          // --- LISTA DE AULAS ORDENADAS ---
          StreamBuilder<List<Lesson>>(
            stream: _firestoreService.streamLessons(widget.curso.ownerId, widget.curso.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Center(child: Text('Este curso ainda não tem aulas.'));

              final lessons = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true, // Importante para estar dentro de outro ListView
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${lesson.orderIndex + 1}')),
                    title: Text(lesson.title),
                    trailing: const Icon(Icons.play_circle_fill, color: Colors.redAccent),
                    onTap: () => _launchVideo(lesson.videoUrl),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
