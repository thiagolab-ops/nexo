import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexo/screens/tela_mapa_mental.dart';

class MindMapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference _getMindMapRef(String hubId) {
    return _firestore.collection('hubs').doc(hubId).collection('mind_maps').doc('main');
  }

  Future<void> saveMindMap(String hubId, List<MindMapNode> nodes) async {
    final List<Map<String, dynamic>> nodesData = nodes.map((node) => node.toMap()).toList();
    await _getMindMapRef(hubId).set({'nodes': nodesData});
  }

  Stream<List<MindMapNode>> getMindMapStream(String hubId) {
    return _getMindMapRef(hubId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return []; // Retorna lista vazia se não houver mapa salvo
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      final nodesData = data?['nodes'] as List<dynamic>? ?? [];
      return nodesData.map((nodeData) => MindMapNode.fromMap(nodeData)).toList();
    });
  }
}
