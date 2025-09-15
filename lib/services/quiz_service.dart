import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'package:uuid/uuid.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Quiz> _getQuizzesRef() {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('quizzes')
        .withConverter<Quiz>(
          fromFirestore: (snapshot, _) => Quiz.fromFirestore(snapshot),
          toFirestore: (quiz, _) => quiz.toMap(),
        );
  }

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

    final newQuizRef = _getQuizzesRef().doc();
    final newQuiz = Quiz(
      id: newQuizRef.id,
      title: 'Prova de "$deckName"',
      ownerId: _userId,
      sourceDeckId: deckId,
      questions: questions,
      createdAt: Timestamp.now(),
    );
    
    await newQuizRef.set(newQuiz);
  }

  Stream<List<Quiz>> getQuizzesForDeckStream(String deckId) {
    return _getQuizzesRef()
        .where('sourceDeckId', isEqualTo: deckId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // MÉTODO FALTANTE ADICIONADO
  Stream<List<Quiz>> getAllQuizzesForUserStream() {
    return _getQuizzesRef()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
