import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class NexoPadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<NexoPadDocument> get _documentsRef =>
      _firestore.collection('documents').withConverter<NexoPadDocument>(
        fromFirestore: (snapshot, _) => NexoPadDocument.fromFirestore(snapshot),
        toFirestore: (doc, _) => doc.toMap(),
      );

  Future<NexoPadDocument> createNewDocument() async {
    final newDocRef = _documentsRef.doc();
    final newDoc = NexoPadDocument(
      id: newDocRef.id,
      title: 'Novo Documento',
      contentJson: jsonEncode([]),
      ownerId: _userId,
      createdAt: Timestamp.now(),
      lastEdited: Timestamp.now(),
    );
    await newDocRef.set(newDoc);
    return newDoc;
  }

  Stream<List<NexoPadDocument>> getDocumentsStream() {
    return _documentsRef
        .where('ownerId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> updateDocument(NexoPadDocument doc) async {
    await _documentsRef.doc(doc.id).set(doc);
  }

  Future<void> updateDocumentTitle(String docId, String newTitle) async {
    await _documentsRef.doc(docId).update({'title': newTitle});
  }

  Future<void> deleteDocument(String docId) async {
    await _documentsRef.doc(docId).delete();
  }
}
