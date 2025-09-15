import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class NexoPadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference _getDocsRef() {
    return _firestore.collection('users').doc(_userId).collection('nexo_pad_documents');
  }

  Stream<List<NexoPadDocument>> getDocumentsStream() {
    return _getDocsRef()
      .orderBy('lastEdited', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => NexoPadDocument.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<NexoPadDocument> createNewDocument() async {
    final newDocRef = _getDocsRef().doc(); // Gera um ID
    final newDoc = NexoPadDocument(
      id: newDocRef.id, // Passa o ID no construtor
      title: 'Novo Documento',
      ownerId: _userId!,
      contentJson: '[{"insert":"\\n"}]',
      createdAt: Timestamp.now(),
      lastEdited: Timestamp.now(),
    );
    await newDocRef.set(newDoc.toMap()); // Salva o documento com o ID correto
    return newDoc;
  }

  Future<void> updateDocument(NexoPadDocument document) async {
    await _getDocsRef().doc(document.id).update(document.toMap());
  }

  Future<void> deleteDocument(String docId) async {
    await _getDocsRef().doc(docId).delete();
  }
}
