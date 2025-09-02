import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/mind_map_service.dart';

class MindMapViewModel extends ChangeNotifier {
  final MindMapService _mindMapService = MindMapService();

  List<MindMapNodeModel> _nodes = [];
  List<MindMapNodeModel> get nodes => _nodes;

  List<MindMapEdge> _edges = [];
  List<MindMapEdge> get edges => _edges;

  String? _hubId;
  String? _mapId;

  void listenToMap(String hubId, String mapId) {
    _hubId = hubId;
    _mapId = mapId;

    _mindMapService.getNodesStream(hubId: hubId, mapId: mapId).listen((nodes) {
      _nodes = nodes;
      notifyListeners();
    });

    _mindMapService.getMindMapStream(hubId: hubId, mapId: mapId).listen((map) {
      _edges = map.edges;
      notifyListeners();
    });
  }

  Future<void> addNode(MindMapNodeModel node, {MindMapNodeModel? parentNode}) async {
    if (_hubId == null || _mapId == null) return;
    await _mindMapService.addNodeWithConnection(
      hubId: _hubId!,
      mapId: _mapId!,
      node: node,
      parentNode: parentNode,
    );
  }

  Future<void> updateNode(MindMapNodeModel node) async {
    if (_hubId == null || _mapId == null) return;
    await _mindMapService.updateNodePosition(
      hubId: _hubId!,
      mapId: _mapId!,
      nodeId: node.id,
      newPosition: node.position,
    );
    await _mindMapService.updateNodeLabel(
      hubId: _hubId!,
      mapId: _mapId!,
      nodeId: node.id,
      newLabel: node.label,
    );
  }

  Future<void> deleteNode(String nodeId) async {
    if (_hubId == null || _mapId == null) return;
    await _mindMapService.deleteNode(
      hubId: _hubId!,
      mapId: _mapId!,
      nodeId: nodeId,
    );
  }

  Future<void> createEdge(MindMapEdge edge) async {
    if (_hubId == null || _mapId == null) return;
    await _mindMapService.addEdge(
      hubId: _hubId!,
      mapId: _mapId!,
      fromNodeId: edge.from,
      toNodeId: edge.to,
    );
  }
}
