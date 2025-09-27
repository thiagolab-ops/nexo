import 'dart:convert';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:nexo/services/mind_map_service.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:uuid/uuid.dart'; // Importa o gerador de ID

class MindMapNode {
  final String id;
  String text;
  Offset position;
  final List<String> children;
  final String? parentId;

  MindMapNode({
    required this.id,
    required this.text,
    required this.position,
    this.parentId,
    List<String>? children,
  }) : children = children ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'position': {'dx': position.dx, 'dy': position.dy},
        'children': children,
        'parentId': parentId,
      };

  factory MindMapNode.fromJson(Map<String, dynamic> json) => MindMapNode(
        id: json['id'],
        text: json['text'],
        position: Offset(json['position']['dx'], json['position']['dy']),
        children: List<String>.from(json['children'] ?? []),
        parentId: json['parentId'],
      );
}

class TelaMapaMental extends StatefulWidget {
  final String hubId;
  const TelaMapaMental({super.key, required this.hubId});

  @override
  _TelaMapaMentalState createState() => _TelaMapaMentalState();
}

class _TelaMapaMentalState extends State<TelaMapaMental> {
  final String _viewId = 'mind-map-iframe';
  late final MindMapService _mindMapService;
  final web.HTMLIFrameElement _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  List<MindMapNode> _nodes = []; // Mantém o estado atual dos nós

  @override
  void initState() {
    super.initState();
    _mindMapService = context.read<MindMapService>();
    
    _iframe.style.width = '100%';
    _iframe.style.height = '100%';
    _iframe.style.border = 'none';
    _iframe.sandbox.add('allow-scripts');
    _iframe.sandbox.add('allow-same-origin');
    
    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iframe,
    );
    
    _listenToMapChanges();
    _loadHtmlFromAssetsIntoIframe();
  }
  
  void _listenToMapChanges() {
    // Escuta continuamente por mudanças no Firestore
    _mindMapService.getMindMapStream(widget.hubId).listen((nodes) {
      _nodes = nodes; // Atualiza nosso estado local
      _sendDataToJs(); // Envia os novos dados para o IFrame
    });
  }

  void _loadHtmlFromAssetsIntoIframe() async {
    final String htmlContent = await rootBundle.loadString('assets/mind_map/index.html');
    _iframe.srcdoc = htmlContent;
  }
  
  // Renomeado de _loadInitialMap para um nome mais genérico
  void _sendDataToJs() {
    final nodesJson = jsonEncode(_nodes.map((n) => n.toJson()).toList());
    final message = jsonEncode({'type': 'loadMap', 'data': nodesJson}).toJS;
    
    _iframe.contentWindow?.postMessage(message, '*'.toJS);
  }

  // NOVA FUNÇÃO: Adiciona um nó
  void _addNode() {
    final newNodeId = const Uuid().v4();
    // Se não houver nós, o novo nó será filho do 'root' implícito
    // Se houver nós, será filho do primeiro nó por enquanto (lógica a ser refinada)
    final parent = _nodes.isEmpty ? null : _nodes.first.id;

    final newNode = MindMapNode(
      id: newNodeId,
      text: 'Novo Item',
      position: const Offset(200, 200), // Posição de exemplo
      parentId: parent,
    );

    // Salva a lista inteira (antigos + o novo) no Firestore
    _mindMapService.saveMindMap(widget.hubId, [..._nodes, newNode]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HtmlElementView(
        viewType: _viewId,
      ),
      // BOTÃO DE ADICIONAR NÓ
      floatingActionButton: FloatingActionButton(
        onPressed: _addNode,
        tooltip: 'Adicionar Nó',
        child: const Icon(Icons.add),
      ),
    );
  }
}
