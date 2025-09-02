import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_pad_service.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';

class TelaNexoPadLista extends StatefulWidget {
  const TelaNexoPadLista({super.key});

  @override
  _TelaNexoPadListaState createState() => _TelaNexoPadListaState();
}

class _TelaNexoPadListaState extends State<TelaNexoPadLista> {
  final NexoPadService _nexoPadService = NexoPadService();
  final TextEditingController _titleController = TextEditingController();

  void _renameDocument(NexoPadDocument doc) async {
    _titleController.text = doc.title;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear Documento'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Novo nome',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _nexoPadService.updateDocumentTitle(doc.id, _titleController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteDocument(NexoPadDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Tem certeza que deseja excluir o documento "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _nexoPadService.deleteDocument(doc.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento excluído com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Documentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final newDoc = await _nexoPadService.createNewDocument();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TelaNexoPad(document: newDoc),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NexoPadDocument>>(
        stream: _nexoPadService.getDocumentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum documento encontrado'));
          }
          
          final documents = snapshot.data!;
          
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(doc.title),
                  subtitle: Text('Editado em: ${doc.lastEdited.toDate()}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') {
                        _renameDocument(doc);
                      } else if (value == 'delete') {
                        _deleteDocument(doc);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Renomear'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir'),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TelaNexoPad(document: doc),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
