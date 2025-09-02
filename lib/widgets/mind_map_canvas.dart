import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/widgets/mind_map_node_widget.dart';

class MindMapCanvas extends StatefulWidget {
  const MindMapCanvas({super.key});

  @override
  State<MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<MindMapCanvas> {
  final List<MindMapNodeModel> _nodes = [];
  final List<MindMapEdge> _edges = [];
  final TransformationController _transformationController = TransformationController();

  void _addNode() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset center = renderBox.size.center(Offset.zero);
    final Offset transformedCenter = _transformationController.toScene(center);

    setState(() {
      final newNode = MindMapNodeModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: 'Novo Nó',
        position: transformedCenter,
      );
      _nodes.add(newNode);
    });
  }

  void _updateNode(MindMapNodeModel updatedNode) {
    setState(() {
      final index = _nodes.indexWhere((node) => node.id == updatedNode.id);
      if (index != -1) {
        _nodes[index] = updatedNode;
      }
    });
  }

  void _deleteNode(String nodeId) {
    setState(() {
      _nodes.removeWhere((node) => node.id == nodeId);
      _edges.removeWhere((edge) => edge.from == nodeId || edge.to == nodeId);
    });
  }

  void _updateNodeColor(String nodeId, Color color) {
    setState(() {
      final index = _nodes.indexWhere((node) => node.id == nodeId);
      if (index != -1) {
        _nodes[index].color = color;
      }
    });
  }

  void _addLinkToNode(String nodeId, String link) {
    setState(() {
      final index = _nodes.indexWhere((node) => node.id == nodeId);
      if (index != -1) {
        // TODO: Implementar a lógica para adicionar o link ao nó
        print('Link adicionado ao nó $nodeId: $link');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind Map'),
      ),
      body: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 4.0,
        child: Stack(
          children: [
            CustomPaint(
              painter: EdgePainter(nodes: _nodes, edges: _edges),
              size: Size.infinite,
            ),
            ..._nodes.map((node) {
              return Positioned(
                left: node.position.dx,
                top: node.position.dy,
                child: Draggable(
                  feedback: MindMapNodeWidget(
                    node: node,
                    onUpdate: _updateNode,
                    onColorChanged: (color) => _updateNodeColor(node.id, color),
                    onLinkAdded: (link) => _addLinkToNode(node.id, link),
                    onDelete: () => _deleteNode(node.id),
                  ),
                  childWhenDragging: Container(),
                  onDragEnd: (details) {
                    setState(() {
                      node.position = details.offset;
                    });
                  },
                  child: MindMapNodeWidget(
                    node: node,
                    onUpdate: _updateNode,
                    onColorChanged: (color) => _updateNodeColor(node.id, color),
                    onLinkAdded: (link) => _addLinkToNode(node.id, link),
                    onDelete: () => _deleteNode(node.id),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNode,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EdgePainter extends CustomPainter {
  final List<MindMapNodeModel> nodes;
  final List<MindMapEdge> edges;

  EdgePainter({required this.nodes, required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;

    for (final edge in edges) {
      final fromNode = nodes.firstWhere((node) => node.id == edge.from);
      final toNode = nodes.firstWhere((node) => node.id == edge.to);
      canvas.drawLine(fromNode.position, toNode.position, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
