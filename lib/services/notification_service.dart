import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationModel.fromFirestore(doc);
      }).toList();
    });
  }

  Stream<int> getUnreadNotificationCountStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // --- NOVA FUNÇÃO ADICIONADA ---
  Future<void> markAllNotificationsAsRead(String userId) async {
    // 1. Encontra todos os documentos não lidos
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return; // Nada para marcar
    }

    // 2. Cria uma operação em lote (batch) para eficiência
    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    // 3. Executa todas as atualizações de uma vez
    await batch.commit();
  }
}
