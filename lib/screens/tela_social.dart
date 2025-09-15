import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/screens/tela_chats_lista.dart'; 
import '../models/models.dart';
import '../services/nexo_hub_service.dart';
import '../services/profile_service.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/user_list_view.dart';
import 'package:provider/provider.dart';

class TelaSocial extends StatefulWidget {
  const TelaSocial({super.key});

  @override
  State<TelaSocial> createState() => _TelaSocialState();
}

class _TelaSocialState extends State<TelaSocial> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfileService _profileService = ProfileService();
  final NexoHubService _hubService = NexoHubService();
  final _searchController = TextEditingController();
  Future<List<UserModel>>? _searchResultsFuture;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
          tabs: const [
            Tab(text: 'Conversas'),
            Tab(text: 'Procurar'),
            Tab(text: 'Seguidores'),
            Tab(text: 'Seguindo'),
            Tab(text: 'Convites de Hub'),
          ],
        ),
      ),
      body: currentUserProfile == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                const TelaChatsLista(),
                _buildSearchTab(currentUserProfile),
                UserListView(userIds: currentUserProfile.followerIds, currentUserProfile: currentUserProfile),
                UserListView(userIds: currentUserProfile.followingIds, currentUserProfile: currentUserProfile),
                _buildHubInvitesTab(),
              ],
            ),
    );
  }

  Widget _buildSearchTab(UserModel currentUserProfile) {
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

  // ABA DE CONVITES CORRIGIDA
  Widget _buildHubInvitesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>( // TIPO CORRIGIDO AQUI
      stream: _hubService.getReceivedHubInvitesStream(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text("Nenhum convite de Hub."));
        
        final invites = snapshot.data!; // 'invites' agora é uma List<Map>
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final inviteData = invites[index]; // cada item é um Map
            return ListTile(
              leading: const Icon(Icons.group_add),
              title: Text('Convite para o Hub "${inviteData['hubName'] ?? 'Nome Indisponível'}"'),
              subtitle: Text('Enviado por ${inviteData['fromUsername'] ?? 'Usuário Desconhecido'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: const Text("Aceitar", style: TextStyle(color: Colors.green)),
                    onPressed: () => _hubService.acceptHubInvite(inviteData['id']), // Acessando o ID do mapa
                  ),
                  TextButton(
                    child: const Text("Recusar", style: TextStyle(color: Colors.red)),
                    onPressed: () => _hubService.declineHubInvite(inviteData['id']), // Acessando o ID do mapa
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
