import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_hub_detalhe.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class TelaHubsLista extends StatefulWidget {
  const TelaHubsLista({super.key});

  @override
  State<TelaHubsLista> createState() => _TelaHubsListaState();
}

class _TelaHubsListaState extends State<TelaHubsLista> {
  late final NexoHubService _hubService;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _hubService = context.read<NexoHubService>();
  }

  // --- FUNÇÃO DE DELETAR ADICIONADA ---
  void _deleteHub(NexoHub hub) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Hub'),
        content: Text('Tem certeza que deseja excluir permanentemente o hub "${hub.name}"? Esta ação NÃO pode ser desfeita e também excluirá a sala de chat principal.'),
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
      try {
        await _hubService.deleteHub(hub.id, hub.ownerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hub "${hub.name}" excluído.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<NexoHub>>(
        stream: _hubService.getHubsForCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar Hubs: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Você ainda não participa de nenhum Hub.'));
          }
          final hubs = snapshot.data!;
          return ListView.builder(
            itemCount: hubs.length,
            itemBuilder: (context, index) {
              final hub = hubs[index];
              final bool isOwner = hub.ownerId == _currentUserId;

              return ListTile(
                leading: UserAvatar(username: hub.name, photoUrl: null),
                title: Text(hub.name),
                subtitle: Text(hub.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                // --- MENU DE DELETAR ADICIONADO ---
                trailing: isOwner 
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteHub(hub);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(leading: Icon(Icons.delete, color: Colors.redAccent), title: Text('Excluir Hub', style: TextStyle(color: Colors.redAccent))),
                        ),
                      ],
                    )
                  : null, // Não mostra o menu se não for o dono
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaHubDetalhe(hub: hub),
                  ));
                },
              );
            },
          );
        },
      ),
      // O FLOATING ACTION BUTTON FOI REMOVIDO DAQUI
      // Ele agora será controlado pelo main.dart
    );
  }
}
