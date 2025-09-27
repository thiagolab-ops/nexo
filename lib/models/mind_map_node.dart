import 'dart:ui';

// A definição da classe MindMapNode agora vive em seu próprio arquivo.
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

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'],
      text: json['text'],
      position: Offset(json['position']['dx'], json['position']['dy']),
      parentId: json['parentId'],
      isCollapsed: json['isCollapsed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'position': {'dx': position.dx, 'dy': position.dy},
    'parentId': parentId,
    'isCollapsed': isCollapsed,
  };
}
