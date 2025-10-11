import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexo/models/models.dart';
import 'package:nexo/screens/tela_criar_post.dart';
import 'package:nexo/services/feed_service.dart';
import 'package:nexo/services/profile_service.dart';
import 'package:nexo/widgets/post_widget.dart';

class TelaFeed extends StatefulWidget {
  const TelaFeed({super.key});

  @override
  State<TelaFeed> createState() => _TelaFeedState();
}

class _TelaFeedState extends State<TelaFeed> {
  final FeedService _feedService = FeedService();
  final ProfileService _profileService = ProfileService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Post>>(
        stream: _feedService.getFeedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('feed_loadError'.tr(namedArgs: {'error': snapshot.error.toString()})));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'feed_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostWidget(post: post);
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<UserModel?>(
        stream: _profileService.getUserProfileStream(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.role == 'professor') {
            return FloatingActionButton(
              heroTag: 'fab_feed',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const TelaCriarPost(),
                  fullscreenDialog: true,
                ));
              },
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        }
      ),
    );
  }
}
