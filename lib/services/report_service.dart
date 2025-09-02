import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _reportsRef = FirebaseFirestore.instance.collection('reports');

  Future<void> submitReport(ReportModel report) async {
    try {
      await _reportsRef.add(report.toMap());
    } catch (e) {
      // Em um app real, você poderia logar este erro em um serviço de monitoramento.
      print('Erro ao enviar denúncia: $e');
      throw Exception('Não foi possível enviar a denúncia. Tente novamente mais tarde.');
    }
  }
}
