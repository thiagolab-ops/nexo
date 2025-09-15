import 'package:flutter/material.dart';
import 'dart:math';
import 'package:nexo/services/mind_map_service.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:async';

// --- Modelos de Dados ---
class MindMapNode {
  String id;
  String text;
  Offset position;
  Size size;
  String? parentId;
  bool isCollapsed;

  MindMapNode({
    required this.id,
    required this.text,
    required this.position,
    this.size = const Size(150, 50),
    this.parentId,
    this.isCollapsed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'dx': position.dx,
      'dy': position.dy,
      'parentId': parentId,
      'isCollapsed': isCollapsed,
    };
  }

  factory MindMapNode.fromMap(Map<String, dynamic> map) {
    return MindMapNode(
      id: map['id'],
      text: map['text'],
      position: Offset(map['dx'], map['dy']),
      parentId: map['parentId'],
      isCollapsed: map['isCollapsed'] ?? false,
    );
  }
}

// --- Gerenciador de Estado ---
class MindMapController extends ChangeNotifier {
  List<MindMapNode> _nodes = [];
  String? _selectedNodeId;
  Matrix4 _transform = Matrix4.identity();

  MindMapNode? editingNode;
  final TextEditingController textEditingController = TextEditingController();
  final FocusNode textFocusNode = FocusNode();

  List<MindMapNode> get nodes => _nodes;
  String? get selectedNodeId => _selectedNodeId;
  Matrix4 get transform => _transform;

  MindMapController(List<MindMapNode> initialNodes) {
    if (initialNodes.isEmpty) {
      _initialize();
    } else {
      _nodes = initialNodes;
      for (var node in _nodes) {
        _updateNodeSize(node);
      }
    }
  }
  
  void updateNodes(List<MindMapNode> newNodes) {
    if (newNodes.isEmpty) {
      _initialize();
    } else {
      _nodes = newNodes;
       for (var node in _nodes) {
        _updateNodeSize(node);
      }
    }
    notifyListeners();
  }

  void _initialize() {
    final rootNode = MindMapNode(
      id: '0',
      text: 'Ideia Central',
      position: const Offset(0, 0),
    );
    _updateNodeSize(rootNode);
    _nodes.add(rootNode);
    _selectedNodeId = rootNode.id;
    notifyListeners();
  }
  
