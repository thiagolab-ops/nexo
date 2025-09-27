import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chat_mensagens.dart';
import 'package:nexo/screens/tela_nexogo_publica.dart'; 
import 'package:nexo/screens/widgets_perfil/perfil_forum_tab.dart';
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

class _TelaPerfilUsuarioState extends State<TelaPerfilUsuario> with SingleTickerProviderStateMixin {
  late final ProfileService _profileService;
  late final ChatService _chatService;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _profileService = context.read<ProfileService>();
    _chatService = context.read<ChatService>();
  }
  
  void _initTabs(UserModel user) {
    int count = 2; // Sobre, Tópicos
    if (user.isPrivileged) { // Usando a nova lógica centralizada
      count++; // Adiciona a aba "Daxu GO"
    }

    if (_tabController != null && _tabController!.length == count) return;
    
    _tabController?.dispose();
    setState(() {
      _tabController = TabController(length: count, vsync: this);
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

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

    return StreamBuilder<UserModel?>(
      stream: _profileService.getUserProfileStream(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || currentUserProfile == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        
        final userProfile = snapshot.data!;
        
        final expectedTabCount = userProfile.isPrivileged ? 3 : 2;
        if (_tabController == null || _tabController!.length != expectedTabCount) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _initTabs(userProfile);
           });
        }

        final bool isFollowing = currentUserProfile.followingIds.contains(userProfile.id);
        final bool isFollower = userProfile.followingIds.contains(currentUserProfile.id);
        final bool isCoNexo = isFollowing && isFollower;

        List<Widget> tabs = [
          const Tab(text: 'Sobre'),
          const Tab(text: 'Tópicos no Fórum'),
        ];
        if (userProfile.isPrivileged) {
          tabs.add(const Tab(text: 'Daxu GO'));
        }
        
        List<Widget> tabViews = [
           _buildSobreTab(userProfile, currentUserProfile, isCoNexo, isFollowing),
           PerfilForumTab(userId: userProfile.id),
        ];
        if (userProfile.isPrivileged) {
          tabViews.add(TelaNexoGoPublica(profUser: userProfile));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(userProfile.username),
            bottom: _tabController != null ? TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: tabs,
            ) : null,
          ),
          body: _tabController == null 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: tabViews,
              ),
        );
      },
    );
  }

  Widget _buildSobreTab(UserModel userProfile, UserModel currentUserProfile, bool isCoNexo, bool isFollowing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            UserAvatar(username: userProfile.username, photoUrl: userProfile.photoUrl, radius: 60),
            const SizedBox(height: 16),
            Text(userProfile.username, style: Theme.of(context).textTheme.headlineSmall),
            Text(userProfile.email),
            const SizedBox(height: 16),
            Text(userProfile.bio, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            
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
      ),
    );
  }
}
