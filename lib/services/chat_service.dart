import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class ChatService {
  FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;

  // --- MÉTODOS PARA TESTES ---
  void setFirestoreForTests(FirebaseFirestore firestore) {
    _db = firestore;
  }
  void setAuthForTests(FirebaseAuth auth) {
    _auth = auth;
  }
  // --- FIM DOS MÉTODOS PARA TESTES ---
  
  CollectionReference<ChatRoom> get _roomsRef =>
      _db.collection('chatRooms').withConverter<ChatRoom>(
            fromFirestore: (snapshot, _) => ChatRoom.fromFirestore(snapshot),
            toFirestore: (room, _) => room.toMap(),
          );

  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    return _roomsRef
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<ChatRoom?> getChatRoomById(String roomId) async {
    final doc = await _roomsRef.doc(roomId).get();
    return doc.data();
  }
  
  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _roomsRef
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .withConverter<ChatMessage>(
            fromFirestore: (snapshot, _) => ChatMessage.fromFirestore(snapshot),
            toFirestore: (message, _) => throw UnimplementedError(), // Não escrevemos aqui
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
    required String senderId,
  }) async {
    final newMessage = {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    final batch = _db.batch();
    
    final messageRef = _roomsRef.doc(roomId).collection('messages').doc();
    batch.set(messageRef, newMessage);

    final roomRef = _roomsRef.doc(roomId);
    batch.update(roomRef, {
      'lastMessage': text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
  
  Future<ChatRoom> getOrCreateDmRoom(UserModel currentUser, UserModel otherUser) async {
    final dmRoomId = (currentUser.id.hashCode <= otherUser.id.hashCode)
      ? '${currentUser.id}_${otherUser.id}'
      : '${otherUser.id}_${currentUser.id}';
      
    final roomRef = _roomsRef.doc(dmRoomId);
    final roomDoc = await roomRef.get();

    if (roomDoc.exists) {
      return roomDoc.data()!;
    } else {
      final newRoom = ChatRoom(
        id: dmRoomId,
        type: ChatRoomType.dm,
        memberIds: [currentUser.id, otherUser.id],
        memberInfo: {
          currentUser.id: currentUser.username,
          otherUser.id: otherUser.username,
        },
        createdAt: Timestamp.now(),
        lastMessageTimestamp: Timestamp.now(),
      );
      await roomRef.set(newRoom);
      return newRoom;
    }
  }

  Future<ChatRoom?> createChatRoom(ChatRoom room) async {
     try {
       await _roomsRef.doc(room.id).set(room);
       return room;
     } catch (e) {
       print(e);
       return null;
     }
  }
}
