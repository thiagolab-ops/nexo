import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NexoHubService {
  final FirebaseFirestore _firestore;
  final ProfileService _profileService;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  NexoHubService({
    FirebaseFirestore? firestore,
    ProfileService? profileService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileService = profileService ?? ProfileService();

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }
    return user.uid;
  }

  CollectionReference<NexoHub> get _hubsRef =>
      _firestore.collection('hubs').withConverter<NexoHub>(
            fromFirestore: (snapshot, options) => NexoHub.fromFirestore(snapshot),
            toFirestore: (hub, _) => hub.toMap(),
          );
  
  CollectionReference<ChatRoom> get _chatRoomsRef =>
      _firestore.collection('chatRooms').withConverter<ChatRoom>(
            fromFirestore: (snapshot, options) => ChatRoom.fromFirestore(snapshot),
            toFirestore: (room, _) => room.toMap(),
          );
          
  Future<void> createHub({required String name, String? description}) async {
    final userProfile = await _profileService.getUserProfile(_currentUserId);
    if (userProfile == null) return;

    final newHubRef = _hubsRef.doc();
    final newChatRoomRef = _chatRoomsRef.doc(newHubRef.id);

    final newHub = NexoHub(
      id: newHubRef.id,
      name: name,
      description: description ?? '',
      ownerId: _currentUserId,
      memberIds: [_currentUserId],
      createdAt: Timestamp.now(),
    );

    final newChatRoom = ChatRoom(
      id: newHubRef.id,
      type: ChatRoomType.group,
      memberIds: [_currentUserId],
      hubId: newHubRef.id,
      memberInfo: { 
        'hubName': name,
        _currentUserId: userProfile.username,
      },
      createdAt: Timestamp.now(),
      lastMessageTimestamp: Timestamp.now(),
    );

    final batch = _firestore.batch();
    batch.set(newHubRef, newHub);
    batch.set(newChatRoomRef, newChatRoom);
    await batch.commit();
  }
  
  Future<void> sendHubInvite({
    required String hubId,
    required String hubName,
    required String fromUserId,
    required String fromUsername,
    required UserModel toUser,
  }) async {
    await _firestore.collection('hub_invites').add({
      'hubId': hubId,
      'hubName': hubName,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'toUserId': toUser.id,
      'toUsername': toUser.username,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<NexoHub?> getHubById(String hubId) async {
    final doc = await _hubsRef.doc(hubId).get();
    return doc.data();
  }
  
  Future<List<UserModel>> getHubMembers(String hubId) async {
    final hub = await getHubById(hubId);
    if (hub == null || hub.memberIds.isEmpty) return [];
    return await _profileService.getUsersFromIdList(hub.memberIds);
  }

  Stream<List<HubEvent>> getEventsStream(String hubId) {
    return _hubsRef
        .doc(hubId)
        .collection('events')
        .orderBy('date', descending: true)
        .withConverter<HubEvent>(
          fromFirestore: (snapshot, options) => HubEvent.fromFirestore(snapshot),
          toFirestore: (event, _) => event.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addEventToHub(String hubId, { required String title, required DateTime date, String? meetLink, String? audience, }) async {
    final userProfile = await _profileService.getUserProfile(_currentUserId);
    if (userProfile == null) return;
    
    final newEvent = HubEvent(
      id: '',
      title: title,
      date: date,
      creatorId: userProfile.id,
      creatorUsername: userProfile.username,
      meetLink: meetLink,
      audience: audience,
      attendees: [], 
    );
    await _hubsRef.doc(hubId).collection('events').add(newEvent.toMap());
  }
  
  Future<void> updateEventInHub(String hubId, String eventId, String newTitle) async {
      await _hubsRef.doc(hubId).collection('events').doc(eventId).update({'title': newTitle});
  }

  Future<void> deleteEventFromHub(String hubId, String eventId) async {
    await _hubsRef.doc(hubId).collection('events').doc(eventId).delete();
  }

  Future<void> rsvpToEvent({ required String hubId, required String eventId, required String userId, required bool isAttending, }) async {
    final eventRef = _hubsRef.doc(hubId).collection('events').doc(eventId);

    if (isAttending) {
      await eventRef.update({ 'attendees': FieldValue.arrayUnion([userId]) });
    } else {
      await eventRef.update({ 'attendees': FieldValue.arrayRemove([userId]) });
    }
  }
  
  // --- LÓGICA DE EXCLUSÃO ATUALIZADA ---
  // Agora aceita apenas um argumento e chama a Cloud Function.
  Future<void> deleteHub(String hubId) async {
    final callable = _functions.httpsCallable('deleteHub');
    await callable.call({'hubId': hubId});
  }

  Stream<List<NexoHub>> getHubsForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    
    return _hubsRef
        .where('memberIds', arrayContains: user.uid)
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
  
  Future<void> shareQuizWithHub({required String hubId, required Quiz quiz}) async {
    await _firestore.collection('hubs').doc(hubId).collection('quizzes').add(quiz.toMap());
  }

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

  Future<void> acceptHubInvite(String inviteId) async {
      final docRef = _firestore.collection('hub_invites').doc(inviteId);
      await docRef.update({'status': 'accepted'});
  }

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

  Future<NexoPadDocument> createSharedDocumentInHub({ required String hubId, required String title, required String ownerId, String? initialContentJson, }) async {
    final newDocRef = _firestore.collection('hubs').doc(hubId).collection('documents').doc();
    final newDoc = NexoPadDocument(
      id: newDocRef.id,
      title: title,
      ownerId: ownerId,
      contentJson: initialContentJson ?? '[{"insert":"\\n"}]',
      createdAt: Timestamp.now(),
      lastEdited: Timestamp.now(),
      hubId: hubId,
    );
    await newDocRef.set(newDoc.toMap());
    return newDoc;
  }
  
  Future<void> updateSharedDocument(String hubId, NexoPadDocument document) async {
    final docRef = _firestore.collection('hubs').doc(hubId).collection('documents').doc(document.id);
    
    await docRef.update({
      'title': document.title,
      'contentJson': document.contentJson,
      'lastEdited': document.lastEdited,
      'lastEditorId': document.lastEditorId,
      'lastEditorUsername': document.lastEditorUsername,
    });
  }

  Future<void> deleteSharedDocument(String hubId, String docId) async {
    await _firestore.collection('hubs').doc(hubId).collection('documents').doc(docId).delete();
  }
}
