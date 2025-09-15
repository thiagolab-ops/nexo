import 'package:cloud_firestore/cloud_firestore.dart';

// --- MODELOS DE POST E COMMENT RESTAURADOS ---

class Post {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final String text;
  final Timestamp createdAt;
  final List<String> likes;
  final int commentCount;
  final int deckCreationCount;

  Post({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
    this.likes = const [],
    this.commentCount = 0,
    this.deckCreationCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': createdAt,
      'likes': likes,
      'commentCount': commentCount,
      'deckCreationCount': deckCreationCount,
    };
  }

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, [SnapshotOptions? options]) {
    final data = doc.data()!;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      deckCreationCount: data['deckCreationCount'] ?? 0,
    );
  }
}

class Comment {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final String text;
  final Timestamp createdAt;

  Comment({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, [SnapshotOptions? options]) {
    final data = doc.data()!;
    return Comment(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}

// --- OUTROS MODELOS ---

class ReportModel {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String contentId;
  final String contentType;
  final String reason;
  final Timestamp createdAt;
  final String status;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.contentId,
    required this.contentType,
    required this.reason,
    required this.createdAt,
    this.status = 'new',
  });
  
  factory ReportModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data()!;
    return ReportModel(
      id: snapshot.id,
      reporterId: data['reporterId'],
      reportedUserId: data['reportedUserId'],
      contentId: data['contentId'],
      contentType: data['contentType'],
      reason: data['reason'],
      createdAt: data['createdAt'],
      status: data['status'] ?? 'new',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'contentId': contentId,
      'contentType': contentType,
      'reason': reason,
      'createdAt': createdAt,
      'status': status,
    };
  }
}

class ProfessorStats {
  final int totalLikes;
  final int totalComments;
  final int totalDeckCreations;
  final int postCount;
  final Timestamp lastUpdated;

  ProfessorStats({
    this.totalLikes = 0,
    this.totalComments = 0,
    this.totalDeckCreations = 0,
    this.postCount = 0,
    required this.lastUpdated,
  });

  factory ProfessorStats.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, [SnapshotOptions? options]) {
    final data = doc.data() ?? {};
    return ProfessorStats(
      totalLikes: data['totalLikes'] ?? 0,
      totalComments: data['totalComments'] ?? 0,
      totalDeckCreations: data['totalDeckCreations'] ?? 0,
      postCount: data['postCount'] ?? 0,
      lastUpdated: data['lastUpdated'] ?? Timestamp.now(),
    );
  }
}

class NotificationModel {
  final String id;
  final String text;
  final String sourceType;
  final String sourceId;
  final Timestamp createdAt;
  final bool isRead;
  final String? relatedHubId;
  final String? meetLink;

  NotificationModel({
    required this.id,
    required this.text,
    required this.sourceType,
    required this.sourceId,
    required this.createdAt,
    this.isRead = false,
    this.relatedHubId,
    this.meetLink,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, [SnapshotOptions? options]) {
    final data = doc.data()!;
    return NotificationModel(
      id: doc.id,
      text: data['text'] ?? '',
      sourceType: data['sourceType'] ?? '',
      sourceId: data['sourceId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      relatedHubId: data['relatedHubId'],
      meetLink: data['meetLink'],
    );
  }
}

class HubEvent {
  final String id;
  final String title;
  final DateTime date;
  final String creatorId;
  final String creatorUsername;
  final String? meetLink;
  final String? audience;

  HubEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.creatorId,
    required this.creatorUsername,
    this.meetLink,
    this.audience,
  });

  factory HubEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, [SnapshotOptions? options]) {
    final data = doc.data()!;
    return HubEvent(
      id: doc.id,
      title: data['title'] ?? 'Evento sem título',
      date: (data['date'] as Timestamp).toDate(),
      creatorId: data['creatorId'] ?? '',
      creatorUsername: data['creatorUsername'] ?? '',
      meetLink: data['meetLink'],
      audience: data['audience'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'creatorId': creatorId,
      'creatorUsername': creatorUsername,
      'meetLink': meetLink,
      'audience': audience,
    };
  }
}

