import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'dart:math';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    return user.uid;
  }
  
  CollectionReference<Quiz> _getQuizzesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('quizzes')
        .withConverter<Quiz>(
          fromFirestore: (snapshot, _) => Quiz.fromFirestore(snapshot),
          toFirestore: (quiz, _) => quiz.toMap(),
        );
  }
  
  Future<Quiz> createQuiz({
    required String deckId,
    required String title,
    required List<Cartao> cards,
  }) async {
    if (cards.length < 4) {
      throw Exception('É preciso ter pelo menos 4 cartões para gerar uma prova.');
    }
    
    final List<QuizQuestion> questions = [];
    final random = Random();

    for (final card in cards) {
      final otherCards = cards.where((c) => c.id != card.id).toList();
      otherCards.shuffle();
      
      final options = [card.verso];
      for (int i = 0; i < 3 && i < otherCards.length; i++) {
        options.add(otherCards[i].verso);
      }
      options.shuffle(random);
      
      questions.add(QuizQuestion(
        id: card.id!,
        questionText: card.frente,
        correctAnswer: card.verso,
        options: options,
      ));
    }

    final newQuiz = Quiz(
      id: '',
      title: 'Prova Rápida: $title',
      ownerId: _currentUserId,
      sourceDeckId: deckId,
      questions: questions,
      createdAt: Timestamp.now(),
    );

    final docRef = await _getQuizzesRef(_currentUserId).add(newQuiz);
    final quizSnapshot = await docRef.get();
    return quizSnapshot.data()!;
  }
  
  // Função genérica que busca todos os quizzes de um usuário
  Stream<List<Quiz>> getQuizzesStream(String userId) {
    return _getQuizzesRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // NOVA FUNÇÃO EFICIENTE que busca apenas quizzes de um baralho específico
  Stream<List<Quiz>> getQuizzesForDeckStream(String deckId) {
    return _getQuizzesRef(_currentUserId)
        .where('sourceDeckId', isEqualTo: deckId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
