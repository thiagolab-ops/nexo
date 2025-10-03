import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:nexo/models/mind_map_node.dart';
import 'package:uuid/uuid.dart';
import 'package:nexo/services/mind_map_service.dart';
import 'package:provider/provider.dart';

class MindMapController extends ChangeNotifier {
  List<MindMapNode> _nodes = [];
  String? _selectedNodeId;
  Matrix4 _transform = Matrix4.identity();
  final MindMapService service;
  final String hubId;

  MindMapNode? editingNode;
  final TextEditingController textEditingController = TextEditingController();
  final FocusNode textFocusNode = FocusNode();

  List<MindMapNode> get nodes => _nodes;
  String? get selectedNodeId => _selectedNodeId;
  Matrix4 get transform => _transform;

  MindMapController({required this.service, required this.hubId}) {
    _loadInitialMap();
  }

  void _loadInitialMap() {
    service.getMindMapStream(hubId).listen((loadedNodes) {
      bool needsSave = false;
      if (loadedNodes.isEmpty) {
        final rootNode = MindMapNode(
          id: const Uuid().v4(),
          text: 'Ideia Central',
          position: const Offset(0, 0),
        );
        _updateNodeSize(rootNode);
        _nodes = [rootNode];
        needsSave = true;
      } else {
        _nodes = loadedNodes;
        for (var node in _nodes) { _updateNodeSize(node); }
      }
      if (_selectedNodeId == null && _nodes.isNotEmpty) {
        _selectedNodeId = _nodes.first.id;
      }
      
      if (needsSave) {
        service.saveMindMap(hubId, _nodes);
      } else {
        notifyListeners();
      }
    });
  }

  void _save() {
    service.saveMindMap(hubId, _nodes);
  }

  // --- NOVA FUNÇÃO DE RESET ---
  void resetMap() {
    if (_nodes.isEmpty) return;

    // Encontra o nó raiz (aquele sem pai)
    final rootNode = _nodes.firstWhere((node) => node.parentId == null, orElse: () => _nodes.first);
    
    // Define a lista de nós para conter apenas o nó raiz
    _nodes = [rootNode];
    _selectedNodeId = rootNode.id; // Seleciona o nó raiz

    // Salva o estado resetado no Firestore
    _save();
    notifyListeners();
  }
  // --- FIM DA NOVA FUNÇÃO ---

  void addNode() {
    if (_selectedNodeId == null) return;
    final parentNode = _getNodeById(_selectedNodeId!);
    if (parentNode == null) return;
    
    if (parentNode.isCollapsed) {
      parentNode.isCollapsed = false;
    }

    final childrenCount = _nodes.where((n) => n.parentId == _selectedNodeId).length;
    final angle = childrenCount * 1.5;
    final distance = (parentNode.size.width / 2) + 100;

    final newPosition = Offset(
      parentNode.position.dx + cos(angle) * distance,
      parentNode.position.dy + sin(angle) * distance,
    );

    final newNode = MindMapNode(
      id: const Uuid().v4(),
      text: 'Nova Ideia',
      parentId: _selectedNodeId,
      position: newPosition,
    );
    _updateNodeSize(newNode);
    _nodes.add(newNode);
    selectNode(newNode.id);
    _save();
  }

  void removeNode() {
    if (_selectedNodeId == null || _getNodeById(_selectedNodeId!)?.parentId == null) return;
    
    final parentId = _getNodeById(_selectedNodeId!)?.parentId;
    final idsToRemove = _getDescendantIds(_selectedNodeId!);
    idsToRemove.add(_selectedNodeId!);
    
    _nodes.removeWhere((node) => idsToRemove.contains(node.id));
    selectNode(parentId);
    _save();
  }

  void selectNode(String? nodeId) {
    if (editingNode != null) finishEditing();
    if (_selectedNodeId != nodeId) {
      _selectedNodeId = nodeId;
      notifyListeners();
    }
  }