class UserModel {
  final String id;
  final String username;
  final String email;
  final String bio;
  final String photoUrl;
  final Timestamp createdAt;
  final List<String> followerIds;
  final List<String> followingIds;
  final List<String> blockedUserIds;
  final List<String> interests;
  final int xp;
  final int level;
  final int streak;
  final Timestamp lastStudyDate;
  final String role;
  final bool hasCompletedOnboarding;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.bio,
    required this.photoUrl,
    required this.createdAt,
    this.followerIds = const [],
    this.followingIds = const [],
    this.blockedUserIds = const [],
    this.interests = const [],
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    required this.lastStudyDate,
    this.role = 'student',
    this.hasCompletedOnboarding = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data()!;
    return UserModel(
      id: snapshot.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      followerIds: List<String>.from(data['followerIds'] ?? []),
      followingIds: List<String>.from(data['followingIds'] ?? []),
      blockedUserIds: List<String>.from(data['blockedUserIds'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      streak: data['streak'] ?? 0,
      lastStudyDate: data['lastStudyDate'] ?? data['createdAt'] ?? Timestamp.now(),
      role: data['role'] ?? 'student',
      hasCompletedOnboarding: data['hasCompletedOnboarding'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username, 'email': email, 'bio': bio, 'photoUrl': photoUrl,
      'createdAt': createdAt,
      'followerIds': followerIds,
      'followingIds': followingIds,
      'blockedUserIds': blockedUserIds,
      'interests': interests, 'xp': xp, 'level': level, 'streak': streak,
      'lastStudyDate': lastStudyDate,
      'role': role,
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }
}

class Baralho { 
  String? id; 
  String nome; 
  String? descricao; 
  String? ownerId;
  
  Baralho({ this.id, required this.nome, this.descricao, this.ownerId }); 

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'ownerId': ownerId,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}

class Cartao { 
  String? id; 
  String baralhoId; 
  String frente; 
  String verso; 
  DateTime proximaRevisao; 
  int intervalo; 
  double easeFactor; 
  int repeticoes; 
  Cartao({ this.id, required this.baralhoId, required this.frente, required this.verso, DateTime? proximaRevisao, this.intervalo = 0, this.easeFactor = 2.5, this.repeticoes = 0, }) : proximaRevisao = proximaRevisao ?? DateTime.now(); 
  
  Map<String, dynamic> toMap() { 
    return { 
      'baralho_id': baralhoId, 
      'frente': frente, 
      'verso': verso, 
      'proximaRevisao': Timestamp.fromDate(proximaRevisao), 
      'intervalo': intervalo, 
      'easeFactor': easeFactor, 
      'repeticoes': repeticoes, 
    }; 
  } 
  
  factory Cartao.fromMap(Map<String, dynamic> map) { 
    final data = map; 
    return Cartao( 
      id: data['id'], 
      baralhoId: data['baralho_id'], 
      frente: data['frente'], 
      verso: data['verso'], 
      proximaRevisao: (data['proximaRevisao'] as Timestamp).toDate(), 
      intervalo: data['intervalo'], 
      easeFactor: (data['easeFactor'] as num?)?.toDouble() ?? 2.5, 
      repeticoes: data['repeticoes'], 
    ); 
  } 
}

class NexoHub { 
  final String id; 
  final String name; 
  final String description; 
  final String ownerId; 
  final List<String> memberIds; 
  final Timestamp createdAt; 
  NexoHub({ required this.id, required this.name, required this.description, required this.ownerId, required this.memberIds, required this.createdAt, }); 
  
  factory NexoHub.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) { 
    final data = snapshot.data()!; 
    return NexoHub( 
      id: snapshot.id, 
      name: data['name'] ?? '', 
      description: data['description'] ?? '', 
      ownerId: data['ownerId'] ?? '', 
      memberIds: List<String>.from(data['memberIds'] ?? []), 
      createdAt: data['createdAt'] ?? Timestamp.now(), 
    ); 
  } 
  
  Map<String, dynamic> toMap() { 
    return { 
      'name': name, 
      'description': description, 
      'ownerId': ownerId, 
      'memberIds': memberIds, 
      'createdAt': createdAt, 
    }; 
  } 
}

class NexoPadDocument { 
  String id; 
  String title; 
  final String ownerId; 
  String contentJson; 
  final Timestamp createdAt;
  final Timestamp lastEdited; 
  final String? hubId; 
  final String? lastEditorId; 
  final String? lastEditorUsername; 
  
  NexoPadDocument({ 
    required this.id, 
    required this.title, 
    required this.ownerId, 
    required this.contentJson, 
    required this.createdAt, 
    required this.lastEdited, 
    this.hubId, 
    this.lastEditorId, 
    this.lastEditorUsername, 
  }); 
  
  factory NexoPadDocument.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) { 
    final data = snapshot.data()!; 
    return NexoPadDocument( 
      id: snapshot.id, 
      title: data['title'] ?? 'Sem Título', 
      ownerId: data['ownerId'] ?? '', 
      contentJson: data['contentJson'] ?? '[{"insert":"\\n"}]', 
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastEdited: data['lastEdited'] ?? Timestamp.now(), 
      hubId: data['hubId'], 
      lastEditorId: data['lastEditorId'], 
      lastEditorUsername: data['lastEditorUsername'], 
    ); 
  } 
  
  Map<String, dynamic> toMap() { 
    return { 
      'title': title, 
      'ownerId': ownerId, 
      'contentJson': contentJson, 
      'createdAt': createdAt,
      'lastEdited': lastEdited, 
      'lastEditorId': lastEditorId, 
      'lastEditorUsername': lastEditorUsername, 
    }; 
  } 
}

enum ChatRoomType { dm, group }

class ChatRoom { 
  final String id; 
  final ChatRoomType type; 
  final List<String> memberIds; 
  final String? hubId; 
  final Map<String, String> memberInfo; 
  final String lastMessage; 
  final Timestamp lastMessageTimestamp; 
  final Timestamp createdAt;
  
