import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/screens/tela_hub_detalhe.dart';

class TelaHubsLista extends StatefulWidget {
  const TelaHubsLista({super.key});

  @override
  _TelaHubsListaState createState() => _TelaHubsListaState();
}

class _TelaHubsListaState extends State<TelaHubsLista> {
  final NexoHubService _hubService = NexoHubService();

  void _navigateToHubDetail(NexoHub hub) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TelaHubDetalhe(hub: hub),
      ),
    );
  }

  void _deleteHub(NexoHub hub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Tem certeza que deseja excluir o hub "${hub.name}"?'),
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
      // Implementar lógica de exclusão
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hub excluído com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Hubs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Implementar navegação para criar novo hub
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NexoHub>>(
        stream: _hubService.getHubsForCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Você não participa de nenhum hub ainda'),
            );
          }
          
          final hubs = snapshot.data!;
          
          return ListView.builder(
            itemCount: hubs.length,
            itemBuilder: (context, index) {
              final hub = hubs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(hub.name),
                  subtitle: hub.description != null 
                      ? Text(hub.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteHub(hub);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir'),
                      ),
                    ],
                  ),
                  onTap: () => _navigateToHubDetail(hub),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implementar navegação para criar novo hub
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
