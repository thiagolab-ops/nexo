import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/widgets/forum_widget.dart';
import 'package:provider/provider.dart';

class TelaForumGlobal extends StatelessWidget {
  const TelaForumGlobal({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserProfile = Provider.of<UserModel?>(context);
    final firestore = FirebaseFirestore.instance;

    if (currentUserProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ForumWidget(
      // 1. Aponta para a coleção global '/topics'
      topicsCollection: firestore.collection('topics'),
      currentUser: currentUserProfile,
      // 2. LIGA as features avançadas que você pediu
      enableCloseTopic: true,
      enableBestAnswer: true,
    );
  }
}
