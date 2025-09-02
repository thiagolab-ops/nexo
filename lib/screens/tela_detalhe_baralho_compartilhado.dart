import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';

class TelaDetalheBaralhoCompartilhado extends StatefulWidget {
  final String hubId;
  
  const TelaDetalheBaralhoCompartilhado({super.key, required this.hubId});

  @override
  _TelaDetalheBaralhoCompartilhadoState createState() => _TelaDetalheBaralhoCompartilhadoState();
}

class _TelaDetalheBaralhoCompartilhadoState extends State<TelaDetalheBaralhoCompartilhado> {
  final NexoHubService _hubService = NexoHubService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baralho Compartilhado'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _hubService.getSharedCardsStream(widget.hubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum card encontrado'));
          }
          
          final cards = snapshot.data!;
          
          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(card['frente'] ?? ''),
                  subtitle: Text(card['verso'] ?? ''),
                  trailing: Text('Compartilhado por: ${card['sharedBy'] ?? ''}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
