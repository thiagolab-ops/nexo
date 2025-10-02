import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    return user.uid;
  }

  // --- NOVA FUNÇÃO DE RESET ---
  Future<void> resetDeckProgress(String userId, String baralhoId) async {
    final cardsRef = _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).collection('cards');
    final cardsSnapshot = await cardsRef.get();
    
    if (cardsSnapshot.docs.isEmpty) {
      return; // Nada a fazer se não houver cartões
    }

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
  // --- FIM DA NOVA FUNÇÃO ---

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
      final newCardRef = newDeckRef.collection('cards').doc();
      final newCard = Cartao(
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

  Future<void> addBaralho(Baralho baralho, String userId) async {
    await _db.collection('users').doc(userId).collection('baralhos').add({
      'nome': baralho.nome,
      'descricao': baralho.descricao ?? '',
      'criadoEm': FieldValue.serverTimestamp(),
      'ownerId': baralho.ownerId ?? userId,
    });
  }

  Stream<List<Baralho>> getBaralhos(String userId) {
    return _db.collection('users').doc(userId).collection('baralhos')
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Baralho(
                id: doc.id,
                nome: data['nome'],
                descricao: data['descricao'],
                ownerId: data['ownerId'],
              );
            }).toList());
  }
  
  Future<void> updateBaralho(String userId, String baralhoId, String novoNome) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).update({'nome': novoNome});
  }

  Future<void> deleteBaralho(String userId, String baralhoId) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).delete();
  }

  Future<void> addCard(Cartao card, String userId, String baralhoId) async {
    await _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId).collection('cards').add(card.toMap());
  }

  Stream<List<Cartao>> getCards(String userId, String baralhoId) {
    return _db.collection('users').doc(userId).collection('baralhos').doc(baralhoId)
        .collection('cards')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Cartao.fromMap(data);
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
      cardData['proximaRevisao'] = Timestamp.now(); 
      cardData['intervalo'] = 0;
      cardData['repeticoes'] = 0;
      cardData['easeFactor'] = 2.5;
      batch.set(newCardRef, cardData);
    }
    await batch.commit();
  }

  CollectionReference<VideoNexo> _videoRef(String userId) {
    return _db.collection('users').doc(userId).collection('videoteca')
      .withConverter<VideoNexo>(
        fromFirestore: (doc, _) => VideoNexo.fromFirestore(doc),
        toFirestore: (video, _) => video.toMap(),
      );
  }

  Future<void> addVideo(VideoNexo video) async {
    await _videoRef(video.ownerId).add(video);
  }

  Stream<List<VideoNexo>> streamVideos(String userId) {
    return _videoRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> updateVideo(VideoNexo video) async {
    await _videoRef(video.ownerId).doc(video.id).update(video.toMap());
  }

  Future<void> deleteVideo(String userId, String videoId) async {
    await _videoRef(userId).doc(videoId).delete();
  }
  
  CollectionReference<Curso> _cursosRef(String userId) {
    return _db.collection('users').doc(userId).collection('cursos')
      .withConverter<Curso>(
        fromFirestore: (doc, _) => Curso.fromFirestore(doc),
        toFirestore: (curso, _) => curso.toMap(),
      );
  }
  
  CollectionReference<Lesson> _lessonsRef(String userId, String cursoId) {
     return _cursosRef(userId).doc(cursoId).collection('lessons')
       .withConverter<Lesson>(
         fromFirestore: (doc, _) => Lesson.fromFirestore(doc),
         toFirestore: (lesson, _) => lesson.toMap(),
       );
  }
  
  CollectionReference<LessonComment> _lessonCommentsRef(String userId, String cursoId, String lessonId) {
     return _lessonsRef(userId, cursoId).doc(lessonId).collection('comments')
       .withConverter<LessonComment>(
         fromFirestore: (doc, _) => LessonComment.fromFirestore(doc),
         toFirestore: (comment, _) => comment.toMap(),
       );
  }
  
  Future<DocumentReference<Curso>> createCurso(Curso curso) async {
    return await _cursosRef(curso.ownerId).add(curso);
  }
  
  Stream<List<Curso>> streamCursos(String userId) {
    return _cursosRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Stream<DocumentSnapshot<Curso>> getCursoStream(String userId, String cursoId) {
    return _cursosRef(userId).doc(cursoId).snapshots();
  }
  
  Future<void> updateCurso(String userId, Curso curso) async {
    await _cursosRef(userId).doc(curso.id).update(curso.toMap());
  }

  Future<void> deleteCurso(String userId, String cursoId) async {
    await _cursosRef(userId).doc(cursoId).delete();
  }

  Future<void> rateCurso(String ownerId, String cursoId, String raterUserId, int rating) async {
    final fieldToUpdate = 'ratings.$raterUserId';
    await _cursosRef(ownerId).doc(cursoId).update({
      fieldToUpdate: rating,
    });
  }
  
  Stream<List<Lesson>> streamLessons(String userId, String cursoId) {
    return _lessonsRef(userId, cursoId)
        .orderBy('orderIndex') 
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
  
  Future<void> addLesson(String userId, String cursoId, Lesson lesson) async {
    await _lessonsRef(userId, cursoId).add(lesson);
  }

  Future<void> updateLesson(String userId, String cursoId, Lesson lesson) async {
    await _lessonsRef(userId, cursoId).doc(lesson.id).update(lesson.toMap());
  }
  
  Future<void> deleteLesson(String userId, String cursoId, String lessonId) async {
    await _lessonsRef(userId, cursoId).doc(lessonId).delete();
  }
  
  Future<void> updateLessonOrder(String userId, String cursoId, List<Lesson> lessons) async {
    final batch = _db.batch();
    for (int i = 0; i < lessons.length; i++) {
      final lessonRef = _lessonsRef(userId, cursoId).doc(lessons[i].id);
      batch.update(lessonRef, {'orderIndex': i});
    }
    await batch.commit();
  }

  Stream<List<LessonComment>> streamLessonComments(String userId, String cursoId, String lessonId) {
    return _lessonCommentsRef(userId, cursoId, lessonId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addLessonComment(String userId, String cursoId, String lessonId, LessonComment comment) async {
    await _lessonCommentsRef(userId, cursoId, lessonId).add(comment);
  }
}
