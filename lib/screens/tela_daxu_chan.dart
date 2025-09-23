import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/widgets/forum_widget.dart';
import 'package:provider/provider.dart';

// Esta tela agora é APENAS o Fórum Global (Nexo Chan)
class TelaDaxuChan extends StatelessWidget {
  const TelaDaxuChan({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserProfile = Provider.of<UserModel?>(context);
    final firestore = FirebaseFirestore.instance;

    if (currentUserProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ela simplesmente renderiza o ForumWidget que já fizemos
    return ForumWidget(
      topicsCollection: firestore.collection('topics'),
      currentUser: currentUserProfile,
      enableCloseTopic: true,
      enableBestAnswer: true,
    );
  }
}
