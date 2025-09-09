import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';

class NexoHubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<NexoHub> get _hubsRef =>
      _firestore.collection('hubs').withConverter<NexoHub>(
            fromFirestore: (snapshot, _) => NexoHub.fromFirestore(snapshot),
            toFirestore: (hub, _) => hub.toMap(),
          );
          
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
          fromFirestore: (snapshot, _) => HubEvent.fromFirestore(snapshot),
          toFirestore: (event, _) => event.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addEventToHub(
    String hubId, {
    required String title,
    required DateTime date,
    String? meetLink,
    String? audience,
  }) async {
    final userProfile = await ProfileService().getUserProfile(_currentUserId!);
    if (userProfile == null) return;
    
    final newEvent = HubEvent(
      id: '', // Firestore will generate
      title: title,
      date: date,
      creatorId: userProfile.id,
      creatorUsername: userProfile.username,
      meetLink: meetLink,
      audience: audience,
    );
    await _hubsRef.doc(hubId).collection('events').add(newEvent.toMap());
  }
  
  Future<void> updateEventInHub(String hubId, String eventId, String newTitle) async {
      await _hubsRef.doc(hubId).collection('events').doc(eventId).update({'title': newTitle});
  }

  Future<void> deleteEventFromHub(String hubId, String eventId) async {
    await _hubsRef.doc(hubId).collection('events').doc(eventId).delete();
  }
  
  Stream<List<NexoHub>> getHubsForCurrentUser() {
    if (_currentUserId == null) return Stream.value([]);
    return _hubsRef
        .where('memberIds', arrayContains: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> shareDeckWithHub({
    required String hubId,
    required Baralho baralho,
    required List<Cartao> cards,
  }) async {
    if (baralho.id == null) return;
    final deckRef = _hubsRef.doc(hubId).collection('decks').doc(baralho.id);
    final cardsRef = deckRef.collection('cards');
    
    final batch = _firestore.batch();
    batch.set(deckRef, {
      'nome': baralho.nome,
      'descricao': baralho.descricao,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    for (final card in cards) {
      batch.set(cardsRef.doc(), card.toMap());
    }
    await batch.commit();
  }
    
  Future<void> shareQuizWithHub({required String hubId, required Quiz quiz}) async {
    await _hubsRef.doc(hubId).collection('quizzes').add(quiz.toMap());
  }

  // MÉTODO CORRIGIDO para incluir o ID do documento no mapa
  Stream<List<Map<String, dynamic>>> getReceivedHubInvitesStream(String userId) {
    return _firestore
        .collection('hub_invites')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id; // Adicionando o ID ao mapa
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
}