  void moveNode(String nodeId, Offset delta) {
    final node = _getNodeById(nodeId);
    if (node != null) {
      node.position += delta;
      notifyListeners();
    }
  }
  
  void onMoveEnd() {
    _save();
  }
  
  void panCanvas(Offset delta) {
    final double currentScale = _transform.getMaxScaleOnAxis();
    if (currentScale > 0) {
      _transform.translate(delta.dx / currentScale, delta.dy / currentScale);
      notifyListeners();
    }
  }

  void toggleCollapse(String nodeId) {
    final node = _getNodeById(nodeId);
    if (node != null) {
        node.isCollapsed = !node.isCollapsed;
        _save();
        notifyListeners();
    }
  }

  List<MindMapNode> getVisibleNodes() {
    if (_nodes.isEmpty) return [];
    final visible = <MindMapNode>[];
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
      _save();
      notifyListeners();
    }
  }
  
  void onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.localFocalPoint;
    final newScale = details.scale;
    
    _transform.translate(focalPoint.dx, focalPoint.dy);
    _transform.scale(newScale, newScale);
    _transform.translate(-focalPoint.dx, -focalPoint.dy);
    
    notifyListeners();
  }

  void centerView(Size screenSize) {
    if (_nodes.isEmpty) return;
    final rootNode = _nodes.firstWhere((n) => n.parentId == null, orElse: () => _nodes.first);
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
      text: TextSpan(text: node.text, style: const TextStyle(fontSize: 14, color: Colors.black, fontFamily: 'Inter')),
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

class MindMapScreenNativo extends StatefulWidget {
  final MindMapController controller;
  const MindMapScreenNativo({super.key, required this.controller});

  @override
  State<MindMapScreenNativo> createState() => _MindMapScreenNativoState();
}

class _MindMapScreenNativoState extends State<MindMapScreenNativo> {
  late final MindMapController controller;
  Offset? _lastDragPosition;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    
    // --- NOVA LÓGICA DE CENTRALIZAÇÃO AUTOMÁTICA ---
    // Adiciona um callback para ser executado APÓS o primeiro frame ser desenhado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenSize = MediaQuery.of(context).size;
        controller.centerView(screenSize);
      }
    });
    // --- FIM DA NOVA LÓGICA ---

    controller.textFocusNode.addListener(() {
      if (!controller.textFocusNode.hasFocus) {
        controller.finishEditing();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            children: [
              GestureDetector(
                onTapUp: (details) {
                  final canvasTap = controller.screenToCanvas(details.localPosition);
                  String? tappedNodeId;
                  
                  for (final node in controller.getVisibleNodes().reversed) {
                      final hasChildren = controller.nodes.any((n) => n.parentId == node.id);
                      if (hasChildren) {
                        final buttonCenter = node.position + Offset(node.size.width / 2, 0);
                        if ((canvasTap - buttonCenter).distance <= 12) {
                            controller.toggleCollapse(node.id);
                            return;
                        }
                      }

                      final nodeRect = Rect.fromCenter(center: node.position, width: node.size.width, height: node.size.height);
                      if (nodeRect.contains(canvasTap)) {
                          tappedNodeId = node.id;
                          break;
                      }
                  }
                  controller.selectNode(tappedNodeId);
                },
                onScaleStart: (details) {
                  _lastDragPosition = details.localFocalPoint;
                },
                onScaleUpdate: (details) {
                  if (details.scale == 1.0 && _lastDragPosition != null) {
                    final currentDragPosition = details.localFocalPoint;
                    final delta = currentDragPosition - _lastDragPosition!;
                    
                    if (controller.selectedNodeId != null) {
                      final canvasDelta = controller.screenToCanvas(currentDragPosition) - controller.screenToCanvas(_lastDragPosition!);
                      controller.moveNode(controller.selectedNodeId!, canvasDelta);
                    } else {
                      controller.panCanvas(delta);
                    }
                    _lastDragPosition = currentDragPosition;
                  } else {
                    controller.onScaleUpdate(details);
                  }
                },
                onScaleEnd: (details) {
                  if (controller.selectedNodeId != null) {
                    controller.onMoveEnd();
                  }
                },
                child: CustomPaint(
                  painter: MindMapPainter(controller),
                  size: Size.infinite,
                ),
              ),
              _buildToolbar(screenSize),
              if (controller.editingNode != null)
                _buildTextEditor(),
            ],
          );
        },
      ),
    );
  }

  // --- BARRA DE FERRAMENTAS ATUALIZADA COM O BOTÃO DE RESET ---
  Widget _buildToolbar(Size screenSize) {
    bool isNodeSelected = controller.selectedNodeId != null;
    bool isRootSelected = isNodeSelected && controller.nodes.isNotEmpty && controller.nodes.first.id == controller.selectedNodeId;
    
    return Positioned(
      top: 20,
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
                  onPressed: isNodeSelected ? controller.addNode : null,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.green),
                  tooltip: 'Editar Nó',
                  onPressed: isNodeSelected ? () => controller.startEditing(controller.nodes.firstWhere((n) => n.id == controller.selectedNodeId)) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remover Nó',
                  onPressed: isNodeSelected && !isRootSelected ? controller.removeNode : null,
                ),
                const SizedBox(height: 24, child: VerticalDivider()),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Aumentar Zoom',
                  onPressed: () => controller.zoom(1.2, screenSize.center(Offset.zero)),
                ),
                 IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Diminuir Zoom',
                  onPressed: () => controller.zoom(1 / 1.2, screenSize.center(Offset.zero)),
                ),
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: 'Centralizar',
                  onPressed: () => controller.centerView(screenSize),
                ),
                // NOVO BOTÃO DE RESET
                IconButton(
                  icon: const Icon(Icons.replay_circle_filled_outlined, color: Colors.orangeAccent),
                  tooltip: 'Resetar Mapa',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Resetar Mapa Mental?'),
                        content: const Text('Esta ação apagará todos os nós, exceto o nó central. Esta ação não pode ser desfeita.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Resetar', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      controller.resetMap();
                      controller.centerView(screenSize);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    final node = controller.editingNode!;
    final transformedPosition = MatrixUtils.transformPoint(controller.transform, node.position);
    final transformedSize = node.size * controller.transform.getMaxScaleOnAxis();

    return Positioned(
      left: transformedPosition.dx - transformedSize.width / 2,
      top: transformedPosition.dy - transformedSize.height / 2,
      width: transformedSize.width,
      height: transformedSize.height,
      child: Material(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: TextField(
            controller: controller.textEditingController,
            focusNode: controller.textFocusNode,
            textAlign: TextAlign.center,
            maxLines: null,
            style: TextStyle(fontSize: 14 * controller.transform.getMaxScaleOnAxis()),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => controller.finishEditing(),
          ),
        ),
      ),
    );
  }
}

class MindMapPainter extends CustomPainter {
  final MindMapController controller;

  MindMapPainter(this.controller);

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
      ..color = Colors.grey
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
      ..color = const Color(0xFFEFF6FF)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isSelected ? Colors.red : Colors.blue
      ..strokeWidth = isSelected ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Inter'),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: node.size.width - 20);
    final textOffset = node.position - Offset(textPainter.width / 2, textPainter.height / 2);
    textPainter.paint(canvas, textOffset);
    
    final hasChildren = controller.nodes.any((n) => n.parentId == node.id);
    if (hasChildren) {
      _drawToggleButton(canvas, node);
    }
  }

  void _drawToggleButton(Canvas canvas, MindMapNode node) {
    final buttonCenter = node.position + Offset(node.size.width / 2, 0);
    final buttonPaint = Paint()..color = Colors.blue;
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
