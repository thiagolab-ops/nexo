import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;

class TelaChatsLista extends StatefulWidget {
  const TelaChatsLista({super.key});

  @override
  State<TelaChatsLista> createState() => _TelaChatsListaState();
}

class _TelaChatsListaState extends State<TelaChatsLista> {
  final ChatService _chatService = ChatService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRoom>>(
      stream: _chatService.getChatRoomsStream(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar conversas: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Nenhuma conversa iniciada.\nInicie uma conversa com um Co-Nexo!'),
          );
        }

        final chatRooms = snapshot.data!;

        return ListView.builder(
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final room = chatRooms[index];
            String title = 'Chat';
            String photoUrl = ''; // Placeholder for hub icon
            String usernameForAvatar = '?';

            if (room.type == ChatRoomType.dm) {
              final otherUserId = room.memberIds.firstWhere((id) => id != _currentUserId, orElse: () => '');
              title = room.memberInfo[otherUserId] ?? 'Conversa';
              usernameForAvatar = title;
              // No futuro, podemos buscar a foto do outro usuário aqui
            } else {
              title = room.memberInfo['hubName'] ?? 'Chat de Hub';
              usernameForAvatar = title;
            }

            return ListTile(
              leading: UserAvatar(
                username: usernameForAvatar,
                photoUrl: photoUrl,
                radius: 24,
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                room.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timeago.format(room.lastMessageTimestamp.toDate(), locale: 'pt_BR'),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: room)),
                );
              },
            );
          },
        );
      },
    );
  }
}