  void addNode() {
    if (_selectedNodeId == null) return;
    final parentNode = _getNodeById(_selectedNodeId!);
    if (parentNode == null) return;
    
    if (parentNode.isCollapsed) {
      parentNode.isCollapsed = false;
    }

    final childrenCount = _nodes.where((n) => n.parentId == _selectedNodeId).length;
    final angle = childrenCount * 1.57;
    final distance = (parentNode.size.width / 2) + 120;

    final newPosition = Offset(
      parentNode.position.dx + cos(angle) * distance,
      parentNode.position.dy + sin(angle) * distance,
    );

    final newNode = MindMapNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: 'Nova Ideia',
      parentId: _selectedNodeId,
      position: newPosition,
    );
    _updateNodeSize(newNode);
    _nodes.add(newNode);
    selectNode(newNode.id);
  }

  void removeNode() {
    if (_selectedNodeId == null || _getNodeById(_selectedNodeId!)?.parentId == null) return;
    
    final parentId = _getNodeById(_selectedNodeId!)?.parentId;
    final idsToRemove = _getDescendantIds(_selectedNodeId!);
    idsToRemove.add(_selectedNodeId!);
    
    _nodes.removeWhere((node) => idsToRemove.contains(node.id));
    selectNode(parentId);
  }

  void selectNode(String? nodeId) {
    if (_selectedNodeId != nodeId) {
      _selectedNodeId = nodeId;
      notifyListeners();
    }
  }

  void setNodePosition(String nodeId, Offset newPosition) {
    final node = _getNodeById(nodeId);
    if (node != null) {
      node.position = newPosition;
      notifyListeners();
    }
  }
  
  void toggleCollapse(String nodeId) {
    final node = _getNodeById(nodeId);
    if (node != null) {
        node.isCollapsed = !node.isCollapsed;
        notifyListeners();
    }
  }

  List<MindMapNode> getVisibleNodes() {
    final visible = <MindMapNode>[];
    if (_nodes.isEmpty) return visible;
    final root = _nodes.firstWhere((n) => n.parentId == null, orElse: () => _nodes.first);
    
    final queue = [root];
    visible.add(root);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!current.isCollapsed) {
        final children = _nodes.where((n) => n.parentId == current.id);
        for (final child in children) {
          visible.add(child);
          queue.add(child);
        }
      }
    }
    return visible;
  }

  void startEditing(MindMapNode node) {
    editingNode = node;
    textEditingController.text = node.text;
    textFocusNode.requestFocus();
    notifyListeners();
  }

  void finishEditing() {
    if (editingNode != null) {
      editingNode!.text = textEditingController.text;
      _updateNodeSize(editingNode!);
      editingNode = null;
      notifyListeners();
    }
  }
  
  void onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.localFocalPoint;
    final scaleDelta = details.scale;
    
    _transform.translate(focalPoint.dx, focalPoint.dy);
    _transform.scale(scaleDelta, scaleDelta);
    _transform.translate(-focalPoint.dx, -focalPoint.dy);

    notifyListeners();
  }
  
  void onPanUpdate(Offset delta) {
    _transform.translate(delta.dx, delta.dy);
    notifyListeners();
  }

  void centerView(Size screenSize) {
    if(_nodes.isEmpty) return;
    final rootNode = _nodes.firstWhere((n) => n.parentId == null);
    _transform = Matrix4.identity()
      ..translate(
        screenSize.width / 2 - rootNode.position.dx,
        screenSize.height / 2 - rootNode.position.dy,
      );
    notifyListeners();
  }
  
  void zoom(double factor, Offset center) {
     _transform.translate(center.dx, center.dy);
     _transform.scale(factor, factor);
     _transform.translate(-center.dx, -center.dy);
     notifyListeners();
  }
  
  MindMapNode? _getNodeById(String id) {
    try {
      return _nodes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
  
  List<String> _getDescendantIds(String parentId) {
    final children = _nodes.where((node) => node.parentId == parentId);
    var descendantIds = children.map((child) => child.id).toList();
    for (final child in children) {
      descendantIds.addAll(_getDescendantIds(child.id));
    }
    return descendantIds;
  }

  void _updateNodeSize(MindMapNode node) {
    final textPainter = TextPainter(
      text: TextSpan(text: node.text, style: const TextStyle(fontSize: 14, color: Colors.white, fontFamily: 'Lato')),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: 280);
    
    const minWidth = 120.0;
    const minHeight = 50.0;
    const paddingX = 30.0;
    const paddingY = 20.0;

    node.size = Size(
      max(minWidth, textPainter.width + paddingX),
      max(minHeight, textPainter.height + paddingY),
    );
  }

  Offset screenToCanvas(Offset screenOffset) {
    final inverseMatrix = Matrix4.inverted(_transform);
    final untransformed = vector.Vector4(screenOffset.dx, screenOffset.dy, 0, 1);
    final transformed = inverseMatrix.transform(untransformed);
    return Offset(transformed.x, transformed.y);
  }
}

// --- Tela Principal (AGORA SEM SCAFFOLD) ---
class TelaMapaMental extends StatefulWidget {
  final String hubId;
  const TelaMapaMental({super.key, required this.hubId});

  @override
  State<TelaMapaMental> createState() => _TelaMapaMentalState();
}

class _TelaMapaMentalState extends State<TelaMapaMental> {
  MindMapController? _controller;
  final MindMapService _mindMapService = MindMapService();
  StreamSubscription? _streamSubscription;
  
  String? _draggedNodeId;
  Offset _panStartOffset = Offset.zero;
  Offset? _dragStartCanvasPosition;
  Offset? _draggedNodeOriginalPosition;

  @override
  void initState() {
    super.initState();
    _streamSubscription = _mindMapService.getMindMapStream(widget.hubId).listen((nodes) {
      if (_controller == null) {
        setState(() {
          _controller = MindMapController(nodes);
          _controller!.addListener(() => setState(() {}));
          _controller!.textFocusNode.addListener(() {
            if (!_controller!.textFocusNode.hasFocus) {
              _controller!.finishEditing();
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted && context.size != null) _controller!.centerView(context.size!);
          });
        });
      } else {
        _controller!.updateNodes(nodes);
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
  
  void _saveMap() async {
    if (_controller != null) {
      await _mindMapService.saveMindMap(widget.hubId, _controller!.nodes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapa mental salvo com sucesso!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final screenSize = MediaQuery.of(context).size;
    
    // REMOVIDO O SCAFFOLD E APPBAR
    return Stack(
      children: [
        GestureDetector(
           onScaleStart: (details) {
            _panStartOffset = details.localFocalPoint;
            final canvasTap = _controller!.screenToCanvas(details.localFocalPoint);
            String? tappedNodeId;
            for (final node in _controller!.getVisibleNodes().reversed) {
              final nodeRect = Rect.fromCenter(center: node.position, width: node.size.width, height: node.size.height);
              if (nodeRect.contains(canvasTap)) {
                tappedNodeId = node.id;
                break;
              }
            }
            if (tappedNodeId != null) {
               setState(() {
                  _draggedNodeId = tappedNodeId;
                  _dragStartCanvasPosition = canvasTap;
                  _draggedNodeOriginalPosition = _controller!._getNodeById(tappedNodeId!)!.position;
               });
            } else {
              _panStartOffset = details.localFocalPoint;
            }
          },
          onScaleUpdate: (details) {
            if (_draggedNodeId != null) {
                final currentCanvasPosition = _controller!.screenToCanvas(details.localFocalPoint);
                final canvasDelta = currentCanvasPosition - _dragStartCanvasPosition!;
                _controller!.setNodePosition(_draggedNodeId!, _draggedNodeOriginalPosition! + canvasDelta);
            } else if (details.scale == 1.0) {
              _controller!.onPanUpdate(details.localFocalPoint - _panStartOffset);
              _panStartOffset = details.localFocalPoint;
            } else {
               _controller!.onScaleUpdate(details);
            }
          },
          onScaleEnd: (details) {
             setState(() => _draggedNodeId = null);
          },
          onTapUp: (details) {
            if (_draggedNodeId != null) {
              _draggedNodeId = null; 
              return;
            }
            final canvasTap = _controller!.screenToCanvas(details.localPosition);
            MindMapNode? tappedNode;
            for (final node in _controller!.getVisibleNodes().reversed) {
                final nodeRect = Rect.fromCenter(center: node.position, width: node.size.width, height: node.size.height);
                if (nodeRect.contains(canvasTap)) {
                    tappedNode = node;
                    break;
                }
            }
            
            if (tappedNode != null) {
              final toggleButtonRect = Rect.fromCircle(
                center: tappedNode.position + Offset(tappedNode.size.width / 2, 0),
                radius: 12,
              );
              if (toggleButtonRect.contains(canvasTap)) {
                _controller!.toggleCollapse(tappedNode.id);
              } else {
                _controller!.selectNode(tappedNode.id);
              }
            } else {
               _controller!.selectNode(null);
            }
          },
          onDoubleTapDown: (details) {
            final canvasTap = _controller!.screenToCanvas(details.localPosition);
            for (final node in _controller!.getVisibleNodes().reversed) {
                final nodeRect = Rect.fromCenter(center: node.position, width: node.size.width, height: node.size.height);
                if (nodeRect.contains(canvasTap)) {
                    _controller!.startEditing(node);
                    break;
                }
            }
          },
          child: CustomPaint(
            painter: MindMapPainter(_controller!, context),
            size: Size.infinite,
          ),
        ),
        _buildToolbar(screenSize),
        if (_controller!.editingNode != null)
          _buildTextEditor(),
        
        // Botão Salvar agora é flutuante
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'save_mindmap',
            onPressed: _saveMap,
            tooltip: 'Salvar Mapa',
            child: const Icon(Icons.save),
          ),
        )
      ],
    );
  }

  Widget _buildToolbar(Size screenSize) {
    bool isNodeSelected = _controller!.selectedNodeId != null;
    bool isRootSelected = isNodeSelected && _controller!.nodes.isNotEmpty && _controller!.nodes.first.id == _controller!.selectedNodeId;
    
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Adicionar Nó',
                  onPressed: isNodeSelected ? _controller!.addNode : null,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.greenAccent),
                  tooltip: 'Editar Nó (Duplo Clique)',
                  onPressed: isNodeSelected ? () => _controller!.startEditing(_controller!.nodes.firstWhere((n) => n.id == _controller!.selectedNodeId)) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Remover Nó',
                  onPressed: isNodeSelected && !isRootSelected ? _controller!.removeNode : null,
                ),
                const SizedBox(height: 24, child: VerticalDivider()),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Aumentar Zoom',
                  onPressed: () => _controller!.zoom(1.2, screenSize.center(Offset.zero)),
                ),
                 IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Diminuir Zoom',
                  onPressed: () => _controller!.zoom(1 / 1.2, screenSize.center(Offset.zero)),
                ),
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: 'Centralizar',
                  onPressed: () => _controller!.centerView(screenSize),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    final node = _controller!.editingNode!;
    final transformedPosition = MatrixUtils.transformPoint(_controller!.transform, node.position);
    final transformedSize = node.size * _controller!.transform.getMaxScaleOnAxis();

    return Positioned(
      left: transformedPosition.dx - transformedSize.width / 2,
      top: transformedPosition.dy - transformedSize.height / 2,
      width: transformedSize.width,
      height: transformedSize.height,
      child: Material(
        color: const Color(0xFF1F1F1F).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: TextField(
            controller: _controller!.textEditingController,
            focusNode: _controller!.textFocusNode,
            textAlign: TextAlign.center,
            maxLines: null,
            style: TextStyle(fontSize: 14 * _controller!.transform.getMaxScaleOnAxis(), color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _controller!.finishEditing(),
          ),
        ),
      ),
    );
  }
}

// --- Painter ---
class MindMapPainter extends CustomPainter {
  final MindMapController controller;
  final BuildContext context;

  MindMapPainter(this.controller, this.context);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.transform(controller.transform.storage);
    
    final visibleNodes = controller.getVisibleNodes();
    final visibleNodeIds = visibleNodes.map((n) => n.id).toSet();

    for (final node in visibleNodes) {
      if (node.parentId != null && visibleNodeIds.contains(node.parentId)) {
        final parent = controller.nodes.firstWhere((n) => n.id == node.parentId);
        _drawConnector(canvas, parent.position, node.position);
      }
    }

    for (final node in visibleNodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawConnector(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(start.dx, start.dy);
    final dx = end.dx - start.dx;
    path.cubicTo(start.dx + dx / 2, start.dy, start.dx + dx / 2, end.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  void _drawNode(Canvas canvas, MindMapNode node) {
    final rect = Rect.fromCenter(
      center: node.position,
      width: node.size.width,
      height: node.size.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final isSelected = node.id == controller.selectedNodeId;
    final paint = Paint()
      ..color = const Color(0xFF1F1F1F)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isSelected ? Theme.of(context).floatingActionButtonTheme.backgroundColor! : Theme.of(context).primaryColor
      ..strokeWidth = isSelected ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: const TextStyle(fontSize: 14, color: Colors.white, fontFamily: 'Lato'),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: node.size.width - 20);
    final textOffset = node.position - Offset(textPainter.width / 2, textPainter.height / 2);
    textPainter.paint(canvas, textOffset);
    
    final hasChildren = controller.nodes.any((n) => n.parentId == node.id);
    if (hasChildren && node.parentId != null) {
      _drawToggleButton(canvas, node);
    }
  }

  void _drawToggleButton(Canvas canvas, MindMapNode node) {
    final buttonCenter = node.position + Offset(node.size.width / 2, 0);
    final buttonPaint = Paint()..color = Theme.of(context).primaryColor;
    final iconPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

    canvas.drawCircle(buttonCenter, 10, buttonPaint);
    
    canvas.drawLine(
        buttonCenter - const Offset(5, 0),
        buttonCenter + const Offset(5, 0),
        iconPaint,
    );
    
    if (node.isCollapsed) {
       canvas.drawLine(
        buttonCenter - const Offset(0, 5),
        buttonCenter + const Offset(0, 5),
        iconPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
