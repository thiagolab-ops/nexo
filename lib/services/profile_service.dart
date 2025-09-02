import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final CollectionReference _usersRef = FirebaseFirestore.instance.collection('users');

  Future<void> completeOnboarding(String userId) async {
    await _usersRef.doc(userId).update({'hasCompletedOnboarding': true});
  }

  Stream<ProfessorStats?> getProfessorStatsStream(String professorId) {
    return _usersRef
        .doc(professorId)
        .collection('professor_stats')
        .doc('summary')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return ProfessorStats.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Future<void> followUser(String currentUserId, String targetUserId) async {
    final callable = _functions.httpsCallable('followUser');
    await callable.call({'userId': targetUserId});
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final callable = _functions.httpsCallable('unfollowUser');
    await callable.call({'userId': targetUserId});
  }
  
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    await _usersRef.doc(currentUserId).update({
      'blockedUserIds': FieldValue.arrayUnion([targetUserId])
    });
    await unfollowUser(currentUserId, targetUserId);
    await unfollowUser(targetUserId, currentUserId);
  }

  Future<void> performInitialWriteCheck(String uid) async {
    try {
      await _usersRef.doc(uid).set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      print("Initial write check failed (this can be normal): $e");
    }
  }

  Stream<UserModel?> getUserProfileStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) return UserModel.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
      return null;
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final docSnapshot = await _usersRef.doc(uid).get();
    if (docSnapshot.exists) return UserModel.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
    return null;
  }
    Future<void> createUserProfile({
      required String uid,
      required String username,
      required String email,
      required String bio,
      required List<String> interests,
    }) async {
      final newUser = UserModel(
        id: uid,
        username: username,
        email: email,
        bio: bio,
        photoUrl: '',
        createdAt: Timestamp.now(),
        interests: interests,
        lastStudyDate: Timestamp.now(),
        hasCompletedOnboarding: false,
      );
      await _usersRef.doc(uid).set(newUser.toMap());
    }
    Future<void> addXp(String userId, int amount) async { final userRef = _usersRef.doc(userId); await _firestore.runTransaction((transaction) async { final snapshot = await transaction.get(userRef); if (!snapshot.exists) throw Exception("User does not exist!"); final data = snapshot.data()! as Map<String, dynamic>; final int currentXp = data['xp'] ?? 0; final int currentLevel = data['level'] ?? 1; final int newXp = currentXp + amount; int xpForNextLevel = (100 * (currentLevel * 1.5)).round(); int newLevel = currentLevel; if (newXp >= xpForNextLevel) { newLevel++; } transaction.update(userRef, {'xp': newXp, 'level': newLevel}); }); }
    Future<void> updateStudyStreak(String userId) async { final userRef = _usersRef.doc(userId); await _firestore.runTransaction((transaction) async { final snapshot = await transaction.get(userRef); if (!snapshot.exists) return; final data = snapshot.data()! as Map<String, dynamic>; final int currentStreak = data['streak'] ?? 0; final Timestamp lastStudyTimestamp = data['lastStudyDate'] ?? Timestamp.now(); final lastStudyDate = lastStudyTimestamp.toDate(); final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); final yesterday = DateTime(now.year, now.month, now.day - 1); final lastStudyDay = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day); int newStreak = currentStreak; if (lastStudyDay.isAtSameMomentAs(yesterday)) { newStreak++; } else if (!lastStudyDay.isAtSameMomentAs(today)) { newStreak = 1; } transaction.update(userRef, {'streak': newStreak, 'lastStudyDate': Timestamp.now()}); }); }
    Future<List<UserModel>> getUsersFromIdList(List<String> userIds) async { if (userIds.isEmpty) return []; List<UserModel> users = []; for (var i = 0; i < userIds.length; i += 30) { var sublist = userIds.sublist(i, i + 30 > userIds.length ? userIds.length : i + 30); if (sublist.isNotEmpty) { final snapshot = await _usersRef.where(FieldPath.documentId, whereIn: sublist).get(); users.addAll(snapshot.docs.map((doc) => UserModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))); } } return users; }
    Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async { await _usersRef.doc(uid).update(data); }
    Future<List<UserModel>> searchUsersByUsername({required String query, required String currentUserId}) async { if (query.isEmpty) return []; final snapshot = await _usersRef.where('username', isGreaterThanOrEqualTo: query).where('username', isLessThan: '${query}\uf8ff').limit(15).get(); return snapshot.docs.map((doc) => UserModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).where((user) => user.id != currentUserId).toList(); }
    Future<void> unblockUser({required String currentUserId, required String userIdToUnblock}) async { await _usersRef.doc(currentUserId).update({ 'blockedUserIds': FieldValue.arrayRemove([userIdToUnblock]) }); }
    Future<bool> isUsernameUnique(String username) async { final query = await _usersRef.where('username', isEqualTo: username).limit(1).get(); return query.docs.isEmpty; }
    Future<String> uploadProfilePicture({ required String uid, required Uint8List imageData, }) async { final ref = _storage.ref().child('profile_pictures').child('$uid.jpg'); final metadata = SettableMetadata(contentType: 'image/jpeg'); final uploadTask = ref.putData(imageData, metadata); final snapshot = await uploadTask; final downloadUrl = await snapshot.ref.getDownloadURL(); await updateUserProfile(uid, {'photoUrl': downloadUrl}); return downloadUrl; }
}
