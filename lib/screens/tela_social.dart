import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/nexo_hub_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/user_list_view.dart';

class TelaSocial extends StatefulWidget {
  const TelaSocial({super.key});

  @override
  _TelaSocialState createState() => _TelaSocialState();
}

class _TelaSocialState extends State<TelaSocial> {
  final ProfileService _profileService = ProfileService();
  final NexoHubService _hubService = NexoHubService();
  final TextEditingController _searchController = TextEditingController();
  Future<List<UserModel>>? _searchResultsFuture;
  UserModel? _currentUserProfile;
  String _currentUserId = 'current_user_id'; // Substitua pelo ID do usuário atual

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final profile = await _profileService.getUserProfile(_currentUserId);
    if (mounted) setState(() => _currentUserProfile = profile);
  }

  void _searchUsers(String query) {
    if (query.isNotEmpty) {
      setState(() {
        _searchResultsFuture = _profileService.searchUsersByUsername(
          query: query,
          currentUserId: _currentUserId,
        );
      });
    } else {
      setState(() {
        _searchResultsFuture = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar usuários...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          const SizedBox(height: 16),
          if (_currentUserProfile != null) ...[
            // Seguidores
            if (_currentUserProfile!.followerIds != null && _currentUserProfile!.followerIds!.isNotEmpty)
              UserListView(
                userIds: _currentUserProfile!.followerIds!,
                currentUserProfile: _currentUserProfile!,
              ),
            
            // Seguindo
            if (_currentUserProfile!.followingIds != null && _currentUserProfile!.followingIds!.isNotEmpty)
              UserListView(
                userIds: _currentUserProfile!.followingIds!,
                currentUserProfile: _currentUserProfile!,
              ),
          ],
          
          // Resultados da busca
          if (_searchResultsFuture != null)
            Expanded(
              child: FutureBuilder<List<UserModel>>(
                future: _searchResultsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum usuário encontrado'));
                  }
                  
                  final users = snapshot.data!;
                  
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.username[0].toUpperCase()),
                        ),
                        title: Text(user.username),
                        subtitle: Text(user.bio ?? ''),
                        onTap: () {
                          // Navegar para o perfil do usuário
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
