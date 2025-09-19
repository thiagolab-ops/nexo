import 'dart:convert';
import 'dart:html' as html; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/nexo_pad_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/calculadora_flutuante.dart';

// Importações de PDF e Impressão
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class TelaNexoPad extends StatefulWidget {
  final NexoPadDocument document;
  const TelaNexoPad({required this.document, super.key});

  @override
  State<TelaNexoPad> createState() => _TelaNexoPadState();
}

class _TelaNexoPadState extends State<TelaNexoPad> {
  late quill.QuillController _controller;
  final NexoPadService _nexoPadService = NexoPadService();
  final NexoHubService _nexoHubService = NexoHubService();
  final ProfileService _profileService = ProfileService();
  UserModel? _currentUserProfile;
  bool _showCalculator = false;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
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
        _controller = quill.QuillController(
          document: quill.Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _controller = quill.QuillController.basic();
      }
    } catch (e) {
      _controller = quill.QuillController.basic();
    }
  }

  void _saveDocument() async {
    if (_currentUserProfile == null) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil de usuário ainda carregando... Tente novamente em 1 segundo.'), backgroundColor: Colors.orangeAccent),
        );
      }
      return; 
    }

    final updatedDocument = NexoPadDocument(
      id: widget.document.id,
      title: widget.document.title,
      contentJson: jsonEncode(_controller.document.toDelta().toJson()),
      ownerId: widget.document.ownerId,
      lastEditorId: _currentUserProfile!.id, 
      lastEditorUsername: _currentUserProfile!.username,
      createdAt: widget.document.createdAt,
      lastEdited: Timestamp.now(),
      hubId: widget.document.hubId,
    );
    
    try {
      if (widget.document.hubId != null && widget.document.hubId!.isNotEmpty) {
        await _nexoHubService.updateSharedDocument(widget.document.hubId!, updatedDocument);
      } else {
        await _nexoPadService.updateDocument(updatedDocument);
      }
    
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento salvo!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
       if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FUNÇÃO DE IMPRESSÃO REESCRITA COM GERADOR DE PDF ---
  Future<void> _printDocument() async {
    final String plainText = _controller.document.toPlainText();
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.latoRegular();
    final titleFont = await PdfGoogleFonts.latoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                widget.document.title, 
                style: pw.TextStyle(font: titleFont, fontSize: 24),
              ),
            ),
            pw.Divider(),
            pw.Paragraph(
              text: plainText,
              // --- CORREÇÃO AQUI ---
              // Trocado 'lineHeight: 1.5' (inválido) por 'lineSpacing: 5.0' (válido)
              style: pw.TextStyle(font: font, fontSize: 14, lineSpacing: 5.0),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  // --- FIM DA FUNÇÃO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimir / Salvar como PDF',
            onPressed: _printDocument,
          ),
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
              quill.QuillToolbar.simple(
                configurations: quill.QuillSimpleToolbarConfigurations(
                  controller: _controller,
                  sharedConfigurations: const quill.QuillSharedConfigurations(
                    locale: Locale('pt', 'BR'),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: quill.QuillEditor( 
                    focusNode: _editorFocusNode,
                    scrollController: _scrollController,
                    configurations: quill.QuillEditorConfigurations(
                      controller: _controller,
                      sharedConfigurations: const quill.QuillSharedConfigurations(
                        locale: Locale('pt', 'BR'),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
          if (_showCalculator)
            CalculadoraFlutuante(
              onClose: () => setState(() => _showCalculator = false),
              onInsert: (String textToInsert) {
                  final index = _controller.selection.baseOffset;
                  _controller.replaceText(index, 0, '$textToInsert ', TextSelection.collapsed(offset: index + textToInsert.length + 1));
                  _editorFocusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }
}
