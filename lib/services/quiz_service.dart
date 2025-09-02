import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'package:uuid/uuid.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> generateAndSaveQuiz({
    required String deckId,
    required String deckName,
    required List<Cartao> cards,
  }) async {
    cards.shuffle();
    final List<QuizQuestion> questions = [];
    for (final card in cards) {
      List<String> options = [card.verso];
      final otherCards = cards.where((c) => c.id != card.id).toList();
      otherCards.shuffle();
      for (final otherCard in otherCards) {
        if (options.length < 4) {
          options.add(otherCard.verso);
        } else {
          break;
        }
      }
      options.shuffle();
      questions.add(QuizQuestion(
        id: const Uuid().v4(), 
        questionText: card.frente,
        correctAnswer: card.verso,
        options: options,
      ));
    }

    final newQuiz = Quiz(
      id: '', // Firestore irá gerar
      title: 'Prova de "$deckName"',
      ownerId: _userId,
      sourceDeckId: deckId,
      questions: questions,
      createdAt: Timestamp.now(),
    );
    
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('quizzes')
        .add(newQuiz.toMap());
  }

  // MÉTODO ADICIONADO AQUI
  Stream<List<Quiz>> getQuizzesForDeckStream(String deckId) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('quizzes')
        .where('sourceDeckId', isEqualTo: deckId)
        .orderBy('createdAt', descending: true)
        .withConverter<Quiz>(
          fromFirestore: (snapshot, _) => Quiz.fromFirestore(snapshot),
          toFirestore: (quiz, _) => quiz.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
