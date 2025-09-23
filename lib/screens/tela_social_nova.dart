import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chats_lista.dart'; 
import '../models/models.dart';
import '../services/nexo_hub_service.dart';
import '../services/profile_service.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/user_list_view.dart';
import 'package:provider/provider.dart';

// Esta é a NOVA tela Social, que contém apenas a gestão de comunidade
class TelaSocialNova extends StatefulWidget {
  const TelaSocialNova({super.key});

  @override
  State<TelaSocialNova> createState() => _TelaSocialNovaState();
}

class _TelaSocialNovaState extends State<TelaSocialNova> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ProfileService _profileService;
  late final NexoHubService _hubService;
  final _searchController = TextEditingController();
  Future<List<UserModel>>? _searchResultsFuture;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    // Agora tem 5 abas (sem o Fórum)
    _tabController = TabController(length: 5, vsync: this);
    _profileService = context.read<ProfileService>();
    _hubService = context.read<NexoHubService>();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  void _searchUsers() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        _searchResultsFuture = _profileService.searchUsersByUsername(
          query: query,
          currentUserId: _currentUserId,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserProfile = Provider.of<UserModel?>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          // Ordem que você pediu
          tabs: const [
            Tab(text: 'Conversas'),
            Tab(text: 'Seguidores'),
            Tab(text: 'Seguindo'),
            Tab(text: 'Convites de Hub'),
            Tab(text: 'Procurar'),
          ],
        ),
      ),
      body: currentUserProfile == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              // Ordem que você pediu
              children: [
                const TelaChatsLista(),
                UserListView(userIds: currentUserProfile.followerIds, currentUserProfile: currentUserProfile),
                UserListView(userIds: currentUserProfile.followingIds, currentUserProfile: currentUserProfile),
                _buildHubInvitesTab(),
                _buildSearchTab(currentUserProfile),
              ],
            ),
    );
  }

  Widget _buildSearchTab(UserModel currentUserProfile) {
    // (Esta função permanece a mesma)
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Procurar por @username',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Procurar',
                onPressed: _searchUsers,
              ),
            ),
            onSubmitted: (_) => _searchUsers(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _searchResultsFuture,
            builder: (context, snapshot) {
              if (_searchResultsFuture == null) return const Center(child: Text('Procure para encontrar outros campeões!'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Erro ao buscar: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum usuário encontrado.'));
              
              final results = snapshot.data!;
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final user = results[index];
                  return SearchResultTile(
                    user: user,
                    currentUserProfile: currentUserProfile,
                    profileService: _profileService,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHubInvitesTab() {
    // (Esta função permanece a mesma)
    return StreamBuilder<List<Map<String, dynamic>>>( 
      stream: _hubService.getReceivedHubInvitesStream(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text("Nenhum convite de Hub."));
        
        final invites = snapshot.data!; 
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final inviteData = invites[index]; 
            return ListTile(
              leading: const Icon(Icons.group_add),
              title: Text('Convite para o Hub "${inviteData['hubName'] ?? 'Nome Indisponível'}"'),
              subtitle: Text('Enviado por ${inviteData['fromUsername'] ?? 'Usuário Desconhecido'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: const Text("Aceitar", style: TextStyle(color: Colors.green)),
                    onPressed: () => _hubService.acceptHubInvite(inviteData['id']),
                  ),
                  TextButton(
                    child: const Text("Recusar", style: TextStyle(color: Colors.red)),
                    onPressed: () => _hubService.declineHubInvite(inviteData['id']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
