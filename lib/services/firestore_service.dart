import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
  
  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    return user.uid;
  }

  // --- MÉTODOS DE BARALHO E CARTÕES ---

  Future<void> resetDeckProgress(String userId, String baralhoId) async {
    final cardsRef = _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).collection('cards');
    final cardsSnapshot = await cardsRef.get();
    
    if (cardsSnapshot.docs.isEmpty) return;

    final WriteBatch batch = _db.batch();
    
    for (final doc in cardsSnapshot.docs) {
      batch.update(doc.reference, {
        'proximaRevisao': Timestamp.now(),
        'intervalo': 0,
        'repeticoes': 0,
        'easeFactor': 2.5,
      });
    }
    
    await batch.commit();
  }

  Future<void> createDeckFromPost(Post post, List<Map<String, String>> cardsData) async {
    final batch = _db.batch();
    
    final newDeckRef = _db.collection('users').doc(_userId).collection('baralhos').doc();
    batch.set(newDeckRef, {
      'nome': 'Do post: ${post.text.substring(0, (post.text.length > 20) ? 20 : post.text.length)}...',
      'descricao': 'Criado a partir do post de ${post.authorUsername}',
      'criadoEm': FieldValue.serverTimestamp(),
      'ownerId': _userId,
    });

    for (final cardMap in cardsData) {
      // CORREÇÃO LÓGICA:
      // 1. Cria a referência do documento PRIMEIRO para obter um ID.
      final newCardRef = newDeckRef.collection('cards').doc();
      // 2. USA o ID obtido para criar o objeto Cartao.
      final newCard = Cartao(
        id: newCardRef.id, 
        baralhoId: newDeckRef.id,
        frente: cardMap['frente']!,
        verso: cardMap['verso']!,
      );
      batch.set(newCardRef, newCard.toMap());
    }
    
    final postRef = _db.collection('posts').doc(post.id);
    batch.update(postRef, {'deckCreationCount': FieldValue.increment(1)});

    await batch.commit();
  }

  Future<DocumentReference> addBaralho(Baralho baralho, String userId) async {
    // Ajustado para não precisar do ID do baralho, já que o Firestore gera.
    return await _db.collection('users').doc(userId).collection('baralhos').add(baralho.toMap());
  }

  Stream<List<Baralho>> getBaralhos(String userId) {
    return _db.collection('users').doc(userId).collection('baralhos')
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Baralho.fromFirestore(doc)).toList());
  }
  
  Future<void> updateBaralho(String userId, String baralhoId, String novoNome) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).update({'nome': novoNome});
  }

  Future<void> deleteBaralho(String userId, String baralhoId) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).delete();
  }

  Future<void> addCard(Cartao card, String userId, String baralhoId) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).collection('cards').doc(card.id).set(card.toMap());
  }

  Stream<List<Cartao>> getCards(String userId, String baralhoId) {
    return _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId)
        .collection('cards')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return Cartao.fromMap(doc.data()..['id'] = doc.id);
            }).toList());
  }

  Future<void> updateCard(String userId, String baralhoId, Cartao card) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId)
        .collection('cards').doc(card.id).update(card.toMap());
  }
  
  Future<void> copySharedDeck({required Baralho sharedDeck, required String hubId}) async {
    final batch = _db.batch();
    
    final newDeckRef = _db.collection('users').doc(_userId).collection('baralhos').doc();
    batch.set(newDeckRef, {
      'nome': sharedDeck.nome,
      'descricao': 'Cópia de "${sharedDeck.nome}"',
      'criadoEm': FieldValue.serverTimestamp(),
      'ownerId': _userId,
    });

    final sharedCardsSnapshot = await _db.collection('hubs').doc(hubId).collection('decks').doc(sharedDeck.id).collection('cards').get();
    
    for (final doc in sharedCardsSnapshot.docs) {
      final newCardRef = newDeckRef.collection('cards').doc();
      var cardData = doc.data();
      cardData['id'] = newCardRef.id;
      cardData['proximaRevisao'] = Timestamp.now(); 
      cardData['intervalo'] = 0;
      cardData['repeticoes'] = 0;
      cardData['easeFactor'] = 2.5;
      batch.set(newCardRef, cardData);
    }
    await batch.commit();
  }

  // --- MÉTODOS DO DAXU GO (VÍDEOS E CURSOS) ---

  CollectionReference<VideoNexo> _videosCollection(String userId) => 
    _db.collection('users').doc(userId).collection('videos').withConverter<VideoNexo>(
      fromFirestore: (doc, _) => VideoNexo.fromFirestore(doc),
      toFirestore: (video, _) => video.toMap(),
    );

  Stream<List<VideoNexo>> streamVideos(String userId) {
    return _videosCollection(userId).orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addVideo(VideoNexo video) async {
    await _videosCollection(_userId).doc(video.id).set(video);
  }

  Future<void> updateVideo(VideoNexo video) async {
    await _videosCollection(video.ownerId).doc(video.id).update(video.toMap());
  }

  Future<void> deleteVideo(String userId, String videoId) async {
    await _videosCollection(userId).doc(videoId).delete();
  }

  CollectionReference<Curso> _cursosCollection(String userId) => 
    _db.collection('users').doc(userId).collection('cursos').withConverter<Curso>(
      fromFirestore: (doc, _) => Curso.fromFirestore(doc),
      toFirestore: (curso, _) => curso.toMap(),
    );

  Stream<List<Curso>> streamCursos(String userId) {
    return _cursosCollection(userId).orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Stream<DocumentSnapshot<Curso>> getCursoStream(String userId, String cursoId) {
    return _cursosCollection(userId).doc(cursoId).snapshots();
  }

  Future<DocumentReference<Curso>> createCurso(Curso curso) async {
    return await _cursosCollection(_userId).add(curso);
  }
   
  Future<void> updateCurso(String userId, Curso curso) async {
    await _cursosCollection(userId).doc(curso.id).update(curso.toMap());
  }

  Future<void> deleteCurso(String userId, String cursoId) async {
    await _cursosCollection(userId).doc(cursoId).delete();
  }

  Future<void> rateCurso(String ownerId, String cursoId, String raterId, int rating) async {
    await _cursosCollection(ownerId).doc(cursoId).update({
      'ratings.$raterId': rating,
    });
  }

  CollectionReference<Lesson> _lessonsCollection(String userId, String cursoId) => 
    _cursosCollection(userId).doc(cursoId).collection('lessons').withConverter<Lesson>(
      fromFirestore: (doc, _) => Lesson.fromFirestore(doc),
      toFirestore: (lesson, _) => lesson.toMap(),
    );

  Stream<List<Lesson>> streamLessons(String userId, String cursoId) {
    return _lessonsCollection(userId, cursoId).orderBy('orderIndex').snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addLesson(String userId, String cursoId, Lesson lesson) async {
    await _lessonsCollection(userId, cursoId).add(lesson);
  }

  Future<void> updateLesson(String userId, String cursoId, Lesson lesson) async {
    await _lessonsCollection(userId, cursoId).doc(lesson.id).update(lesson.toMap());
  }

  Future<void> deleteLesson(String userId, String cursoId, String lessonId) async {
    await _lessonsCollection(userId, cursoId).doc(lessonId).delete();
  }

  Future<void> updateLessonOrder(String userId, String cursoId, List<Lesson> lessons) async {
    final batch = _db.batch();
    for (var lesson in lessons) {
      batch.update(_lessonsCollection(userId, cursoId).doc(lesson.id), {'orderIndex': lesson.orderIndex});
    }
    await batch.commit();
  }

  CollectionReference<LessonComment> _commentsCollection(String userId, String cursoId, String lessonId) => 
    _lessonsCollection(userId, cursoId).doc(lessonId).collection('comments').withConverter<LessonComment>(
      fromFirestore: (doc, _) => LessonComment.fromFirestore(doc),
      toFirestore: (comment, _) => comment.toMap(),
    );
  
  Stream<List<LessonComment>> streamLessonComments(String userId, String cursoId, String lessonId) {
    return _commentsCollection(userId, cursoId, lessonId).orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
  
  Future<void> addLessonComment(String userId, String cursoId, String lessonId, LessonComment comment) async {
    await _commentsCollection(userId, cursoId, lessonId).add(comment);
  }
}
