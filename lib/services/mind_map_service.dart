import 'package:cloud_firestore/cloud_firestore.dart';
// CORREÇÃO: Importando a definição centralizada do modelo.
import 'package:nexo/models/mind_map_node.dart'; 

class MindMapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference _getMindMapRef(String hubId) {
    return _firestore
        .collection('hubs')
        .doc(hubId)
        .collection('mind_maps')
        .doc('main');
  }

  Future<void> saveMindMap(String hubId, List<MindMapNode> nodes) async {
    final List<Map<String, dynamic>> nodesData =
        nodes.map((node) => node.toJson()).toList();
    await _getMindMapRef(hubId).set({'nodes': nodesData});
  }

  Stream<List<MindMapNode>> getMindMapStream(String hubId) {
    return _getMindMapRef(hubId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return [];
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      final nodesData = data?['nodes'] as List<dynamic>? ?? [];
      return nodesData
          .map((nodeData) => MindMapNode.fromJson(nodeData as Map<String, dynamic>))
          .toList();
    });
  }
}
