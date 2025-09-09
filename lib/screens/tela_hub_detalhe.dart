import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';

class TelaHubDetalhe extends StatefulWidget {
  final NexoHub hub;
  const TelaHubDetalhe({super.key, required this.hub});

  @override
  State<TelaHubDetalhe> createState() => _TelaHubDetalheState();
}

class _TelaHubDetalheState extends State<TelaHubDetalhe> {
  final NexoHubService _hubService = NexoHubService();
  final ChatService _chatService = ChatService();
  late Future<List<UserModel>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _hubService.getHubMembers(widget.hub.id);
  }

  void _openChat() async {
    // Busca por uma sala de chat existente para este Hub
    final existingRoom = await _chatService.getChatRoomById(widget.hub.id);

    if (existingRoom != null) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: existingRoom)),
        );
      }
      return;
    }
    
    // Se não existir, cria uma nova
    final newChatRoom = ChatRoom(
      id: widget.hub.id, // Usa o ID do Hub como ID da sala de chat
      type: ChatRoomType.group,
      memberIds: widget.hub.memberIds,
      hubId: widget.hub.id,
      memberInfo: {'hubName': widget.hub.name},
      createdAt: Timestamp.now(),
      lastMessageTimestamp: Timestamp.now(),
    );

    final createdRoom = await _chatService.createChatRoom(newChatRoom);
    if (createdRoom != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: createdRoom)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hub.name),
        actions: [
          // BOTÃO DE CHAT DO HUB ADICIONADO
          IconButton(
            icon: const Icon(Icons.chat_bubble),
            onPressed: _openChat,
            tooltip: 'Chat do Hub',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.hub.description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            Text('Membros', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(),
            FutureBuilder<List<UserModel>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('Nenhum membro encontrado.');
                }
                final members = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      title: Text(member.username),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
