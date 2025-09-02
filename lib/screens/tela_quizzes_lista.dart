import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/nexo_hub_service.dart';
import '../services/quiz_service.dart';
import 'tela_realizar_quiz.dart';

class TelaQuizzesLista extends StatefulWidget {
  final String deckId;
  final String deckName;
  const TelaQuizzesLista({super.key, required this.deckId, required this.deckName});

  @override
  State<TelaQuizzesLista> createState() => _TelaQuizzesListaState();
}

class _TelaQuizzesListaState extends State<TelaQuizzesLista> {
  final QuizService _quizService = QuizService();
  final NexoHubService _hubService = NexoHubService();

  void _showShareQuizDialog(Quiz quiz) {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<NexoHub>>(
          stream: _hubService.getHubsForCurrentUser(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) {
              return AlertDialog(
                title: const Text('Compartilhar Prova'),
                content: const Text('Você precisa participar de um Hub para compartilhar uma prova.'),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
              );
            }
            final hubs = snapshot.data!;
            return AlertDialog(
              title: const Text('Compartilhar em qual Hub?'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: hubs.length,
                  itemBuilder: (context, index) {
                    final hub = hubs[index];
                    return ListTile(
                      title: Text(hub.name),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _hubService.shareQuizWithHub(hubId: hub.id, quiz: quiz);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Prova compartilhada em "${hub.name}"!'), backgroundColor: Colors.green),
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Provas de "${widget.deckName}"'),
      ),
      body: StreamBuilder<List<Quiz>>(
        stream: _quizService.getQuizzesForDeckStream(widget.deckId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar provas: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Nenhuma prova foi gerada para este baralho ainda.'),
            );
          }

          final quizzes = snapshot.data!;
          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return ListTile(
                leading: const Icon(Icons.quiz),
                title: Text(quiz.title),
                subtitle: Text('Criada em: ${DateFormat('dd/MM/yy HH:mm').format(quiz.createdAt.toDate())}'),
                trailing: IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Compartilhar no Hub',
                  onPressed: () => _showShareQuizDialog(quiz),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TelaRealizarQuiz(quiz: quiz),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
