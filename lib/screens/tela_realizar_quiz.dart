import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'tela_resultados_quiz.dart';

class TelaRealizarQuiz extends StatefulWidget {
  final Quiz quiz;
  const TelaRealizarQuiz({super.key, required this.quiz});

  @override
  State<TelaRealizarQuiz> createState() => _TelaRealizarQuizState();
}

class _TelaRealizarQuizState extends State<TelaRealizarQuiz> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answerSubmitted = false;

  void _submitAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
      _answerSubmitted = true;
      if (answer == widget.quiz.questions[_currentQuestionIndex].correctAnswer) {
        _score++;
      }
    });

    Timer(const Duration(seconds: 2), () {
      if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _answerSubmitted = false;
        });
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TelaResultadosQuiz(
              score: _score,
              totalQuestions: widget.quiz.questions.length,
            ),
          ),
        );
      }
    });
  }

  Color _getOptionColor(String option) {
    if (!_answerSubmitted) return Colors.grey[800]!;
    if (option == widget.quiz.questions[_currentQuestionIndex].correctAnswer) {
      return Colors.green.shade700;
    }
    if (option == _selectedAnswer) {
      return Colors.red.shade700;
    }
    return Colors.grey[800]!;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.quiz.questions[_currentQuestionIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Questão ${_currentQuestionIndex + 1} de ${widget.quiz.questions.length}'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Text(
                    question.questionText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: ListView(
                children: question.options.map((option) {
                  return Card(
                    color: _getOptionColor(option),
                    child: ListTile(
                      title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      onTap: _answerSubmitted ? null : () => _submitAnswer(option),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
