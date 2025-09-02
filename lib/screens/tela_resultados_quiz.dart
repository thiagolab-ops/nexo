import 'package:flutter/material.dart';

class TelaResultadosQuiz extends StatelessWidget {
  final int score;
  final int totalQuestions;
  const TelaResultadosQuiz({super.key, required this.score, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Prova'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Você acertou',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              '$score / $totalQuestions',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Pop 2 vezes para voltar para a lista de quizzes
                Navigator.of(context)..pop()..pop();
              },
              child: const Text('Voltar para a Lista de Provas'),
            ),
          ],
        ),
      ),
    );
  }
}
