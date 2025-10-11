import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_agenda_hub.dart';
import 'package:nexo/screens/tela_mapa_mental_nativo.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/forum_widget.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/screens/tela_detalhe_baralho_compartilhado.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexo/services/mind_map_service.dart';

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
  UserModel? _currentUserProfile;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ScrollPhysics _tabBarPhysics = const PageScrollPhysics();
  
  late final MindMapController _mindMapController;
  
  DateTime? _selectedAgendaDay;

  @override
  void initState() {
    super.initState();
    _currentUserProfile = Provider.of<UserModel?>(context, listen: false);
    _tabController = TabController(length: 8, vsync: this);
    _selectedAgendaDay = DateTime.now();
    
    _mindMapController = MindMapController(
      service: context.read<MindMapService>(),
      hubId: widget.hub.id,
    );
    
    _tabController.addListener(() {
      if (!mounted) return;
      
      final screenSize = MediaQuery.of(context).size;
      
      if (_tabController.index == 4) {
        if (_tabBarPhysics is! NeverScrollableScrollPhysics) {
          setState(() {
            _tabBarPhysics = const NeverScrollableScrollPhysics();
          });
        }
        _mindMapController.centerView(screenSize);
      } else {
        if (_tabBarPhysics is! PageScrollPhysics) {
          setState(() {
            _tabBarPhysics = const PageScrollPhysics();
          });
        }
      }
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _mindMapController.dispose();
    super.dispose();
  }

  Widget? _buildFloatingActionButton() {
    if (_currentUserProfile == null) return null;

    switch (_tabController.index) {
      case 2:
        return FloatingActionButton(
          heroTag: 'add_event',
          onPressed: () => _showCreateEventDialog(),
          tooltip: 'hubDetail_addEventTooltip'.tr(),
          child: const Icon(Icons.add),
        );
      case 5:
        return FloatingActionButton(
          heroTag: 'add_document',
          onPressed: () => _showCreateSharedDocumentDialog(),
          tooltip: 'hubDetail_newDocumentTooltip'.tr(),
          child: const Icon(Icons.note_add),
        );
      case 6:
        return FloatingActionButton(
          heroTag: 'share_deck',
          onPressed: () => _showShareDeckDialog(),
          tooltip: 'hubDetail_shareDeckTooltip'.tr(),
          child: const Icon(Icons.share),
        );
      default:
        return null;
    }
  }

  void _showCreateEventDialog({HubEvent? eventToEdit}) {
    if (_currentUserProfile == null) return;
    final isEditing = eventToEdit != null;
    final titleController = TextEditingController(text: isEditing ? eventToEdit.title : '');
    final linkController = TextEditingController();
    Audience selectedAudience = Audience.hub;
    
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (dialogContext, setDialogState) {
      return AlertDialog(title: Text(isEditing ? 'hubDetail_editEvent'.tr() : 'hubDetail_createEvent'.tr()),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: isEditing ? 'hubDetail_eventTitleLabel'.tr() : 'hubDetail_eventClassTitleLabel'.tr())),
            if (_currentUserProfile!.isPrivileged && !isEditing) ...[
              const SizedBox(height: 16),
              TextField(controller: linkController, decoration: InputDecoration(labelText: 'hubDetail_meetLinkLabel'.tr(), hintText: 'hubDetail_meetLinkHint'.tr())),
              const SizedBox(height: 24),
              Text('hubDetail_召集Label'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<Audience>(title: Text('hubDetail_audienceHubOnly'.tr(namedArgs: {'hubName': widget.hub.name})), value: Audience.hub, groupValue: selectedAudience, onChanged: (Audience? value) { setDialogState(() => selectedAudience = value!); }),
              RadioListTile<Audience>(title: Text('hubDetail_audienceFollowers'.tr()), value: Audience.followers, groupValue: selectedAudience, onChanged: (Audience? value) { setDialogState(() => selectedAudience = value!); }),
            ]
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('cancelButton'.tr())),
          ElevatedButton(onPressed: () async {
            if (titleController.text.isNotEmpty) {
              Navigator.of(dialogContext).pop();
              final hubService = context.read<NexoHubService>();
              try {
                if (isEditing) {
                  await hubService.updateEventInHub(widget.hub.id, eventToEdit!.id, titleController.text);
                } else {
                  final eventDate = _selectedAgendaDay ?? DateTime.now();
                  await hubService.addEventToHub(widget.hub.id, title: titleController.text, date: eventDate, meetLink: linkController.text.trim().isEmpty ? null : linkController.text.trim(), audience: linkController.text.trim().isEmpty ? null : selectedAudience.name);
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('hubDetail_eventSaveError'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.redAccent));
              }
            }
          }, child: Text('saveButton'.tr())),
        ],
      );
    }));
  }

  void _showCreateSharedDocumentDialog() {
    final titleController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text('hubDetail_newSharedDocumentTitle'.tr()),
      content: TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: 'hubDetail_documentTitleLabel'.tr())),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancelButton'.tr())),
        ElevatedButton(onPressed: () async {
          if (titleController.text.trim().isEmpty) return;
          final newDoc = await context.read<NexoHubService>().createSharedDocumentInHub(hubId: widget.hub.id, title: titleController.text.trim(), ownerId: _currentUserId);
          if(mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => TelaNexoPad(document: newDoc)));
          }
        }, child: Text('hubDetail_createButton'.tr())),
      ],
    ));
  }

  void _showShareDeckDialog() {
    final firestoreService = context.read<FirestoreService>();
    final hubService = context.read<NexoHubService>();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text('hubDetail_sharePersonalDeckTitle'.tr()),
      content: SizedBox(width: double.maxFinite, child: StreamBuilder<List<Baralho>>(
        stream: firestoreService.getBaralhos(_currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return Text('hubDetail_noPersonalDecks'.tr());
          final decks = snapshot.data!;
          return ListView.builder(shrinkWrap: true, itemCount: decks.length, itemBuilder: (context, index) {
            final deck = decks[index];
            return ListTile(title: Text(deck.nome), onTap: () async {
              final cards = await firestoreService.getCards(_currentUserId, deck.id!).first;
              await hubService.shareDeckWithHub(hubId: widget.hub.id, baralho: deck, cards: cards);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('hubDetail_deckSharedSuccess'.tr(namedArgs: {'deckName': deck.nome})), backgroundColor: Colors.green));
              }
            });
          });
        },
      )),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserProfile == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hub.name),
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.info_outline), text: 'hubDetail_tabAbout'.tr()),
            Tab(icon: const Icon(Icons.people), text: 'hubDetail_tabMembers'.tr()),
            Tab(icon: const Icon(Icons.calendar_month), text: 'hubDetail_tabSchedule'.tr()),
            Tab(icon: const Icon(Icons.chat_bubble), text: 'hubDetail_tabChat'.tr()),
            Tab(icon: const Icon(Icons.hub_outlined), text: 'hubDetail_tabMap'.tr()),
            Tab(icon: const Icon(Icons.note_add), text: 'hubDetail_tabDocs'.tr()),
            Tab(icon: const Icon(Icons.style), text: 'hubDetail_tabDecks'.tr()),
            Tab(icon: const Icon(Icons.forum), text: 'hubDetail_tabForum'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        physics: _tabBarPhysics,
        controller: _tabController,
        children: [
          _SobreTab(description: widget.hub.description),
          _MembrosTab(hubId: widget.hub.id),
          TelaAgendaHub(
            hubId: widget.hub.id,
            hubName: widget.hub.name,
            showEventDialog: _showCreateEventDialog,
            currentUserProfile: _currentUserProfile!,
            onDaySelectedCallback: (day) => setState(() => _selectedAgendaDay = day),
          ),
          _HubChatWrapper(hub: widget.hub),
          MindMapScreenNativo(controller: _mindMapController),
          _DocumentosTab(hubId: widget.hub.id),
          _BaralhosTab(hubId: widget.hub.id),
          ForumWidget(
            topicsCollection: _firestore.collection('hubs').doc(widget.hub.id).collection('forum_topics'),
            currentUser: _currentUserProfile!,
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

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
    if (existingRoom != null) return existingRoom;
    final newChatRoom = ChatRoom(id: widget.hub.id, type: ChatRoomType.group, memberIds: widget.hub.memberIds, hubId: widget.hub.id, memberInfo: {'hubName': widget.hub.name}, createdAt: Timestamp.now(), lastMessageTimestamp: Timestamp.now());
    final createdRoom = await _chatService.createChatRoom(newChatRoom);
    return createdRoom!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatRoom>(
      future: _chatRoomFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('hubDetail_chatLoadError'.tr(namedArgs: {'error': snapshot.error.toString()})));
        if (!snapshot.hasData) return Center(child: Text('hubDetail_chatLoadErrorGeneric'.tr()));
        final chatRoom = snapshot.data!;
        return TelaChatMensagensSemAppBar(chatRoom: chatRoom);
      },
    );
  }
}

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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('hubDetail_noMembersFound'.tr()));
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
        title: Text('hubDetail_deleteDocumentTitle'.tr()),
        content: Text('hubDetail_deleteDocumentConfirmation'.tr(namedArgs: {'docTitle': doc.title})),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('cancelButton'.tr())),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('hubDetail_deleteButton'.tr(), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await hubService.deleteSharedDocument(hubId, doc.id);
  }

  @override
  Widget build(BuildContext context) {
    final hubService = Provider.of<NexoHubService>(context, listen: false);
    return StreamBuilder<List<NexoPadDocument>>(
      stream: hubService.getSharedDocumentsStream(hubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('hubDetail_noSharedDocuments'.tr()));
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
                  if (value == 'delete') _deleteHubDocument(context, hubService, doc);
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete, color: Colors.redAccent), title: Text('hubDetail_deleteButton'.tr(), style: const TextStyle(color: Colors.redAccent)))),
                ],
              ),
              onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => TelaNexoPad(document: doc)));
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
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('hubDetail_noSharedDecks'.tr()));
          final decks = snapshot.data!;
          return ListView.builder(
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return ListTile(
                leading: const Icon(Icons.style),
                title: Text(deck.nome),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => TelaDetalheBaralhoCompartilhado(hubId: hubId, baralho: deck)));
                },
              );
            },
          );
        },
      );
  }
}

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
    if (mounted) setState(() => _memberProfiles = {for (var p in profiles) p.id: p});
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendMessage(roomId: widget.chatRoom.id, text: _messageController.text, senderId: _currentUserId);
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
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('hubDetail_noMessages'.tr()));
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
      decoration: BoxDecoration(color: isMe ? Colors.blueAccent : Colors.grey[800], borderRadius: BorderRadius.circular(16)),
      child: Text(message.text, style: const TextStyle(color: Colors.white)),
    );
    if (isMe) return Row(mainAxisAlignment: MainAxisAlignment.end, children: [bubble]);
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          UserAvatar(username: sender?.username ?? '?', photoUrl: sender?.photoUrl, radius: 16),
          const SizedBox(width: 4),
          bubble,
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _messageController, decoration: InputDecoration(hintText: 'hubDetail_chatInputHint'.tr(), border: InputBorder.none), onSubmitted: (_) => _sendMessage())),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }
}
