import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:provider/provider.dart';

class TelaDetalheBaralhoCompartilhado extends StatefulWidget {
  final String hubId;
  final String deckId;
  final String deckName;

  const TelaDetalheBaralhoCompartilhado({
    super.key,
    required this.hubId,
    required this.deckId,
    required this.deckName,
  });

  @override
  State<TelaDetalheBaralhoCompartilhado> createState() => _TelaDetalheBaralhoCompartilhadoState();
}

class _TelaDetalheBaralhoCompartilhadoState extends State<TelaDetalheBaralhoCompartilhado> {
  @override
  Widget build(BuildContext context) {
    final hubService = Provider.of<NexoHubService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckName),
      ),
      body: StreamBuilder<List<Cartao>>(
        stream: hubService.getSharedCardsStream(widget.hubId, widget.deckId), // MÉTODO CORRIGIDO
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Este baralho compartilhado está vazio.'));
          }
          final cards = snapshot.data!;
          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(card.frente),
                  subtitle: Text(card.verso),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
