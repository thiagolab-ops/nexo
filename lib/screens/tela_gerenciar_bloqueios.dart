import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';

class TelaGerenciarBloqueios extends StatefulWidget {
  const TelaGerenciarBloqueios({super.key});

  @override
  _TelaGerenciarBloqueiosState createState() => _TelaGerenciarBloqueiosState();
}

class _TelaGerenciarBloqueiosState extends State<TelaGerenciarBloqueios> {
  final ProfileService _profileService = ProfileService();
  UserModel? _currentUserProfile;
  List<UserModel>? _blockedUsers;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
    _fetchBlockedUsers();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final profile = await _profileService.getUserProfile('current_user_id'); // Substitua pelo ID do usuário atual
    if (mounted) setState(() => _currentUserProfile = profile);
  }

  Future<void> _fetchBlockedUsers() async {
    if (_currentUserProfile?.blockedUserIds != null && _currentUserProfile!.blockedUserIds!.isNotEmpty) {
      final users = await _profileService.getUsersFromIdList(_currentUserProfile!.blockedUserIds!);
      if (mounted) setState(() => _blockedUsers = users);
    }
  }

  Future<void> _unblockUser(UserModel user) async {
    if (_currentUserProfile != null) {
      await _profileService.unblockUser(
        currentUserId: _currentUserProfile!.id,
        userIdToUnblock: user.id,
      );
      _fetchBlockedUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.username} foi desbloqueado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários Bloqueados'),
      ),
      body: _blockedUsers == null
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers!.isEmpty
              ? const Center(child: Text('Você não bloqueou nenhum usuário'))
              : ListView.builder(
                  itemCount: _blockedUsers!.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(user.username[0].toUpperCase()),
                        ),
                        title: Text(user.username),
                        subtitle: Text(user.bio ?? ''),
                        trailing: TextButton(
                          onPressed: () => _unblockUser(user),
                          child: const Text('Desbloquear'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
