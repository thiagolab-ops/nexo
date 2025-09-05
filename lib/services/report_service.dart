import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _reportsRef = FirebaseFirestore.instance.collection('reports');

  // Método para enviar uma nova denúncia
  Future<void> submitReport(ReportModel report) async {
    try {
      await _reportsRef.add(report.toMap());
    } catch (e) {
      print('Erro ao enviar denúncia: $e');
      throw Exception('Não foi possível enviar a denúncia. Tente novamente mais tarde.');
    }
  }

  // NOVO: Método para buscar o stream de denúncias
  Stream<List<ReportModel>> getReportsStream() {
    return _reportsRef
        .where('status', isEqualTo: 'new') // Mostra apenas as denúncias não resolvidas
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Criando uma instância do modelo a partir dos dados do Firestore
              return ReportModel(
                id: doc.id,
                reporterId: data['reporterId'],
                reportedUserId: data['reportedUserId'],
                contentId: data['contentId'],
                contentType: data['contentType'],
                reason: data['reason'],
                createdAt: data['createdAt'],
                status: data['status'],
              );
            }).toList());
  }
  
  // NOVO: Método para atualizar o status de uma denúncia (ex: marcar como resolvida)
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    await _reportsRef.doc(reportId).update({'status': newStatus});
  }
}
