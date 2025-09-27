import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  CollectionReference<UserModel> get _usersRef => 
      _db.collection('users').withConverter<UserModel>(
        fromFirestore: (snapshot, _) => UserModel.fromFirestore(snapshot),
        toFirestore: (user, _) => user.toMap(),
      );

  Stream<ProfessorStats?> getProfessorStatsStream(String userId) {
    return _db.collection('users').doc(userId).collection('professor_stats').doc('summary').snapshots()
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
  
  Stream<UserModel?> getUserProfileStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) return snapshot.data();
      return null;
    });
  }
  
  Future<UserModel?> getUserProfile(String uid) async {
    final docSnapshot = await _usersRef.doc(uid).get();
    if (docSnapshot.exists) return docSnapshot.data();
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
      lastStudyDate: Timestamp.now(),
      hasCompletedOnboarding: true,
      interests: interests,
    );
    await _usersRef.doc(uid).set(newUser);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _usersRef.doc(uid).update(data);
  }

  Future<List<UserModel>> getUsersFromIdList(List<String> userIds) async { if (userIds.isEmpty) return []; List<UserModel> users = []; for (var i = 0; i < userIds.length; i += 30) { var sublist = userIds.sublist(i, i + 30 > userIds.length ? userIds.length : i + 30); if (sublist.isNotEmpty) { final snapshot = await _usersRef.where(FieldPath.documentId, whereIn: sublist).get(); users.addAll(snapshot.docs.map((doc) => doc.data())); } } return users; }

  Future<List<UserModel>> searchUsersByUsername({required String query, required String currentUserId}) async {
    if (query.isEmpty) return [];
    
    String cleanedQuery = query.trim();
    if (cleanedQuery.startsWith('@')) {
      cleanedQuery = cleanedQuery.substring(1);
    }
    if (cleanedQuery.isEmpty) return [];

    final snapshot = await _usersRef
        .where('username', isGreaterThanOrEqualTo: cleanedQuery)
        .where('username', isLessThan: '$cleanedQuery\uf8ff')
        .limit(15)
        .get();
    
    return snapshot.docs
        .map((doc) => doc.data())
        .where((user) => user.id != currentUserId)
        .toList();
  }

  Future<bool> isUsernameUnique(String username) async {
    final snapshot = await _usersRef.where('username', isEqualTo: username).limit(1).get();
    return snapshot.docs.isEmpty;
  }
  
  Future<String> uploadProfilePicture({required String uid, required Uint8List imageData}) async {
    final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');
    final uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
    final snapshot = await uploadTask.whenComplete(() => {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    
    await updateUserProfile(uid, {'photoUrl': downloadUrl});
    return downloadUrl;
  }

  Future<List<UserModel>> getBlockedUsers(String userId) async {
    final userDoc = await _usersRef.doc(userId).get();
    final user = userDoc.data();
    if (user != null && user.blockedUserIds.isNotEmpty) {
      return getUsersFromIdList(user.blockedUserIds);
    }
    return [];
  }

  Future<void> blockUser(String currentUserId, String targetUserId) async {
    await _usersRef.doc(currentUserId).update({
      'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
      'followingIds': FieldValue.arrayRemove([targetUserId]),
      'followerIds': FieldValue.arrayRemove([targetUserId]),
    });
    await _usersRef.doc(targetUserId).update({
      'followingIds': FieldValue.arrayRemove([currentUserId]),
      'followerIds': FieldValue.arrayRemove([currentUserId]),
    });
  }

  Future<void> unblockUser(String currentUserId, String targetUserId) async {
     await _usersRef.doc(currentUserId).update({
      'blockedUserIds': FieldValue.arrayRemove([targetUserId])
    });
  }

  Future<void> applyToBeProfessor({
    required String userId,
    required String specialties,
    required String socialLinks,
  }) async {
    final applicationData = {
      'userId': userId,
      'specialties': specialties,
      'socialLinks': socialLinks,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('professor_applications').doc(userId).set(applicationData);
  }

  // --- MÉTODOS DE GAMIFICAÇÃO REINSERIDOS ---
  
  Future<void> addXp(String uid, int xpAmount) async {
    await _usersRef.doc(uid).update({'xp': FieldValue.increment(xpAmount)});
  }

  bool _isYesterday(DateTime date1, DateTime date2) {
    final yesterday = DateTime(date2.year, date2.month, date2.day - 1);
    return date1.year == yesterday.year && date1.month == yesterday.month && date1.day == yesterday.day;
  }

  Future<void> updateStudyStreak(String uid) async {
    final userDoc = await _usersRef.doc(uid).get();
    if (!userDoc.exists) return;
    
    final user = userDoc.data()!;
    final lastStudy = user.lastStudyDate.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastStudyDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);

    if (lastStudyDay.isAtSameMomentAs(today)) {
      // Já estudou hoje, não faz nada
      return;
    }

    if (_isYesterday(lastStudyDay, today)) {
      // Estudou ontem, continua a sequência
      await userDoc.reference.update({
        'streak': FieldValue.increment(1),
        'lastStudyDate': Timestamp.now(),
      });
    } else {
      // Quebrou a sequência
      await userDoc.reference.update({
        'streak': 1,
        'lastStudyDate': Timestamp.now(),
      });
    }
  }
}
