import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';
import 'package:nexo/services/nexo_pad_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class TelaNexoPadLista extends StatefulWidget {
  const TelaNexoPadLista({super.key});

  @override
  State<TelaNexoPadLista> createState() => _TelaNexoPadListaState();
}

class _TelaNexoPadListaState extends State<TelaNexoPadLista> {
  final NexoPadService _nexoPadService = NexoPadService();

  void _createNewPadAndNavigate() async {
    try {
      final newDocument = await _nexoPadService.createNewDocument();
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => TelaNexoPad(document: newDocument),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar documento: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            return const Center(child: Text('Nenhum documento ainda.'));
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_nexopad',
        onPressed: _createNewPadAndNavigate, // LÓGICA CORRIGIDA AQUI
        tooltip: 'Novo Documento',
        child: const Icon(Icons.add),
      ),
    );
  }
}
