import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/screens/tela_perfil_usuario.dart';
import 'package:nexo/services/chat_service.dart';
import '../models/models.dart';
import '../services/profile_service.dart';
import 'user_avatar.dart';

class UserListView extends StatefulWidget {
  final List<String> userIds;
  final UserModel currentUserProfile;
  const UserListView({super.key, required this.userIds, required this.currentUserProfile});

  @override
  State<UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<UserListView> {
  late Future<List<UserModel>> _usersFuture;
  final ProfileService _profileService = ProfileService();
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _usersFuture = _profileService.getUsersFromIdList(widget.userIds);
  }

  @override
  void didUpdateWidget(covariant UserListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.userIds, widget.userIds)) {
      setState(_loadData);
    }
  }

  void _startChatWith(UserModel otherUser) async {
    try {
      final chatRoom = await _chatService.getOrCreateDmRoom(widget.currentUserProfile, otherUser);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: chatRoom)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível iniciar o chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userIds.isEmpty) {
      return const Center(child: Text('Nenhum usuário para exibir.'));
    }
    return FutureBuilder<List<UserModel>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Erro ao carregar usuários.'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum usuário encontrado.'));
        }

        final users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            
            final bool isFollowing = widget.currentUserProfile.followingIds.contains(user.id);
            final bool isFollower = user.followingIds.contains(widget.currentUserProfile.id);
            final bool isCoNexo = isFollowing && isFollower;

            return ListTile(
              leading: UserAvatar(username: user.username, photoUrl: user.photoUrl, radius: 24),
              title: Text(user.username),
              subtitle: Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: isCoNexo
                  ? IconButton(
                      icon: const Icon(Icons.chat_bubble),
                      tooltip: 'Iniciar conversa',
                      onPressed: () => _startChatWith(user),
                    )
                  : null,
              onTap: () { // LÓGICA DE NAVEGAÇÃO CORRIGIDA
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => TelaPerfilUsuario(userId: user.id),
                ));
              },
            );
          },
        );
      },
    );
  }
}
