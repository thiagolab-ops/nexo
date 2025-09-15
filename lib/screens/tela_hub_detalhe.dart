import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_mapa_mental.dart';
import 'package:nexo/services/chat_service.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/services/firestore_service.dart';
import 'package:nexo/services/quiz_service.dart';
import 'package:nexo/screens/tela_detalhe_baralho_compartilhado.dart';
import 'package:nexo/screens/tela_nexo_pad.dart';
import 'package:nexo/screens/tela_realizar_quiz.dart';
import 'package:nexo/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- TELA PRINCIPAL DO HUB (PAI COM O TABCONTROLLER) ---
class TelaHubDetalhe extends StatefulWidget {
  final NexoHub hub;
  const TelaHubDetalhe({super.key, required this.hub});

  @override
  State<TelaHubDetalhe> createState() => _TelaHubDetalheState();
}

class _TelaHubDetalheState extends State<TelaHubDetalhe> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Força a reconstrução para atualizar o FAB
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Lógica de abertura do Chat do Hub
  void _openChat() async {
    final chatService = context.read<ChatService>();
    final existingRoom = await chatService.getChatRoomById(widget.hub.id);

    if (existingRoom != null) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: existingRoom)),
        );
      }
      return;
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

    final createdRoom = await chatService.createChatRoom(newChatRoom);
    if (createdRoom != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => TelaChatMensagens(chatRoom: createdRoom)),
      );
    }
  }

  // Lógica do FAB Inteligente
  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 2: // Aba Documentos
        return FloatingActionButton(
          onPressed: () => _showCreateSharedDocumentDialog(),
          tooltip: 'Novo Documento',
          child: const Icon(Icons.note_add), // ÍCONE CORRIGIDO
        );
      case 3: // Aba Baralhos
        return FloatingActionButton(
          onPressed: () => _showShareDeckDialog(),
          tooltip: 'Compartilhar Baralho Pessoal',
          child: const Icon(Icons.share),
        );
      case 4: // Aba Provas
        return FloatingActionButton(
          onPressed: () => _showShareQuizDialog(),
          tooltip: 'Compartilhar Prova Pessoal',
          child: const Icon(Icons.share),
        );
      default: // Abas Sobre e Membros não têm FAB
        return null;
    }
  }

  // Diálogo para criar novo documento
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

  // Diálogo para compartilhar baralho pessoal
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

  // Diálogo para compartilhar prova pessoal
  void _showShareQuizDialog() {
    final quizService = context.read<QuizService>();
    final hubService = context.read<NexoHubService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartilhar Prova Pessoal'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Quiz>>(
            stream: quizService.getAllQuizzesForUserStream(), // MÉTODO CORRIGIDO
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Text('Você não possui nenhuma prova para compartilhar.');

              final quizzes = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  return ListTile(
                    title: Text(quiz.title),
                    subtitle: Text('ID do Baralho: ${quiz.sourceDeckId}'),
                    onTap: () async {
                      await hubService.shareQuizWithHub(hubId: widget.hub.id, quiz: quiz);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${quiz.title} compartilhada!'), backgroundColor: Colors.green));
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
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => TelaMapaMental(hubId: widget.hub.id),
              ));
            },
            tooltip: 'Mapa Mental do Hub',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble),
            onPressed: _openChat,
            tooltip: 'Chat do Hub',
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Garante que as abas caibam
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Sobre'),
            Tab(icon: Icon(Icons.people), text: 'Membros'),
            Tab(icon: Icon(Icons.edit_document), text: 'Docs'),
            Tab(icon: Icon(Icons.style), text: 'Baralhos'),
            Tab(icon: Icon(Icons.quiz), text: 'Provas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SobreTab(description: widget.hub.description),
          _MembrosTab(hubId: widget.hub.id),
          _DocumentosTab(hubId: widget.hub.id),
          _BaralhosTab(hubId: widget.hub.id),
          _ProvasTab(hubId: widget.hub.id),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
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
          return const Center(child: Text('Nenhum documento compartilhado neste Hub.'));
        }
        final docs = snapshot.data!;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return ListTile(
              leading: const Icon(Icons.edit_document),
              title: Text(doc.title),
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
           return const Center(child: Text('Nenhum baralho compartilhado neste Hub.'));
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
                    // CONSTRUTOR CORRIGIDO
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
           return const Center(child: Text('Nenhuma prova compartilhada neste Hub.'));
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
