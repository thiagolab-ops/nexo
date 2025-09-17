import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_agenda_hub.dart';
import 'package:nexo/screens/tela_mapa_mental.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/forum_widget.dart'; // <<< WIDGET DO FÓRUM IMPORTADO
import 'package:nexo/widgets/user_avatar.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/quiz_service.dart';
import 'package:nexo/screens/tela_detalhe_baralho_compartilhado.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';
import 'package:nexo/screens/tela_realizar_quiz.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Audience { hub, followers } 

class TelaHubDetalhe extends StatefulWidget {
  final NexoHub hub;
  const TelaHubDetalhe({super.key, required this.hub});

  @override
  State<TelaHubDetalhe> createState() => _TelaHubDetalheState();
}

class _TelaHubDetalheState extends State<TelaHubDetalhe> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late UserModel _currentUserProfile;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instância do Firestore

  @override
  void initState() {
    super.initState();
    _currentUserProfile = Provider.of<UserModel?>(context, listen: false)!;
    // --- ATUALIZADO PARA 8 ABAS ---
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(() {
      setState(() {}); 
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 2: // Aba Agenda
        if (_currentUserProfile.role == 'professor') {
           return FloatingActionButton(
            heroTag: 'add_event',
            onPressed: () => _showCreateEventDialog(),
            tooltip: 'Adicionar Evento',
            child: const Icon(Icons.add_alert),
          );
        }
        return null;
      case 5: // Aba Documentos
        return FloatingActionButton(
          heroTag: 'add_document',
          onPressed: () => _showCreateSharedDocumentDialog(),
          tooltip: 'Novo Documento',
          child: const Icon(Icons.note_add),
        );
      case 6: // Aba Baralhos
        return FloatingActionButton(
          heroTag: 'share_deck',
          onPressed: () => _showShareDeckDialog(),
          tooltip: 'Compartilhar Baralho Pessoal',
          child: const Icon(Icons.share),
        );
      // O FÓRUM (INDEX 7) JÁ TEM SEU PRÓPRIO FAB INTERNO
      default: 
        return null;
    }
  }

  // (Todas as outras funções de diálogo permanecem as mesmas...)
  void _showCreateEventDialog({HubEvent? eventToEdit}) {
    final isEditing = eventToEdit != null;
    final titleController = TextEditingController(text: isEditing ? eventToEdit.title : '');
    final linkController = TextEditingController();
    Audience selectedAudience = Audience.hub;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Evento' : 'Criar Evento ou Aula'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(labelText: isEditing ? 'Título do Evento' : 'Título do Evento/Aula'),
                  ),
                  if (_currentUserProfile.role == 'professor' && !isEditing) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Link do Google Meet (Opcional)',
                        hintText: 'Cole para convocar uma aula',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Se incluir um link, convocar para:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<Audience>(
                      title: Text('Apenas membros do Hub "${widget.hub.name}"'),
                      value: Audience.hub,
                      groupValue: selectedAudience,
                      onChanged: (Audience? value) {
                        setDialogState(() => selectedAudience = value!);
                      },
                    ),
                    RadioListTile<Audience>(
                      title: const Text('Todos os meus seguidores'),
                      value: Audience.followers,
                      groupValue: selectedAudience,
                      onChanged: (Audience? value) {
                        setDialogState(() => selectedAudience = value!);
                      },
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    Navigator.of(dialogContext).pop();
                    final hubService = context.read<NexoHubService>();
                    try {
                      if (isEditing) {
                        await hubService.updateEventInHub(widget.hub.id, eventToEdit!.id, titleController.text);
                      } else {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        
                        await hubService.addEventToHub(
                          widget.hub.id,
                          title: titleController.text,
                          date: today,
                          meetLink: linkController.text.trim().isEmpty ? null : linkController.text.trim(),
                          audience: linkController.text.trim().isEmpty ? null : selectedAudience.name,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao salvar evento: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateSharedDocumentDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Documento Compartilhado'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Título do Documento'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final newDoc = await context.read<NexoHubService>().createSharedDocumentInHub(
                hubId: widget.hub.id,
                title: titleController.text.trim(),
                ownerId: _currentUserId,
              );
              if(mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => TelaNexoPad(document: newDoc),
                ));
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  void _showShareDeckDialog() {
    final firestoreService = context.read<FirestoreService>();
    final hubService = context.read<NexoHubService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartilhar Baralho Pessoal'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Baralho>>(
            stream: firestoreService.getBaralhos(_currentUserId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Text('Você não possui baralhos pessoais para compartilhar.');
              
              final decks = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: decks.length,
                itemBuilder: (context, index) {
                  final deck = decks[index];
                  return ListTile(
                    title: Text(deck.nome),
                    onTap: () async {
                      final cards = await firestoreService.getCards(_currentUserId, deck.id!).first;
                      await hubService.shareDeckWithHub(hubId: widget.hub.id, baralho: deck, cards: cards);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${deck.nome} compartilhado!'), backgroundColor: Colors.green));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hub.name),
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, 
          // --- ATUALIZADO PARA 8 ABAS ---
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Sobre'),
            Tab(icon: Icon(Icons.people), text: 'Membros'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Agenda'),
            Tab(icon: Icon(Icons.chat_bubble), text: 'Chat'), 
            Tab(icon: Icon(Icons.hub_outlined), text: 'Mapa'),
            Tab(icon: Icon(Icons.note_add), text: 'Docs'),
            Tab(icon: Icon(Icons.style), text: 'Baralhos'),
            Tab(icon: Icon(Icons.forum), text: 'Fórum'), // <<< NOVA ABA ADICIONADA
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // --- ATUALIZADO PARA 8 TELAS ---
        children: [
          _SobreTab(description: widget.hub.description),
          _MembrosTab(hubId: widget.hub.id),
          TelaAgendaHub(
            hubId: widget.hub.id,
            hubName: widget.hub.name,
            showEventDialog: _showCreateEventDialog,
            currentUserProfile: _currentUserProfile,
          ),
          _HubChatWrapper(hub: widget.hub),
          TelaMapaMental(hubId: widget.hub.id),
          _DocumentosTab(hubId: widget.hub.id),
          _BaralhosTab(hubId: widget.hub.id),
          // <<< NOVA TELA DE FÓRUM PRIVADO ADICIONADA >>>
          ForumWidget(
            // Passamos a coleção específica deste Hub
            topicsCollection: _firestore.collection('hubs').doc(widget.hub.id).collection('forum_topics'),
            currentUser: _currentUserProfile,
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}


// --- WIDGET WRAPPER PARA O CHAT (Stateful para evitar loop) ---
class _HubChatWrapper extends StatefulWidget {
  final NexoHub hub;
  const _HubChatWrapper({required this.hub});

  @override
  State<_HubChatWrapper> createState() => _HubChatWrapperState();
}

class _HubChatWrapperState extends State<_HubChatWrapper> {
  late Future<ChatRoom> _chatRoomFuture;
  late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _chatRoomFuture = _getOrCreateHubChat();
  }

  Future<ChatRoom> _getOrCreateHubChat() async {
    final existingRoom = await _chatService.getChatRoomById(widget.hub.id);

    if (existingRoom != null) {
      return existingRoom;
    }
    
    final newChatRoom = ChatRoom(
      id: widget.hub.id,
      type: ChatRoomType.group,
      memberIds: widget.hub.memberIds,
      hubId: widget.hub.id,
      memberInfo: {'hubName': widget.hub.name},
      createdAt: Timestamp.now(),
      lastMessageTimestamp: Timestamp.now(),
    );

    final createdRoom = await _chatService.createChatRoom(newChatRoom);
    return createdRoom!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatRoom>(
      future: _chatRoomFuture, 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar o chat: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Não foi possível carregar a sala de chat.'));
        }
        final chatRoom = snapshot.data!;
        return TelaChatMensagensSemAppBar(chatRoom: chatRoom);
      },
    );
  }
}

// --- WIDGETS DAS ABAS (DEFINIDOS INTERNAMENTE) ---

class _SobreTab extends StatelessWidget {
  final String description;
  const _SobreTab({required this.description});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Text(description, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _MembrosTab extends StatelessWidget {
  final String hubId;
  const _MembrosTab({required this.hubId});

  @override
  Widget build(BuildContext context) {
    final hubService = Provider.of<NexoHubService>(context, listen: false);
    return FutureBuilder<List<UserModel>>(
      future: hubService.getHubMembers(hubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum membro encontrado.'));
        }
        final members = snapshot.data!;
        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: UserAvatar(username: member.username, photoUrl: member.photoUrl),
              title: Text(member.username),
            );
          },
        );
      },
    );
  }
}

class _DocumentosTab extends StatelessWidget {
  final String hubId;
  const _DocumentosTab({required this.hubId});

  void _deleteHubDocument(BuildContext context, NexoHubService hubService, NexoPadDocument doc) async {
     final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Documento'),
        content: Text('Tem certeza que deseja excluir permanentemente "${doc.title}" deste Hub?'),
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
      await hubService.deleteSharedDocument(hubId, doc.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubService = Provider.of<NexoHubService>(context, listen: false);
    return StreamBuilder<List<NexoPadDocument>>(
      stream: hubService.getSharedDocumentsStream(hubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum documento compartilhado.'));
        }
        final docs = snapshot.data!;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return ListTile(
              leading: const Icon(Icons.edit_document),
              title: Text(doc.title),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteHubDocument(context, hubService, doc);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete, color: Colors.redAccent), title: Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                  ),
                ],
              ),
              onTap: () {
                 Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => TelaNexoPad(document: doc),
                 ));
              },
            );
          },
        );
      },
    );
  }
}

