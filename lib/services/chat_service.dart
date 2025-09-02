import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<ChatRoom> get _chatRoomsRef =>
      _firestore.collection('chatRooms').withConverter<ChatRoom>(
            fromFirestore: (snapshot, _) => ChatRoom.fromFirestore(snapshot),
            toFirestore: (room, _) => room.toMap(),
          );

  Future<ChatRoom?> getChatRoomById(String roomId) async {
    final doc = await _chatRoomsRef.doc(roomId).get();
    return doc.data();
  }
  
  Future<ChatRoom?> createChatRoom(ChatRoom chatRoom) async {
    final docRef = _chatRoomsRef.doc();
    final newRoom = ChatRoom(
      id: docRef.id,
      type: chatRoom.type,
      memberIds: chatRoom.memberIds,
      hubId: chatRoom.hubId,
      memberInfo: chatRoom.memberInfo,
      lastMessage: chatRoom.lastMessage,
      lastMessageTimestamp: chatRoom.lastMessageTimestamp,
      createdAt: chatRoom.createdAt,
    );
    await docRef.set(newRoom);
    return newRoom;
  }

  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    return _chatRoomsRef
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _chatRoomsRef
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .withConverter<ChatMessage>(
            fromFirestore: (snapshot, _) => ChatMessage.fromFirestore(snapshot),
            toFirestore: (_, __) => {})
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
  
  Future<void> sendMessage({
    required String roomId,
    required String text,
    required String senderId,
  }) async {
    if (text.trim().isEmpty) return;
    final messageData = {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch();
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();
    batch.set(messageRef, messageData);
    batch.update(roomRef, {
      'lastMessage': text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<ChatRoom> getOrCreateDmRoom(UserModel currentUser, UserModel otherUser) async {
    final roomId = currentUser.id.hashCode <= otherUser.id.hashCode
        ? '${currentUser.id}_${otherUser.id}'
        : '${otherUser.id}_${currentUser.id}';
    final roomRef = _chatRoomsRef.doc(roomId);
    final docSnapshot = await roomRef.get();
    if (docSnapshot.exists) {
      return docSnapshot.data()!;
    } else {
      final newRoom = ChatRoom(
        id: roomId,
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
}
