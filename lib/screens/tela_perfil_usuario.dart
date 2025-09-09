import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/profile_service.dart';
import '../widgets/user_avatar.dart';

class TelaPerfilUsuario extends StatefulWidget {
  final String userId;
  const TelaPerfilUsuario({super.key, required this.userId});

  @override
  State<TelaPerfilUsuario> createState() => _TelaPerfilUsuarioState();
}

class _TelaPerfilUsuarioState extends State<TelaPerfilUsuario> {
  final ProfileService _profileService = ProfileService();
  final ChatService _chatService = ChatService();

  void _startChatWith(UserModel currentUser, UserModel otherUser) async {
    try {
      final chatRoom = await _chatService.getOrCreateDmRoom(currentUser, otherUser);
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
    final currentUserProfile = Provider.of<UserModel?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuário'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _profileService.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userProfile = snapshot.data!;

          if (currentUserProfile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final bool isFollowing = currentUserProfile.followingIds.contains(userProfile.id);
          final bool isFollower = userProfile.followingIds.contains(currentUserProfile.id);
          final bool isCoNexo = isFollowing && isFollower;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UserAvatar(username: userProfile.username, photoUrl: userProfile.photoUrl, radius: 60),
                const SizedBox(height: 16),
                Text(userProfile.username, style: Theme.of(context).textTheme.headlineSmall),
                Text(userProfile.email),
                const SizedBox(height: 16),
                Text(userProfile.bio, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),
                
                // BOTÃO DE CHAT PRIVADO (APENAS PARA CO-NEXOS)
                if (isCoNexo) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Iniciar Conversa'),
                    onPressed: () => _startChatWith(currentUserProfile, userProfile),
                  ),
                  const SizedBox(height: 16),
                ],

                isFollowing
                    ? ElevatedButton(
                        onPressed: () => _profileService.unfollowUser(currentUserProfile.id, userProfile.id),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        child: const Text('Deixar de Seguir'),
                      )
                    : ElevatedButton(
                        onPressed: () => _profileService.followUser(currentUserProfile.id, userProfile.id),
                        child: const Text('Seguir'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
