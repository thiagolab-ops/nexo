const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

admin.initializeApp();
const db = admin.firestore();

// --- FUNÇÕES DE NOTIFICAÇÃO (ATUALIZADAS) ---

exports.onNewComment = onDocumentCreated("posts/{postId}/comments/{commentId}", async (event) => {
  const commentData = event.data.data();
  const postId = event.params.postId;

  const postRef = db.collection("posts").doc(postId);
  const postDoc = await postRef.get();
  if (!postDoc.exists) {
    /* ... */ return null;
  }
  const postData = postDoc.data();
  const postAuthorId = postData.authorId;
  const commentAuthorId = commentData.authorId;
  const commentAuthorUsername = commentData.authorUsername;

  if (postAuthorId === commentAuthorId) {
    /* ... */ return null;
  }

  // --- LÓGICA DE INCREMENTO ADICIONADA ---
  const userRef = db.collection("users").doc(postAuthorId);
  const notificationRef = userRef.collection("notifications").doc();
  const notificationPayload = {
    text: `${commentAuthorUsername} comentou no seu post.`,
    sourceType: "new_comment",
    sourceId: postId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  };

  const batch = db.batch();
  batch.set(notificationRef, notificationPayload);
  batch.update(userRef, {
    unreadNotificationCount: admin.firestore.FieldValue.increment(1),
  });

  logger.info(`Enviando notificação de comentário e incrementando para ${postAuthorId}`);
  return batch.commit();
});

exports.onPostLiked = onDocumentUpdated("posts/{postId}", async (event) => {
  const postDataBefore = event.data.before.data();
  const postDataAfter = event.data.after.data();
  const likesBefore = postDataBefore.likes || [];
  const likesAfter = postDataAfter.likes || [];
  const newLikerId = likesAfter.find((liker) => !likesBefore.includes(liker));

  if (!newLikerId) {
    return null;
  }
  const postAuthorId = postDataAfter.authorId;
  if (postAuthorId === newLikerId) {
    /* ... */ return null;
  }

  const likerDoc = await db.collection("users").doc(newLikerId).get();
  if (!likerDoc.exists) {
    /* ... */ return null;
  }
  const likerUsername = likerDoc.data().username;

  // --- LÓGICA DE INCREMENTO ADICIONADA ---
  const userRef = db.collection("users").doc(postAuthorId);
  const notificationRef = userRef.collection("notifications").doc();
  const notificationPayload = {
    text: `${likerUsername} curtiu o seu post.`,
    sourceType: "new_like",
    sourceId: event.params.postId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  };

  const batch = db.batch();
  batch.set(notificationRef, notificationPayload);
  batch.update(userRef, {
    unreadNotificationCount: admin.firestore.FieldValue.increment(1),
  });

  logger.info(`Enviando notificação de like e incrementando para ${postAuthorId}`);
  return batch.commit();
});

