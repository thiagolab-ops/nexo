import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_realizar_quiz.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/quiz_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaQuizzesLista extends StatelessWidget {
  final String deckId;
  final String deckName;
  const TelaQuizzesLista({super.key, required this.deckId, required this.deckName});

  void _showShareQuizDialog(BuildContext context, Quiz quiz) {
    final hubService = context.read<NexoHubService>();
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<NexoHub>>(
          stream: hubService.getHubsForCurrentUser(),
          builder: (context, snapshot) {
             if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
             if (snapshot.data!.isEmpty) {
              return AlertDialog(
                title: const Text('Compartilhar Prova'),
                content: const Text('Você precisa ser membro de um Hub para compartilhar.'),
                actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')) ],
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
                         await hubService.shareQuizWithHub(hubId: hub.id, quiz: quiz);
                         if (context.mounted) {
                           Navigator.of(context).pop();
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prova compartilhada em "${hub.name}"!'), backgroundColor: Colors.green));
                         }
                      },
                    );
                  },
                ),
              ),
             );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizService = context.read<QuizService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Provas de "$deckName"'),
      ),
      body: StreamBuilder<List<Quiz>>(
        // CORREÇÃO AQUI: de widget.deckId para apenas deckId
        stream: quizService.getQuizzesForDeckStream(deckId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma prova gerada para este baralho.'));
          }
          
          final quizzes = snapshot.data!;
          
          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(quiz.title),
                subtitle: Text('${quiz.questions.length} questões'),
                trailing: IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Compartilhar no Hub',
                  onPressed: () => _showShareQuizDialog(context, quiz),
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaRealizarQuiz(quiz: quiz),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
