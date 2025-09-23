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

  // ESTA FUNÇÃO NÃO SERÁ MAIS USADA PELO APP BAR, MAS PODE SER ÚTIL
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
    // Esta função agora também pode decrementar o contador, mas vamos deixar
    // o "markAll" cuidar disso para economizar escritas.
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // --- FUNÇÃO ATUALIZADA ---
  Future<void> markAllNotificationsAsRead(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    final querySnapshot = await userRef
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return; // Nada para marcar
    }

    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    // --- LÓGICA DE RESET ADICIONADA ---
    // Adiciona a operação de resetar o contador no perfil do usuário ao batch
    batch.update(userRef, {'unreadNotificationCount': 0});
    // --- FIM DA LÓGICA ---
    
    await batch.commit();
  }
}