exports.onAulaConvocada = onDocumentCreated("hubs/{hubId}/events/{eventId}", async (event) => {
  const eventData = event.data.data();

  if (!eventData.meetLink || eventData.meetLink.trim() === "" || !eventData.audience) {
    /* ... */ return null;
  }

  const creatorId = eventData.creatorId;
  const creatorUsername = eventData.creatorUsername;
  const eventTitle = eventData.title;
  let recipientIds = [];

  if (eventData.audience === "followers") {
    const creatorDoc = await db.collection("users").doc(creatorId).get();
    recipientIds = creatorDoc.data().followerIds || [];
  } else {
    const hubDoc = await db.collection("hubs").doc(event.params.hubId).get();
    recipientIds = hubDoc.data().memberIds || [];
  }

  if (recipientIds.length === 0) {
    /* ... */ return null;
  }

  const batch = db.batch();
  recipientIds.forEach((userId) => {
    if (userId === creatorId) return;

    const userRef = db.collection("users").doc(userId); // Ref do usuário
    const notificationRef = userRef.collection("notifications").doc();
    const notificationPayload = {
      text: `${creatorUsername} convocou para a aula: "${eventTitle}"`,
      sourceType: "aula_convocada",
      sourceId: event.params.eventId,
      relatedHubId: event.params.hubId,
      meetLink: eventData.meetLink,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    batch.set(notificationRef, notificationPayload);
    // --- LÓGICA DE INCREMENTO ADICIONADA AO BATCH ---
    batch.update(userRef, {
      unreadNotificationCount: admin.firestore.FieldValue.increment(1),
    });
  });

  logger.info(`Enviando ${recipientIds.length - 1} notificações de aula e incrementando contadores.`);
  return batch.commit();
});

// --- FUNÇÕES DE USUÁRIO (SEGUIR/DEIXAR DE SEGUIR) ATUALIZADAS ---

exports.followUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado.");
  }

  const currentUserId = request.auth.uid;
  const targetUserId = request.data.userId;
  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "A função deve ser chamada com um 'userId'.");
  }

  const currentUserRef = db.collection("users").doc(currentUserId);
  const targetUserRef = db.collection("users").doc(targetUserId);

  const currentUserDoc = await currentUserRef.get();
  const targetUserDoc = await targetUserRef.get();

  if (!currentUserDoc.exists || !targetUserDoc.exists) {
    throw new HttpsError("not-found", "Perfis de usuário não encontrados.");
  }

  const currentUserUsername = currentUserDoc.data().username;
  const targetUserData = targetUserDoc.data();
  const targetUserUsername = targetUserData.username;

  const batch = db.batch();

  batch.update(currentUserRef, {followingIds: admin.firestore.FieldValue.arrayUnion(targetUserId)});
  batch.update(targetUserRef, {followerIds: admin.firestore.FieldValue.arrayUnion(currentUserId)});

  const isCoNexo = targetUserData.followingIds && targetUserData.followingIds.includes(currentUserId);

  if (isCoNexo) {
    const notificationForTarget = {
      text: `Você e ${currentUserUsername} agora são Co-Nexos!`,
      sourceType: "new_conexo",
      sourceId: currentUserId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    const notifRefTarget = targetUserRef.collection("notifications").doc();
    batch.set(notifRefTarget, notificationForTarget);
    // --- LÓGICA DE INCREMENTO ADICIONADA ---
    batch.update(targetUserRef, {
      unreadNotificationCount: admin.firestore.FieldValue.increment(1),
    });

    const notificationForCurrent = {
      text: `Você e ${targetUserUsername} agora são Co-Nexos!`,
      sourceType: "new_conexo",
      sourceId: targetUserId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    const notifRefCurrent = currentUserRef.collection("notifications").doc();
    batch.set(notifRefCurrent, notificationForCurrent);
    // --- LÓGICA DE INCREMENTO ADICIONADA ---
    batch.update(currentUserRef, {
      unreadNotificationCount: admin.firestore.FieldValue.increment(1),
    });

    logger.info(`Co-Nexo criado e contadores incrementados para ${currentUserId} e ${targetUserId}.`);
  } else {
    const notificationPayload = {
      text: `${currentUserUsername} começou a te seguir.`,
      sourceType: "new_follower",
      sourceId: currentUserId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    const notificationRef = targetUserRef.collection("notifications").doc();
    batch.set(notificationRef, notificationPayload);
    // --- LÓGICA DE INCREMENTO ADICIONADA ---
    batch.update(targetUserRef, {
      unreadNotificationCount: admin.firestore.FieldValue.increment(1),
    });

    logger.info(`Usuário ${currentUserId} agora segue ${targetUserId}, contador incrementado.`);
  }

  await batch.commit();
  return {status: "success"};
});


exports.unfollowUser = onCall(async (request) => {
  // ... (sem mudanças aqui, "unfollow" não gera notificação)
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado.");
  }
  const currentUserId = request.auth.uid;
  const targetUserId = request.data.userId;
  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "A função deve ser chamada com um 'userId'.");
  }
  const currentUserRef = db.collection("users").doc(currentUserId);
  const targetUserRef = db.collection("users").doc(targetUserId);
  const batch = db.batch();
  batch.update(currentUserRef, {followingIds: admin.firestore.FieldValue.arrayRemove(targetUserId)});
  batch.update(targetUserRef, {followerIds: admin.firestore.FieldValue.arrayRemove(currentUserId)});

  await batch.commit();
  logger.info(`Usuário ${currentUserId} deixou de seguir ${targetUserId}.`);
  return {status: "success"};
});

