import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/services/report_service.dart'; // <<< ADICIONADO
import 'package:nexo/utils.dart'; // <<< ADICIONADO
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart'; // <<< ADICIONADO
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
  final ReportService _reportService = ReportService(); // <<< ADICIONADO
  final _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  Map<String, UserModel> _memberProfiles = {};
  String _otherUserId = ''; // Armazena o ID do outro usuário em um DM

  @override
  void initState() {
    super.initState();
    _fetchMemberProfiles();
    if (widget.chatRoom.type == ChatRoomType.dm) {
      _otherUserId = widget.chatRoom.memberIds.firstWhere((id) => id != _currentUserId, orElse: () => '');
    }
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
      _chatService.sendMessage(
        roomId: widget.chatRoom.id,
        text: _messageController.text,
        senderId: _currentUserId,
      );
      _messageController.clear();
    }
  }

  // --- FUNÇÃO DE DENÚNCIA ADICIONADA ---
  void _showReportDialog() {
    final reportController = TextEditingController();
    final reportOptions = ['Assédio', 'Discurso de Ódio', 'Spam', 'Outro'];
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Denunciar Usuário'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    hint: const Text('Selecione um motivo'),
                    onChanged: (value) {
                      setDialogState(() => selectedReason = value);
                    },
                    items: reportOptions.map((reason) {
                      return DropdownMenuItem(value: reason, child: Text(reason));
                    }).toList(),
                  ),
                  if (selectedReason == 'Outro')
                    TextField(
                      controller: reportController,
                      decoration: const InputDecoration(labelText: 'Descreva o motivo'),
                      maxLines: 3,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (selectedReason != null)
                      ? () async {
                          final reason = (selectedReason == 'Outro')
                              ? reportController.text.trim()
                              : selectedReason!;
                          
                          if (reason.isEmpty) return;

                          final report = ReportModel(
                            id: '', // será gerado
                            reporterId: _currentUserId,
                            reportedUserId: _otherUserId, // Denuncia o outro usuário no DM
                            contentId: widget.chatRoom.id, // Envia o ID do chat para análise
                            contentType: 'chat_dm',
                            reason: reason,
                            createdAt: Timestamp.now(),
                          );
                          
                          try {
                            await _reportService.submitReport(report);
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Denúncia enviada com sucesso.'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context).pop();
                              showErrorDialog(context, 'Erro', e.toString());
                            }
                          }
                        }
                      : null,
                  child: const Text('Enviar Denúncia'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String chatTitle = 'Chat';
    if (widget.chatRoom.type == ChatRoomType.dm) {
      chatTitle = _memberProfiles[_otherUserId]?.username ?? 'Carregando...';
    } else {
      chatTitle = widget.chatRoom.memberInfo['hubName'] ?? 'Chat do Hub';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(chatTitle),
        // --- BOTÃO DE DENÚNCIA ADICIONADO ---
        actions: [
          if (widget.chatRoom.type == ChatRoomType.dm) // Só mostra em DMs
            IconButton(
              icon: const Icon(Icons.report_problem_outlined, color: Colors.yellowAccent),
              tooltip: 'Denunciar Conversa',
              onPressed: _showReportDialog,
            ),
        ],
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
