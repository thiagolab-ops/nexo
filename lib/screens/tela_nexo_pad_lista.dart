import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/nexo_pad_service.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class TelaNexoPadLista extends StatefulWidget {
  const TelaNexoPadLista({super.key});

  @override
  State<TelaNexoPadLista> createState() => _TelaNexoPadListaState();
}

class _TelaNexoPadListaState extends State<TelaNexoPadLista> {
  late final NexoPadService _nexoPadService;
  late final NexoHubService _hubService;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    // Nós lemos os serviços do Provider aqui, pois são necessários para as ações do menu
    _nexoPadService = context.read<NexoPadService>();
    _hubService = context.read<NexoHubService>();
  }
  
  void _deleteDocument(NexoPadDocument doc) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Documento'),
        content: Text('Tem certeza que deseja excluir permanentemente "${doc.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _nexoPadService.deleteDocument(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${doc.title}" excluído.'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _showShareDocToHubDialog(NexoPadDocument doc) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<NexoHub>>(
        stream: _hubService.getHubsForCurrentUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Dialog(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
          }
          if (snapshot.data!.isEmpty) {
            return AlertDialog(
              title: const Text('Compartilhar no Hub'),
              content: const Text('Você precisa ser membro de um Hub para poder compartilhar.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            );
          }
          final hubs = snapshot.data!;
          return AlertDialog(
            title: const Text('Compartilhar em qual Hub?'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hubs.length,
                itemBuilder: (context, index) {
                  final hub = hubs[index];
                  return ListTile(
                    title: Text(hub.name),
                    onTap: () async {
                      Navigator.of(context).pop(); // Fecha o diálogo
                      // Cria uma cópia no Hub com o conteúdo do documento pessoal
                      await _hubService.createSharedDocumentInHub(
                        hubId: hub.id,
                        title: doc.title,
                        ownerId: _currentUserId,
                        initialContentJson: doc.contentJson, // Passa o conteúdo atual
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Documento compartilhado em "${hub.name}"!'), backgroundColor: Colors.green),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<NexoPadDocument>>(
        stream: _nexoPadService.getDocumentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum documento ainda.\nClique em + para criar um.'));
          }
          final documents = snapshot.data!;
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return ListTile(
                leading: const Icon(Icons.edit_document),
                title: Text(doc.title),
                subtitle: Text('Editado ${timeago.format(doc.lastEdited.toDate(), locale: 'pt_BR')}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'share') {
                      _showShareDocToHubDialog(doc);
                    } else if (value == 'delete') {
                      _deleteDocument(doc);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(leading: Icon(Icons.share), title: Text('Compartilhar no Hub')),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(leading: Icon(Icons.delete, color: Colors.redAccent), title: Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaNexoPad(document: doc),
                  ));
                },
              );
            },
          );
        },
      ),
      // O FAB é controlado pela TelaPrincipal
    );
  }
}
