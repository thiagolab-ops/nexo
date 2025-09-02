import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/user_avatar.dart';
import '../models/models.dart';
import '../services/chat_service.dart';

class TelaChatMensagens extends StatefulWidget {
  final ChatRoom chatRoom;
  const TelaChatMensagens({required this.chatRoom, super.key});

  @override
  State<TelaChatMensagens> createState() => _TelaChatMensagensState();
}

class _TelaChatMensagensState extends State<TelaChatMensagens> {
  final ChatService _chatService = ChatService();
  final ProfileService _profileService = ProfileService();
  final _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  Map<String, UserModel> _memberProfiles = {};

  @override
  void initState() {
    super.initState();
    _fetchMemberProfiles();
  }

  Future<void> _fetchMemberProfiles() async {
    if (widget.chatRoom.memberIds.isEmpty) return;
    final profiles = await _profileService.getUsersFromIdList(widget.chatRoom.memberIds);
    if (mounted) {
      setState(() {
        _memberProfiles = {for (var p in profiles) p.id: p};
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      // CORRIGIDO: Usando parâmetros nomeados
      _chatService.sendMessage(
        roomId: widget.chatRoom.id,
        text: _messageController.text,
        senderId: _currentUserId,
      );
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    String chatTitle = 'Chat';
    if (widget.chatRoom.type == ChatRoomType.dm) {
      final otherUserId = widget.chatRoom.memberIds.firstWhere((id) => id != _currentUserId, orElse: () => '');
      chatTitle = _memberProfiles[otherUserId]?.username ?? 'Mensagem Direta';
    } else {
      chatTitle = widget.chatRoom.memberInfo['hubName'] ?? 'Chat do Hub';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(chatTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesStream(widget.chatRoom.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhuma mensagem ainda. Diga olá!'));
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    final senderProfile = _memberProfiles[message.senderId];
                    return _buildMessageBubble(message, senderProfile, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message, UserModel? sender, bool isMe) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blueAccent : Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message.text, style: const TextStyle(color: Colors.white)),
    );

    if (isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [bubble],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          UserAvatar(
            username: sender?.username ?? '?',
            photoUrl: sender?.photoUrl,
            radius: 16,
          ),
          const SizedBox(width: 4),
          bubble,
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Digite uma mensagem...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
