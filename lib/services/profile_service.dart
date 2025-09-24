import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

class ProfileService {
  FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  void setFirestoreForTests(FirebaseFirestore firestore) {
    _db = firestore;
  }
   void setAuthForTests(FirebaseAuth auth) {
    _auth = auth;
  }
  
  CollectionReference<UserModel> get _usersRef => 
      _db.collection('users').withConverter<UserModel>(
        fromFirestore: (snapshot, _) => UserModel.fromFirestore(snapshot),
        toFirestore: (user, _) => user.toMap(),
      );

  // --- MÉTODOS REINTEGRADOS PARA A TELA DE ESTUDO ---
  
  /// Adiciona uma quantidade de XP ao perfil do usuário.
  Future<void> addXp(String userId, int amount) async {
    if (amount <= 0) return;
    // Usa FieldValue.increment para uma operação atômica e segura
    await _usersRef.doc(userId).update({'xp': FieldValue.increment(amount)});
  }

  /// Atualiza a sequência de estudos (streak) do usuário.
  Future<void> updateStudyStreak(String userId) async {
    final userDoc = await _usersRef.doc(userId).get();
    if (!userDoc.exists) return;

    final user = userDoc.data()!;
    // Garante que o UserModel tenha o campo lastStudyDate
    if (user.lastStudyDate == null) return; 

    final now = DateTime.now();
    final lastStudy = user.lastStudyDate!.toDate();
    
    // Calcula a diferença em dias ignorando as horas
    final difference = DateTime(now.year, now.month, now.day)
        .difference(DateTime(lastStudy.year, lastStudy.month, lastStudy.day))
        .inDays;
    
    // Se o último estudo foi ontem, incrementa o streak.
    if (difference == 1) {
      await _usersRef.doc(userId).update({
        'studyStreak': FieldValue.increment(1),
        'lastStudyDate': Timestamp.fromDate(now),
      });
    } 
    // Se o último estudo foi hoje, não faz nada.
    else if (difference == 0) {
      return;
    }
    // Se faz mais de um dia que não estuda, reseta o streak para 1.
    else {
      await _usersRef.doc(userId).update({
        'studyStreak': 1,
        'lastStudyDate': Timestamp.fromDate(now),
      });
    }
  }

  // --- FIM DOS MÉTODOS REINTEGRADOS ---

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
      // Garante que os campos existam na criação do usuário
      xp: 0,
      studyStreak: 0,
    );
    await _usersRef.doc(uid).set(newUser);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _usersRef.doc(uid).update(data);
  }

  Future<List<UserModel>> getUsersFromIdList(List<String> userIds) async { if (userIds.isEmpty) return []; List<UserModel> users = []; for (var i = 0; i < userIds.length; i += 30) { var sublist = userIds.sublist(i, i + 30 > userIds.length ? userIds.length : i + 30); if (sublist.isNotEmpty) { final snapshot = await _usersRef.where(FieldPath.documentId, whereIn: sublist).get(); users.addAll(snapshot.docs.map((doc) => doc.data()!)); } } return users; }

  Future<List<UserModel>> searchUsersByUsername({required String query, required String currentUserId}) async { if (query.isEmpty) return []; final snapshot = await _usersRef.where('username', isGreaterThanOrEqualTo: query).where('username', isLessThan: '${query}\uf8ff').limit(15).get(); return snapshot.docs.map((doc) => doc.data()!).where((user) => user.id != currentUserId).toList(); }

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
    if (user != null && user.blockedUserIds != null && user.blockedUserIds!.isNotEmpty) {
      return getUsersFromIdList(user.blockedUserIds!);
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

  // --- FUNÇÃO "SOU PROFESSOR" ---
  Future<void> applyToBeProfessor({
    required String userId,
    required String specialties,
    required String socialLinks,
  }) async {
    final applicationData = {
      'userId': userId,
      'specialties': specialties,
      'socialLinks': socialLinks,
      'status': 'pending', // Fica pendente para sua aprovação manual
      'createdAt': FieldValue.serverTimestamp(),
    };
    // Salva a aplicação em uma nova coleção
    await _db.collection('professor_applications').doc(userId).set(applicationData);
  }
  // --- FIM DA FUNÇÃO ---
}