class _BaralhosTab extends StatelessWidget {
  final String hubId;
  const _BaralhosTab({required this.hubId});

  @override
  Widget build(BuildContext context) {
     final hubService = Provider.of<NexoHubService>(context, listen: false);
     return StreamBuilder<List<Baralho>>(
       stream: hubService.getSharedDecksStream(hubId),
       builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
         }
         if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return const Center(child: Text('Nenhum baralho compartilhado.'));
         }
         final decks = snapshot.data!;
         return ListView.builder(
           itemCount: decks.length,
           itemBuilder: (context, index) {
             final deck = decks[index];
             return ListTile(
                leading: const Icon(Icons.style),
                title: Text(deck.nome),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaDetalheBaralhoCompartilhado(hubId: hubId, deckId: deck.id!, deckName: deck.nome),
                  ));
                },
             );
           },
         );
       },
     );
  }
}

class _ProvasTab extends StatelessWidget {
  final String hubId;
  const _ProvasTab({required this.hubId});

  @override
  Widget build(BuildContext context) {
    final hubService = Provider.of<NexoHubService>(context, listen: false);
    return StreamBuilder<List<Quiz>>(
      stream: hubService.getSharedQuizzesStream(hubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return const Center(child: Text('Nenhuma prova compartilhada.'));
        }
        final quizzes = snapshot.data!;
        return ListView.builder(
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];
            return ListTile(
              leading: const Icon(Icons.quiz),
              title: Text(quiz.title),
              onTap: () {
                 Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TelaRealizarQuiz(quiz: quiz),
                  ));
              },
            );
          },
        );
      },
    );
  }
}

// --- VERSÃO MODIFICADA DA TELA DE CHAT (SEM APPBAR) ---
class TelaChatMensagensSemAppBar extends StatefulWidget {
  final ChatRoom chatRoom;
  const TelaChatMensagensSemAppBar({required this.chatRoom, super.key});

  @override
  State<TelaChatMensagensSemAppBar> createState() => _TelaChatMensagensSemAppBarState();
}

class _TelaChatMensagensSemAppBarState extends State<TelaChatMensagensSemAppBar> {
  late final ChatService _chatService;
  late final ProfileService _profileService;
  final _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  Map<String, UserModel> _memberProfiles = {};

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _profileService = context.read<ProfileService>();
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
    return Column(
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
