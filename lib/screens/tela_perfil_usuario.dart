import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/services/chat_service.dart';

class TelaPerfilUsuario extends StatefulWidget {
  final String userId;
  
  const TelaPerfilUsuario({super.key, required this.userId});

  @override
  _TelaPerfilUsuarioState createState() => _TelaPerfilUsuarioState();
}

class _TelaPerfilUsuarioState extends State<TelaPerfilUsuario> {
  final ProfileService _profileService = ProfileService();
  final ChatService _chatService = ChatService();
  UserModel? _userProfile;
  UserModel? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchCurrentUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final profile = await _profileService.getUserProfile(widget.userId);
    if (mounted) setState(() => _userProfile = profile);
  }

  Future<void> _fetchCurrentUserProfile() async {
    final profile = await _profileService.getUserProfile('current_user_id'); // Substitua pelo ID do usuário atual
    if (mounted) setState(() => _currentUserProfile = profile);
  }

  void _showBlockDialog(UserModel profileUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquear usuário'),
        content: Text('Tem certeza que deseja bloquear ${profileUser.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              // Implementar lógica de bloqueio
              Navigator.of(context).pop();
            },
            child: const Text('Bloquear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startChatWith(UserModel currentUser, UserModel otherUser) async {
    final chatRoom = await _chatService.getOrCreateDmRoom(currentUser, otherUser);
    // Navegar para a tela de chat
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_userProfile!.username),
      ),
      body: _buildProfileView(_userProfile),
    );
  }

  Widget _buildProfileView(UserModel? userProfile) {
    if (userProfile == null) {
      return const Center(child: Text('Perfil não encontrado'));
    }

    final bool isFollowing = _currentUserProfile?.followingIds?.contains(userProfile.id) ?? false;
    final bool isFollower = _currentUserProfile?.followerIds?.contains(userProfile.id) ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userProfile.username,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (userProfile.bio != null)
            Text(
              userProfile.bio!,
              style: const TextStyle(fontSize: 16),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatColumn('Seguidores', userProfile.followerIds?.length ?? 0),
              _buildStatColumn('Seguindo', userProfile.followingIds?.length ?? 0),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  if (isFollowing) {
                    // Deixar de seguir
                  } else {
                    // Seguir
                  }
                },
                child: Text(isFollowing ? 'Deixar de seguir' : 'Seguir'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _startChatWith(_currentUserProfile!, userProfile),
                child: const Text('Mensagem'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _showBlockDialog(userProfile),
                child: const Text('Bloquear'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(label),
        ],
      ),
    );
  }
}
