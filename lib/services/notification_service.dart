import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Método CORRIGIDO para retornar o tipo de dado que a tela espera
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Explicitamente convertendo o dado para o nosso modelo
        return NotificationModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Método FALTANTE que agora está sendo adicionado
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
