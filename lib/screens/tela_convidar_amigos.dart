import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // <-- IMPORTAÇÃO CORRIGIDA
import '../models/models.dart';
import '../services/nexo_hub_service.dart';
import '../services/profile_service.dart';
import '../widgets/user_avatar.dart';

class TelaConvidarAmigos extends StatefulWidget {
  final NexoHub hub;
  const TelaConvidarAmigos({super.key, required this.hub});

  @override
  State<TelaConvidarAmigos> createState() => _TelaConvidarAmigosState();
}

class _TelaConvidarAmigosState extends State<TelaConvidarAmigos> {
  final ProfileService _profileService = ProfileService();
  final NexoHubService _hubService = NexoHubService();
  
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = Future.wait([
        _profileService.getUserProfile(FirebaseAuth.instance.currentUser!.uid).then((p) => _profileService.getUsersFromIdList(p?.followingIds ?? [])),
        _hubService.getPendingInvitedUserIdsForHub(widget.hub.id)
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Convidar para "${widget.hub.name}"'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar usuários: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data == null || (snapshot.data![0] as List).isEmpty) {
            return const Center(child: Text("Você não segue ninguém para convidar."));
          }

          final List<UserModel> usersToInvite = snapshot.data![0];
          final List<String> pendingInviteIds = snapshot.data![1];

          return ListView.builder(
            itemCount: usersToInvite.length,
            itemBuilder: (context, index) {
              final user = usersToInvite[index];
              final isAlreadyMember = widget.hub.memberIds.contains(user.id);
              final hasPendingInvite = pendingInviteIds.contains(user.id);

              Widget trailingWidget;
              if (isAlreadyMember) {
                trailingWidget = const Text("Membro", style: TextStyle(color: Colors.green));
              } else if (hasPendingInvite) {
                trailingWidget = const Text("Convidado", style: TextStyle(color: Colors.grey));
              } else {
                trailingWidget = ElevatedButton(
                  child: const Text("Convidar"),
                  onPressed: () async {
                    await _hubService.sendHubInvite(hub: widget.hub, toUserId: user.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Convite enviado para ${user.username}!')),
                    );
                    _loadData();
                  },
                );
              }

              return ListTile(
                leading: UserAvatar(username: user.username, photoUrl: user.photoUrl),
                title: Text(user.username),
                trailing: trailingWidget,
              );
            },
          );
        },
      ),
    );
  }
}
