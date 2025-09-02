import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'feed_service.dart'; // Import para a classe Post

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // ## INÍCIO DA MUDANÇA: Novo método para criar baralho e cartões de uma vez ##
  Future<void> createDeckFromPost(Post post, List<Map<String, String>> cardsData) async {
    final batch = _db.batch();
    
    // 1. Cria um novo documento para o baralho
    final newDeckRef = _db.collection('users').doc(_userId).collection('baralhos').doc();
    batch.set(newDeckRef, {
      'nome': 'Do post: ${post.text.substring(0, (post.text.length > 20) ? 20 : post.text.length)}...',
      'descricao': 'Criado a partir do post de ${post.authorUsername}',
      'criadoEm': FieldValue.serverTimestamp(),
    });

    // 2. Adiciona cada cartão extraído ao novo baralho
    for (final cardMap in cardsData) {
      final newCardRef = newDeckRef.collection('cards').doc();
      final newCard = Cartao(
        baralhoId: newDeckRef.id,
        frente: cardMap['frente']!,
        verso: cardMap['verso']!,
      );
      batch.set(newCardRef, newCard.toMap());
    }

    // 3. Executa todas as operações de uma vez
    await batch.commit();
  }
  // ## FIM DA MUDANÇA ##

  Future<void> addBaralho(Baralho baralho, String userId) async {
    await _db.collection('users').doc(userId).collection('baralhos').add({
      'nome': baralho.nome,
      'descricao': baralho.descricao ?? '',
      'criadoEm': FieldValue.serverTimestamp(),
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
}
