import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // <-- IMPORTAÇÃO CORRIGIDA
import '../models/models.dart';
import '../services/profile_service.dart';
import 'user_avatar.dart';

class SearchResultTile extends StatelessWidget {
  final UserModel user;
  final UserModel currentUserProfile;
  final ProfileService profileService;

  const SearchResultTile({
    super.key,
    required this.user,
    required this.currentUserProfile,
    required this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    final bool isFollowing = currentUserProfile.followingIds.contains(user.id);

    if (currentUserProfile.blockedUserIds.contains(user.id)) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: UserAvatar(username: user.username, photoUrl: user.photoUrl),
      title: Text(user.username),
      subtitle: Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isFollowing
          ? ElevatedButton(
              onPressed: () => profileService.unfollowUser(currentUserId, user.id),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('Deixar de Seguir'),
            )
          : ElevatedButton(
              onPressed: () => profileService.followUser(currentUserId, user.id),
              child: const Text('Seguir'),
            ),
    );
  }
}
