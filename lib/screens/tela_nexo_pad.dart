import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_pad_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/calculadora_flutuante.dart';

class TelaNexoPad extends StatefulWidget {
  final NexoPadDocument document;
  const TelaNexoPad({required this.document, super.key});

  @override
  State<TelaNexoPad> createState() => _TelaNexoPadState();
}

class _TelaNexoPadState extends State<TelaNexoPad> {
  late final QuillController _controller;
  final NexoPadService _nexoPadService = NexoPadService();
  final ProfileService _profileService = ProfileService();
  UserModel? _currentUserProfile;
  bool _showCalculator = false;
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadDocument();
    _fetchCurrentUserProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final profile = await _profileService.getUserProfile(currentUser.uid);
      if (mounted) setState(() => _currentUserProfile = profile);
    }
  }

  void _loadDocument() {
    try {
      if (widget.document.contentJson.isNotEmpty) {
        final json = jsonDecode(widget.document.contentJson);
        _controller = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _controller = QuillController.basic();
      }
    } catch (e) {
      _controller = QuillController.basic();
    }
  }

  void _saveDocument() async {
    final updatedDocument = NexoPadDocument(
      id: widget.document.id,
      title: widget.document.title,
      contentJson: jsonEncode(_controller.document.toDelta().toJson()),
      ownerId: widget.document.ownerId,
      lastEditorId: _currentUserProfile?.id,
      lastEditorUsername: _currentUserProfile?.username,
      createdAt: widget.document.createdAt,
      lastEdited: Timestamp.now(),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento salvo! (simulação)'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Calculadora',
            onPressed: () => setState(() => _showCalculator = !_showCalculator),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salvar',
            onPressed: _saveDocument,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // CONSTRUÇÃO CORRETA PARA v9.6.0
              QuillToolbar.simple(
                configurations: QuillSimpleToolbarConfigurations(
                  controller: _controller,
                  sharedConfigurations: const QuillSharedConfigurations(
                    locale: Locale('pt', 'BR'),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: QuillEditor.basic(
                    // CONSTRUÇÃO CORRETA PARA v9.6.0
                    configurations: QuillEditorConfigurations(
                      controller: _controller,
                      sharedConfigurations: const QuillSharedConfigurations(
                        locale: Locale('pt', 'BR'),
                      ),
                    ),
                    focusNode: _editorFocusNode,
                    scrollController: ScrollController(),
                  ),
                ),
              )
            ],
          ),
          if (_showCalculator)
            CalculadoraFlutuante(
              onClose: () => setState(() => _showCalculator = false),
              onInsert: (textToInsert) {
                final index = _controller.selection.baseOffset;
                _controller.replaceText(index, 0, '\$textToInsert ', TextSelection.collapsed(offset: index + textToInsert.length + 1));
                _editorFocusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }
}
