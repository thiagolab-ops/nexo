import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/services/profile_service.dart';

class UserListView extends StatefulWidget {
  final List<String> userIds;
  final UserModel currentUserProfile;
  final String? title;

  const UserListView({
    super.key,
    required this.userIds,
    required this.currentUserProfile,
    this.title,
  });

  @override
  _UserListViewState createState() => _UserListViewState();
}

class _UserListViewState extends State<UserListView> {
  final ProfileService _profileService = ProfileService();
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _profileService.getUsersFromIdList(widget.userIds);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              widget.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _usersFuture,
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
                  final bool isFollowing = widget.currentUserProfile.followingIds?.contains(user.id) ?? false;
                  final bool isFollower = widget.currentUserProfile.followerIds?.contains(user.id) ?? false;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user.username[0].toUpperCase()),
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.bio ?? ''),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (isFollowing)
                          Chip(
                            label: const Text('Seguindo'),
                            backgroundColor: Colors.green.shade100,
                          ),
                        if (isFollower)
                          Chip(
                            label: const Text('Seguidor'),
                            backgroundColor: Colors.blue.shade100,
                          ),
                      ],
                    ),
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
    );
  }
}
