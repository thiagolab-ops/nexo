import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_detalhe_baralho.dart';
import 'package:nexo/screens/tela_jogo.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/widgets/baralho_card_widget.dart';

class TelaBaralhosLista extends StatefulWidget {
  const TelaBaralhosLista({super.key});
  @override
  _TelaBaralhosListaState createState() => _TelaBaralhosListaState();
}

class _TelaBaralhosListaState extends State<TelaBaralhosLista> {
  final FirestoreService _firestoreService = FirestoreService();
  final NexoHubService _hubService = NexoHubService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  void _mostrarDialogoNovoBaralho({Baralho? baralhoExistente}) {
    final nomeController = TextEditingController(text: baralhoExistente?.nome);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(baralhoExistente == null ? 'newDeckDialogTitle'.tr() : 'Editar Nome'),
          content: TextField(
            controller: nomeController,
            autofocus: true,
            decoration: InputDecoration(hintText: 'newDeckDialogHint'.tr()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancelButton'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                if (nome.isNotEmpty) {
                  if (baralhoExistente != null) {
                    await _firestoreService.updateBaralho(_userId, baralhoExistente.id!, nome);
                  } else {
                    final novoBaralho = Baralho(nome: nome);
                    await _firestoreService.addBaralho(novoBaralho, _userId);
                  }
                  if (mounted) Navigator.of(context).pop();
                }
              },
              child: Text(baralhoExistente == null ? 'addButton'.tr() : 'saveButton'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _excluirBaralho(Baralho baralho) async {
    final bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Baralho'),
        content: Text('Tem certeza que deseja excluir "${baralho.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true && baralho.id != null) {
      await _firestoreService.deleteBaralho(_userId, baralho.id!);
    }
  }

  void _showShareDeckDialog(Baralho baralho) {
    showDialog(context: context, builder: (context) {
      return StreamBuilder<List<NexoHub>>(
        stream: _hubService.getHubsForCurrentUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) {
            return AlertDialog(
              title: const Text('Compartilhar Baralho'),
              content: const Text('Você precisa participar de um Hub para compartilhar.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("OK"))],
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
                      Navigator.of(context).pop();
                      final cards = await _firestoreService.getCards(_userId, baralho.id!).first;
                      await _hubService.shareDeckWithHub(hubId: hub.id, baralho: baralho, cards: cards);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Baralho compartilhado em "${hub.name}"!'), backgroundColor: Colors.green),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Baralho>>(
        stream: _firestoreService.getBaralhos(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('emptyDecksMessage'.tr(), textAlign: TextAlign.center));
          }
          final baralhos = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.8,
            ),
            itemCount: baralhos.length,
            itemBuilder: (context, index) {
              final baralho = baralhos[index];
              return BaralhoCardWidget(
                baralho: baralho,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => TelaDetalheBaralho(baralho: baralho))),
                onPlay: () async {
                  final cards = await _firestoreService.getCards(_userId, baralho.id!).first;
                  if (cards.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa de pelo menos 4 cartões para jogar!'), backgroundColor: Colors.orangeAccent));
                    return;
                  }
                  if(mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => TelaJogo(cartoesDoBaralho: cards)));
                  }
                },
                onEdit: () => _mostrarDialogoNovoBaralho(baralhoExistente: baralho),
                onDelete: () => _excluirBaralho(baralho),
                onShare: () => _showShareDeckDialog(baralho),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_baralhos',
        onPressed: () => _mostrarDialogoNovoBaralho(),
        tooltip: 'addDeckTooltip'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
