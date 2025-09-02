import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:nexo/models/models.dart';

typedef OnNodeUpdate = void Function(MindMapNodeModel);

class MindMapNodeWidget extends StatefulWidget {
  final MindMapNodeModel node;
  final OnNodeUpdate onUpdate;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onLinkAdded;
  final VoidCallback onDelete;

  const MindMapNodeWidget({
    super.key,
    required this.node,
    required this.onUpdate,
    required this.onColorChanged,
    required this.onLinkAdded,
    required this.onDelete,
  });

  @override
  State<MindMapNodeWidget> createState() => _MindMapNodeWidgetState();
}

class _MindMapNodeWidgetState extends State<MindMapNodeWidget> {
  bool _isEditing = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.node.label);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Mudar Cor'),
              onTap: () {
                Navigator.of(context).pop();
                _showColorPicker(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Adicionar Link'),
              onTap: () {
                Navigator.of(context).pop();
                _showAddLinkDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Excluir Nó'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onDelete();
              },
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Escolha uma cor'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: widget.node.color,
              onColorChanged: (color) {
                widget.onColorChanged(color);
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddLinkDialog(BuildContext context) {
    final linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar Link'),
          content: TextField(
            controller: linkController,
            decoration: const InputDecoration(hintText: "http://..."),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Adicionar'),
              onPressed: () {
                widget.onLinkAdded(linkController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          _isEditing = true;
        });
      },
      onLongPress: () => _showOptions(context),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: widget.node.color,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.black, width: 2.0),
        ),
        child: _isEditing
            ? IntrinsicWidth(
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  onSubmitted: (newLabel) {
                    setState(() {
                      widget.node.label = newLabel;
                      _isEditing = false;
                    });
                    widget.onUpdate(widget.node);
                  },
                  style: TextStyle(
                    fontSize: widget.node.fontSize,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              )
            : Text(
                widget.node.label,
                style: TextStyle(
                  fontSize: widget.node.fontSize,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}