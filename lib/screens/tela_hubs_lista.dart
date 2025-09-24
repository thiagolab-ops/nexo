import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_hub_detalhe.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class TelaHubsLista extends StatefulWidget {
  const TelaHubsLista({super.key});

  @override
  State<TelaHubsLista> createState() => _TelaHubsListaState();
}

class _TelaHubsListaState extends State<TelaHubsLista> {
  // --- CORREÇÃO: Variáveis de serviço removidas do estado ---
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    // --- CORREÇÃO: Acessar 'context' em initState é perigoso. Obtemos apenas o UID aqui. ---
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Se por algum motivo o usuário não estiver logado, tratamos isso.
      // Você pode querer navegar para a tela de login aqui.
      _currentUserId = ''; 
    } else {
      _currentUserId = user.uid;
    }
  }
  
  void _showInviteDialog(NexoHub hub) {
    // --- CORREÇÃO: Serviços e profile obtidos via context DENTRO do método ---
    final hubService = context.read<NexoHubService>();
    final profileService = context.read<ProfileService>();
    final currentUserProfile = context.read<UserModel?>();

    if (currentUserProfile == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter seu perfil para enviar o convite.'), backgroundColor: Colors.red),
      );
      return;
    }

    final searchController = TextEditingController();
    Future<List<UserModel>>? searchResults;
    Set<String> invitedUserIds = {};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Convidar para "${hub.name}"'),
              content: SizedBox(
                width: 400,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Procurar por @username',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            if (searchController.text.trim().isNotEmpty) {
                              setDialogState(() {
                                searchResults = profileService.searchUsersByUsername(
                                  query: searchController.text.trim(),
                                  currentUserId: _currentUserId,
                                );
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<UserModel>>(
                        future: searchResults,
                        builder: (context, snapshot) {
                          if (searchResults == null) return const Center(child: Text('Digite para buscar um usuário.'));
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum usuário encontrado.'));

                          final users = snapshot.data!;
                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final isAlreadyMember = hub.memberIds.contains(user.id);
                              final wasInvited = invitedUserIds.contains(user.id);

                              return ListTile(
                                leading: UserAvatar(username: user.username, photoUrl: user.photoUrl),
                                title: Text(user.username),
                                trailing: ElevatedButton(
                                  onPressed: isAlreadyMember || wasInvited ? null : () {
                                    hubService.sendHubInvite(
                                      hubId: hub.id,
                                      hubName: hub.name,
                                      fromUserId: _currentUserId,
                                      fromUsername: currentUserProfile.username,
                                      toUser: user,
                                    );
                                    setDialogState(() {
                                      invitedUserIds.add(user.id);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Convite enviado para ${user.username}!'), backgroundColor: Colors.green),
                                    );
                                  },
                                  child: Text(isAlreadyMember ? 'Membro' : (wasInvited ? 'Convidado' : 'Convidar')),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fechar'))
              ],
            );
          },
        );
      },
    );
  }

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
        // --- CORREÇÃO: Acessa o serviço via context aqui ---
        await context.read<NexoHubService>().deleteHub(hub.id, hub.ownerId);
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
    if (_currentUserId.isEmpty) {
      return const Center(child: Text('Erro: Usuário não autenticado.'));
    }
    
    return Scaffold(
      body: StreamBuilder<List<NexoHub>>(
        // --- CORREÇÃO: Acessa o serviço via context aqui ---
        stream: context.watch<NexoHubService>().getHubsForCurrentUser(),
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
                trailing: isOwner 
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteHub(hub);
                        }
                        if (value == 'invite') {
                          _showInviteDialog(hub);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'invite',
                          child: ListTile(leading: Icon(Icons.person_add), title: Text('Convidar Membros')),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(leading: Icon(Icons.delete, color: Colors.redAccent), title: Text('Excluir Hub', style: TextStyle(color: Colors.redAccent))),
                        ),
                      ],
                    )
                  : null,
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
    );
  }
}
