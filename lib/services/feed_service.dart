import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexo/services/profile_service.dart';
import '../models/models.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _postsCollection = FirebaseFirestore.instance.collection('posts').withConverter<Post>(
        fromFirestore: (snapshot, _) => Post.fromFirestore(snapshot),
        toFirestore: (post, _) => post.toMap(),
      );
  final _profileService = ProfileService();
  final _auth = FirebaseAuth.instance;

  Future<Post?> getPostById(String postId) async {
    final doc = await _postsCollection.doc(postId).get();
    return doc.data();
  }

  Future<void> createPost({required String text}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final userProfile = await _profileService.getUserProfile(currentUser.uid);
    if (userProfile == null) return;
    final newPostRef = _postsCollection.doc();
    final newPost = Post(
      id: newPostRef.id,
      authorId: currentUser.uid,
      authorUsername: userProfile.username,
      authorPhotoUrl: userProfile.photoUrl,
      text: text,
      createdAt: Timestamp.now(),
    );
    await newPostRef.set(newPost);
  }

  Stream<List<Post>> getFeedStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    return _profileService.getUserProfileStream(currentUser.uid).asyncMap((userProfile) async {
      List<String> authorsToShow = [currentUser.uid];
      if (userProfile != null && userProfile.followingIds.isNotEmpty) {
        authorsToShow.addAll(userProfile.followingIds);
      }
      final chunks = <List<String>>[];
      for (var i = 0; i < authorsToShow.length; i += 30) {
        chunks.add(authorsToShow.sublist(i, i + 30 > authorsToShow.length ? authorsToShow.length : i + 30));
      }
      List<Post> allPosts = [];
      for (final chunk in chunks) {
        if (chunk.isEmpty) continue;
        final snapshot = await _postsCollection
            .where('authorId', whereIn: chunk)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
        allPosts.addAll(snapshot.docs.map((doc) => doc.data()).toList());
      }
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allPosts;
    });
  }

  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    final postRef = _postsCollection.doc(postId);
    if (isCurrentlyLiked) {
      await postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
    } else {
      await postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
    }
  }
  
  Future<void> addComment(String postId, String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final userProfile = await _profileService.getUserProfile(currentUser.uid);
    if (userProfile == null) return;
    final commentRef = _postsCollection.doc(postId).collection('comments').doc();
    final postRef = _postsCollection.doc(postId);
    final newComment = {
      'id': commentRef.id,
      'authorId': currentUser.uid,
      'authorUsername': userProfile.username,
      'authorPhotoUrl': userProfile.photoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch();
    batch.set(commentRef, newComment);
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment(String postId, String commentId) async {
      final postRef = _postsCollection.doc(postId);
      final commentRef = postRef.collection('comments').doc(commentId);

      final batch = _firestore.batch();
      batch.delete(commentRef);
      batch.update(postRef, {'commentCount': FieldValue.increment(-1)});
      await batch.commit();
  }

  Stream<List<Comment>> getCommentsStream(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .withConverter<Comment>(
            fromFirestore: (snapshot, _) => Comment.fromFirestore(snapshot),
            toFirestore: (_, __) => {})
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList());
  }
}