  ChatRoom({ 
    required this.id, 
    required this.type, 
    required this.memberIds, 
    this.hubId, 
    this.memberInfo = const {}, 
    this.lastMessage = '', 
    required this.lastMessageTimestamp, 
    required this.createdAt,
  }); 
  
  factory ChatRoom.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) { 
    final data = snapshot.data()!; 
    return ChatRoom( 
      id: snapshot.id, 
      type: ChatRoomType.values.byName(data['type'] ?? 'dm'), 
      memberIds: List<String>.from(data['memberIds'] ?? []), 
      hubId: data['hubId'], 
      memberInfo: Map<String, String>.from(data['memberInfo'] ?? {}), 
      lastMessage: data['lastMessage'] ?? '', 
      lastMessageTimestamp: data['lastMessageTimestamp'] ?? Timestamp.now(), 
      createdAt: data['createdAt'] ?? Timestamp.now(),
    ); 
  } 
  
  Map<String, dynamic> toMap() { 
    return { 
      'type': type.name, 
      'memberIds': memberIds, 
      'hubId': hubId, 
      'memberInfo': memberInfo, 
      'lastMessage': lastMessage, 
      'lastMessageTimestamp': lastMessageTimestamp, 
      'createdAt': createdAt,
    }; 
  } 
}

class ChatMessage { 
  final String id; 
  final String senderId; 
  final String text; 
  final Timestamp timestamp; 
  
  ChatMessage({ 
    required this.id, 
    required this.senderId, 
    required this.text, 
    required this.timestamp, 
  }); 
  
  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) { 
    final data = snapshot.data()!; 
    return ChatMessage( 
      id: snapshot.id, 
      senderId: data['senderId'] ?? '', 
      text: data['text'] ?? '', 
      timestamp: data['timestamp'] ?? Timestamp.now(), 
    ); 
  } 
}

class Quiz { 
  final String id; 
  final String title; 
  final String ownerId; 
  final String sourceDeckId; 
  final List<QuizQuestion> questions; 
  final Timestamp createdAt; 
  
  Quiz({ 
    required this.id, 
    required this.title, 
    required this.ownerId, 
    required this.sourceDeckId, 
    required this.questions, 
    required this.createdAt, 
  }); 
  
  Map<String, dynamic> toMap() { 
    return { 
      'title': title, 
      'ownerId': ownerId, 
      'sourceDeckId': sourceDeckId, 
      'questions': questions.map((q) => q.toMap()).toList(), 
      'createdAt': createdAt, 
    }; 
  } 
  
  factory Quiz.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) { 
    final data = snapshot.data()!; 
    return Quiz( 
      id: snapshot.id, 
      title: data['title'] ?? '', 
      ownerId: data['ownerId'] ?? '', 
      sourceDeckId: data['sourceDeckId'] ?? '', 
      questions: (data['questions'] as List).map((q) => QuizQuestion.fromMap(q)).toList(), 
      createdAt: data['createdAt'] ?? Timestamp.now(), 
    ); 
  } 
}

class QuizQuestion { 
  final String questionText; 
  final String correctAnswer; 
  final List<String> options; 
  final String id; 
  
  QuizQuestion({ 
    required this.questionText, 
    required this.correctAnswer, 
    required this.options, 
    required this.id 
  }); 
  
  Map<String, dynamic> toMap() { 
    return { 
      'questionText': questionText, 
      'correctAnswer': correctAnswer, 
      'options': options, 
      'id': id 
    }; 
  } 
  
  factory QuizQuestion.fromMap(Map<String, dynamic> map) { 
    return QuizQuestion( 
      questionText: map['questionText'] ?? '', 
      correctAnswer: map['correctAnswer'] ?? '', 
      options: List<String>.from(map['options'] ?? []), 
      id: map['id'] ?? '', 
    ); 
  } 
}

class AgendaEvent { 
  final String id; 
  final String title; 
  final DateTime date; 
  bool isDone; 
  
  AgendaEvent({ 
    required this.id, 
    required this.title, 
    required this.date, 
    this.isDone = false 
  }); 
  
  factory AgendaEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) { 
    final data = snapshot.data()!; 
    return AgendaEvent( 
      id: snapshot.id, 
      title: data['title'] ?? '', 
      date: (data['date'] as Timestamp).toDate(), 
      isDone: data['isDone'] ?? false, 
    ); 
  } 
  
  Map<String, dynamic> toMap() { 
    return { 'title': title, 'date': Timestamp.fromDate(date), 'isDone': isDone }; 
  } 
}
