import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class NexoPadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // REMOVIDO: final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference _getDocsRef() {
    // ADICIONADO: Pega o ID do usuário aqui, no momento do uso.
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuário não autenticado. Não é possível obter referência.');
    }
    return _firestore.collection('users').doc(userId).collection('nexo_pad_documents');
  }

  Stream<List<NexoPadDocument>> getDocumentsStream() {
    // _getDocsRef() agora lida com a autenticação
    return _getDocsRef()
      .orderBy('lastEdited', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => NexoPadDocument.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<NexoPadDocument> createNewDocument() async {
    final newDocRef = _getDocsRef().doc(); 
    final newDoc = NexoPadDocument(
      id: newDocRef.id, 
      title: 'Novo Documento',
      ownerId: newDocRef.parent.parent!.id, // Pega o ID do usuário da referência
      contentJson: '[{"insert":"\\n"}]',
      createdAt: Timestamp.now(),
      lastEdited: Timestamp.now(),
    );
    await newDocRef.set(newDoc.toMap());
    return newDoc;
  }

  Future<void> updateDocument(NexoPadDocument document) async {
    // CORREÇÃO: Usamos um mapa explícito em vez de toMap() 
    await _getDocsRef().doc(document.id).update({
      'title': document.title,
      'contentJson': document.contentJson,
      'lastEdited': document.lastEdited,
      'lastEditorId': document.lastEditorId,
      'lastEditorUsername': document.lastEditorUsername,
    });
  }

  Future<void> deleteDocument(String docId) async {
    await _getDocsRef().doc(docId).delete();
  }
}