exports.processarConvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado.");
  }

  const newUserId = request.auth.uid;
  const referralUsername = request.data.referralUsername;

  if (!referralUsername) {
    throw new HttpsError("invalid-argument", "O 'referralUsername' é obrigatório.");
  }

  const usersRef = db.collection("users");

  const referrerQuery = await usersRef.where("username", "==", referralUsername).limit(1).get();

  if (referrerQuery.empty) {
    logger.error(`Usuário de referência não encontrado: ${referralUsername}`);
    return {status: "error", message: "Referrer not found"};
  }

  const referrerDoc = referrerQuery.docs[0];
  const referrerId = referrerDoc.id;
  const referrerUsername = referrerDoc.data().username;

  const newUserDoc = await usersRef.doc(newUserId).get();
  if (!newUserDoc.exists) {
    throw new HttpsError("not-found", "Perfil do novo usuário não encontrado.");
  }
  const newUserUsername = newUserDoc.data().username;

  if (referrerId === newUserId) {
    logger.info("Usuário tentou se auto-convidar.");
    return {status: "success", message: "Self-referral ignored"};
  }

  const batch = db.batch();
  const newUserRef = usersRef.doc(newUserId);
  const referrerRef = usersRef.doc(referrerId);

  // Novo usuário segue o Referrer
  batch.update(newUserRef, {followingIds: admin.firestore.FieldValue.arrayUnion(referrerId)});
  batch.update(referrerRef, {followerIds: admin.firestore.FieldValue.arrayUnion(newUserId)});

  // Referrer segue o Novo usuário
  batch.update(referrerRef, {followingIds: admin.firestore.FieldValue.arrayUnion(newUserId)});
  batch.update(newUserRef, {followerIds: admin.firestore.FieldValue.arrayUnion(referrerId)});

  // Envia notificação de "Co-Nexo" para AMBOS e incrementa contadores
  const notificationForReferrer = {
    text: `Você e ${newUserUsername} agora são Co-Nexos!`,
    sourceType: "new_conexo",
    sourceId: newUserId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  };
  const notifRefReferrer = referrerRef.collection("notifications").doc();
  batch.set(notifRefReferrer, notificationForReferrer);
  // --- LÓGICA DE INCREMENTO ADICIONADA ---
  batch.update(referrerRef, {
    unreadNotificationCount: admin.firestore.FieldValue.increment(1),
  });


  const notificationForNewUser = {
    text: `Você e ${referrerUsername} agora são Co-Nexos!`,
    sourceType: "new_conexo",
    sourceId: referrerId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  };
  const notifRefNewUser = newUserRef.collection("notifications").doc();
  batch.set(notifRefNewUser, notificationForNewUser);
  // --- LÓGICA DE INCREMENTO ADICIONADA ---
  batch.update(newUserRef, {
    unreadNotificationCount: admin.firestore.FieldValue.increment(1),
  });

  await batch.commit();

  logger.info(`Convite processado: Co-Nexo criado entre ${newUserId} e ${referrerId}`);
  return {status: "success"};
});

// --- FUNÇÕES DE MANUTENÇÃO (AGENDADAS) ---
// (Sem mudanças aqui)
exports.updateProfessorStats = onSchedule("every 24 hours", async (event) => {
  logger.info("Iniciando a tarefa agendada: updateProfessorStats");
  const professorsSnapshot = await db.collection("users").where("role", "==", "professor").get();
  if (professorsSnapshot.empty) {
    logger.info("Nenhum professor encontrado. Finalizando a tarefa.");
    return null;
  }
  const promises = [];
  professorsSnapshot.forEach((profDoc) => {
    const professorId = profDoc.id;
    const processPromise = db.collection("posts").where("authorId", "==", professorId).get().then((postsSnapshot) => {
      let totalLikes = 0;
      let totalComments = 0;
      let totalDeckCreations = 0;
      postsSnapshot.forEach((postDoc) => {
        const postData = postDoc.data();
        totalLikes += (postData.likes || []).length;
        totalComments += postData.commentCount || 0;
        totalDeckCreations += postData.deckCreationCount || 0;
      });
      const stats = {
        totalLikes,
        totalComments,
        totalDeckCreations,
        postCount: postsSnapshot.size,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };
      return db.collection("users").doc(professorId).collection("professor_stats").doc("summary").set(stats);
    });
    promises.push(processPromise);
  });
  await Promise.all(promises);
  logger.info("Tarefa de atualização de estatísticas concluída com sucesso.");
  return null;
});

exports.processHubInvite = onDocumentUpdated("hub_invites/{inviteId}", async (event) => {
  const newData = event.data.after.data();
  const oldData = event.data.before.data();

  if (newData.status === "accepted" && oldData.status === "pending") {
    const {hubId, toUserId} = newData;
    const hubRef = db.collection("hubs").doc(hubId);
    const chatRoomRef = db.collection("chatRooms").doc(hubId);
    const batch = db.batch();
    batch.update(hubRef, {memberIds: admin.firestore.FieldValue.arrayUnion(toUserId)});
    batch.update(chatRoomRef, {memberIds: admin.firestore.FieldValue.arrayUnion(toUserId)});
    batch.delete(event.data.after.ref);
    await batch.commit();
    logger.info(`Usuário ${toUserId} adicionado ao Hub ${hubId}.`);
  }
});
