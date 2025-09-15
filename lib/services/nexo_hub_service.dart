import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';

class NexoHubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<NexoHub> get _hubsRef =>
      _firestore.collection('hubs').withConverter<NexoHub>(
            fromFirestore: (snapshot, options) => NexoHub.fromFirestore(snapshot), // Assinatura corrigida
            toFirestore: (hub, _) => hub.toMap(),
          );
          
  Future<void> createHub({required String name, String? description}) async {
    if (_currentUserId == null) return;
    final userProfile = await ProfileService().getUserProfile(_currentUserId!);
    if (userProfile == null) return;

    final newHubRef = _hubsRef.doc();
    final newChatRoomRef = _firestore.collection('chatRooms').doc(newHubRef.id);

    final newHub = NexoHub(
      id: newHubRef.id,
      name: name,
      description: description ?? '',
      ownerId: _currentUserId!,
      memberIds: [_currentUserId!],
      createdAt: Timestamp.now(),
    );

    final newChatRoom = ChatRoom(
      id: newHubRef.id,
      type: ChatRoomType.group,
      memberIds: [_currentUserId!],
      hubId: newHubRef.id,
      memberInfo: { 
        'hubName': name,
        _currentUserId!: userProfile.username,
      },
      createdAt: Timestamp.now(),
      lastMessageTimestamp: Timestamp.now(),
    );

    final batch = _firestore.batch();
    batch.set(newHubRef, newHub);
    // Assinatura corrigida para o fromFirestore do ChatRoom
    batch.set(newChatRoomRef.withConverter(fromFirestore: (s, o) => ChatRoom.fromFirestore(s), toFirestore: (ChatRoom cr, _) => cr.toMap()), newChatRoom);
    await batch.commit();
  }

  Future<NexoHub?> getHubById(String hubId) async {
    final doc = await _hubsRef.doc(hubId).get();
    return doc.data();
  }
  
  Future<List<UserModel>> getHubMembers(String hubId) async {
    final hub = await getHubById(hubId);
    if (hub == null || hub.memberIds.isEmpty) return [];
    return await ProfileService().getUsersFromIdList(hub.memberIds);
  }

  Stream<List<HubEvent>> getEventsStream(String hubId) {
    return _hubsRef
        .doc(hubId)
        .collection('events')
        .orderBy('date', descending: true)
        .withConverter<HubEvent>(
          fromFirestore: (snapshot, options) => HubEvent.fromFirestore(snapshot), // Assinatura corrigida
          toFirestore: (event, _) => event.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
  
  // MÉTODO RESTAURADO
  Stream<List<NexoHub>> getHubsForCurrentUser() {
    if (_currentUserId == null) return Stream.value([]);
    return _hubsRef
        .where('memberIds', arrayContains: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> shareDeckWithHub({required String hubId, required Baralho baralho, required List<Cartao> cards}) async {
    if (baralho.id == null) return;
    final deckRef = _firestore.collection('hubs').doc(hubId).collection('decks').doc(baralho.id);
    final cardsRef = deckRef.collection('cards');
    
    final batch = _firestore.batch();
    
    final sharedDeckData = baralho.toMap();
    sharedDeckData['originalOwnerId'] = baralho.ownerId; 
    sharedDeckData['sharedAt'] = FieldValue.serverTimestamp();
    
    batch.set(deckRef, sharedDeckData);

    for (final card in cards) {
      batch.set(cardsRef.doc(), card.toMap());
    }
    await batch.commit();
  }
  
  // MÉTODO RESTAURADO
  Future<void> shareQuizWithHub({required String hubId, required Quiz quiz}) async {
    await _firestore.collection('hubs').doc(hubId).collection('quizzes').add(quiz.toMap());
  }

  // MÉTODO RESTAURADO e CORRIGIDO
  Stream<List<Map<String, dynamic>>> getReceivedHubInvitesStream(String userId) {
    return _firestore
        .collection('hub_invites')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // MÉTODO RESTAURADO
  Future<void> acceptHubInvite(String inviteId) async {
      final docRef = _firestore.collection('hub_invites').doc(inviteId);
      await docRef.update({'status': 'accepted'});
  }

  // MÉTODO RESTAURADO
  Future<void> declineHubInvite(String inviteId) async {
      final docRef = _firestore.collection('hub_invites').doc(inviteId);
      await docRef.update({'status': 'declined'});
  }
  
  Stream<List<NexoPadDocument>> getSharedDocumentsStream(String hubId) {
    return _firestore.collection('hubs').doc(hubId).collection('documents')
        .orderBy('lastEdited', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => NexoPadDocument.fromFirestore(doc)).toList());
  }

  Stream<List<Baralho>> getSharedDecksStream(String hubId) {
    return _firestore.collection('hubs').doc(hubId).collection('decks')
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Baralho(
                id: doc.id,
                nome: data['nome'] ?? '',
                descricao: data['descricao'],
                ownerId: data['originalOwnerId']
              );
            }).toList());
  }
  
  Stream<List<Cartao>> getSharedCardsStream(String hubId, String deckId) {
     return _firestore.collection('hubs').doc(hubId).collection('decks').doc(deckId).collection('cards')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Cartao.fromMap(data);
        }).toList());
  }
  
  Stream<List<Quiz>> getSharedQuizzesStream(String hubId) {
     return _firestore.collection('hubs').doc(hubId).collection('quizzes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList());
  }

  Future<NexoPadDocument> createSharedDocumentInHub({
    required String hubId,
    required String title,
    required String ownerId,
  }) async {
    final newDocRef = _firestore.collection('hubs').doc(hubId).collection('documents').doc();
    final newDoc = NexoPadDocument(
      id: newDocRef.id,
      title: title,
      ownerId: ownerId,
      contentJson: '[{"insert":"\\n"}]',
      createdAt: Timestamp.now(),
      lastEdited: Timestamp.now(),
    );
    await newDocRef.set(newDoc.toMap());
    return newDoc;
  }
}
