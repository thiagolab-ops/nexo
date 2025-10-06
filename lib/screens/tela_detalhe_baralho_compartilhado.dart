import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:provider/provider.dart';

class TelaDetalheBaralhoCompartilhado extends StatefulWidget {
  final String hubId;
  final Baralho baralho;

  const TelaDetalheBaralhoCompartilhado({
    super.key,
    required this.hubId,
    required this.baralho,
  });

  @override
  State<TelaDetalheBaralhoCompartilhado> createState() => _TelaDetalheBaralhoCompartilhadoState();
}

class _TelaDetalheBaralhoCompartilhadoState extends State<TelaDetalheBaralhoCompartilhado> {
  bool _isCopying = false;

  Future<void> _copiarBaralhoParaUsuario() async {
    setState(() => _isCopying = true);
    try {
      final firestoreService = context.read<FirestoreService>();
      await firestoreService.copySharedDeck(
        hubId: widget.hubId,
        sharedDeck: widget.baralho,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${widget.baralho.nome}" copiado para seus baralhos!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao copiar baralho: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubService = Provider.of<NexoHubService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baralho.nome),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isCopying
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copiar para Meus Baralhos'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _copiarBaralhoParaUsuario,
                  ),
          ),
          const Text(
            'Copie para poder estudar, jogar e gerar provas.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
          const Divider(height: 32),
          Expanded(
            child: StreamBuilder<List<Cartao>>(
              // AQUI ESTÁ A CORREÇÃO
              stream: hubService.getSharedCardsStream(widget.hubId, widget.baralho.id!),
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
          ),
        ],
      ),
    );
  }
}
