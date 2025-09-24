import 'package:firebase_auth/firebase_auth.dart';
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
  late final String _currentUserId;
  late Future<List<UserModel>> _blockedUsersFuture;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _fetchBlockedUsers();
  }

  void _fetchBlockedUsers() {
    setState(() {
      _blockedUsersFuture = _profileService.getBlockedUsers(_currentUserId);
    });
  }

  Future<void> _unblockUser(UserModel user) async {
    // --- CORREÇÃO: Chamada com argumentos posicionais ---
    await _profileService.unblockUser(_currentUserId, user.id);
    
    _fetchBlockedUsers(); // Recarrega a lista
    if (mounted) {
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
      body: FutureBuilder<List<UserModel>>(
        future: _blockedUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar usuários: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Você não bloqueou nenhum usuário'));
          }
          
          final blockedUsers = snapshot.data!;
          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final user = blockedUsers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?'),
                  ),
                  title: Text(user.username),
                  subtitle: Text(user.bio),
                  trailing: TextButton(
                    onPressed: () => _unblockUser(user),
                    child: const Text('Desbloquear'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
