const admin = require("firebase-admin");
const functions = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");

const {defineSecret} = require("firebase-functions/params");
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

admin.initializeApp();
const db = admin.firestore();

// ## INÍCIO DA CORREÇÃO: Sintaxe atualizada para v2 das Cloud Functions ##
exports.createCheckoutSession = functions.https.onCall({secrets: [stripeSecretKey]}, async (request) => {
  const stripe = require("stripe")(stripeSecretKey.value());

  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado.");
  }

  const userId = request.auth.uid;
  const priceId = request.data.priceId;
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Usuário não encontrado no Firestore.");
  }

  const userData = userDoc.data();
  let stripeCustomerId = userData.stripeCustomerId;

  if (!stripeCustomerId) {
    const customer = await stripe.customers.create({
      email: request.auth.token.email,
      metadata: {firebaseUID: userId},
    });
    stripeCustomerId = customer.id;
    await userRef.update({stripeCustomerId: stripeCustomerId});
  }

  const successUrl = "https://daxu.app/payment-success";
  const cancelUrl = "https://daxu.app/payment-cancel";

  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      mode: "subscription",
      customer: stripeCustomerId,
      line_items: [{price: priceId, quantity: 1}],
      success_url: successUrl,
      cancel_url: cancelUrl,
    });
    return {sessionId: session.id, sessionUrl: session.url};
  } catch (error) {
    logger.error("Erro ao criar sessão de checkout do Stripe:", error);
    throw new functions.https.HttpsError("internal", "Não foi possível criar a sessão de checkout.");
  }
});
// ## FIM DA CORREÇÃO ##

exports.deleteHub = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "...");
  }
  const userId = request.auth.uid;
  const {hubId} = request.data;
  if (!hubId) {
    throw new functions.https.HttpsError("invalid-argument", "...");
  }
  const hubRef = db.collection("hubs").doc(hubId);
  const hubDoc = await hubRef.get();
  if (!hubDoc.exists) {
    throw new functions.https.HttpsError("not-found", "...");
  }
  if (hubDoc.data().ownerId !== userId) {
    throw new functions.https.HttpsError("permission-denied", "...");
  }
  const chatRoomRef = db.collection("chatRooms").doc(hubId);
  const batch = db.batch();
  batch.delete(hubRef);
  batch.delete(chatRoomRef);
  try {
    await batch.commit();
    logger.info(`Hub e ChatRoom ${hubId} deletados por ${userId}.`);
    return {status: "success"};
  } catch (error) {
    logger.error(`Erro ao deletar Hub ${hubId}:`, error);
    throw new functions.https.HttpsError("internal", "...");
  }
});

exports.setUserRoleOnProfileUpdate = functions.firestore.onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  if (beforeData.role === afterData.role) {
    return null;
  }
  const {userId} = event.params;
  const {role: newRole} = afterData;
  try {
    await admin.auth().setCustomUserClaims(userId, {role: newRole});
    logger.info(`Custom claim para ${userId} definido como ${newRole}.`);
  } catch (error) {
    logger.error(`Erro ao definir custom claim para ${userId}:`, error);
  }
});

exports.onUserPromotedToProfessor = functions.firestore.onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  if (beforeData.role !== "professor" && afterData.role === "professor") {
    const {userId} = event.params;
    const userRef = db.collection("users").doc(userId);
    const notificationRef = userRef.collection("notifications").doc();
    const payload = {
      text: "Parabéns! Sua solicitação para se tornar um professor foi aprovada.",
      sourceType: "promotion_approved",
      sourceId: userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    const batch = db.batch();
    batch.set(notificationRef, payload);
    batch.update(userRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
    return batch.commit();
  }
  return null;
});

exports.onProfessorApplicationCreated = functions.firestore.onDocumentCreated("professor_applications/{applicationId}", async (event) => {
  const data = event.data.data();
  const applicantUsername = data.applicantUsername;
  const adminQuery = await db.collection("users").where("role", "==", "super_admin").get();
  if (adminQuery.empty) {
    return null;
  }
  const batch = db.batch();
  adminQuery.forEach((adminDoc) => {
    const userRef = adminDoc.ref;
    const notificationRef = userRef.collection("notifications").doc();
    const payload = {
      text: `${applicantUsername} solicitou para se tornar professor.`,
      sourceType: "professor_application",
      sourceId: event.params.applicationId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    batch.set(notificationRef, payload);
    batch.update(userRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
  });
  return batch.commit();
});

exports.onNewComment = functions.firestore.onDocumentCreated("posts/{postId}/comments/{commentId}", async (event) => {
  const commentData = event.data.data();
  const postId = event.params.postId;
  const postRef = db.collection("posts").doc(postId);
  const postDoc = await postRef.get();
  if (!postDoc.exists) return null;
  const postAuthorId = postDoc.data().authorId;
  const commentAuthorId = commentData.authorId;
  if (postAuthorId === commentAuthorId) return null;
  const userRef = db.collection("users").doc(postAuthorId);
  const notificationRef = userRef.collection("notifications").doc();
  const notificationPayload = {
    text: `${commentData.authorUsername} comentou no seu post.`,
    sourceType: "new_comment", sourceId: postId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false,
  };
  const batch = db.batch();
  batch.set(notificationRef, notificationPayload);
  batch.update(userRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
  return batch.commit();
});

exports.onPostLiked = functions.firestore.onDocumentUpdated("posts/{postId}", async (event) => {
  const likesBefore = event.data.before.data().likes || [];
  const likesAfter = event.data.after.data().likes || [];
  const newLikerId = likesAfter.find((liker) => !likesBefore.includes(liker));
  if (!newLikerId) return null;
  const postAuthorId = event.data.after.data().authorId;
  if (postAuthorId === newLikerId) return null;
  const likerDoc = await db.collection("users").doc(newLikerId).get();
  if (!likerDoc.exists) return null;
  const likerUsername = likerDoc.data().username;
  const userRef = db.collection("users").doc(postAuthorId);
  const notificationRef = userRef.collection("notifications").doc();
  const notificationPayload = {
    text: `${likerUsername} curtiu o seu post.`,
    sourceType: "new_like", sourceId: event.params.postId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false,
  };
  const batch = db.batch();
  batch.set(notificationRef, notificationPayload);
  batch.update(userRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
  return batch.commit();
});

exports.onAulaConvocada = functions.firestore.onDocumentCreated("hubs/{hubId}/events/{eventId}", async (event) => {
  const eventData = event.data.data();
  if (!eventData.meetLink || eventData.meetLink.trim() === "" || !eventData.audience) return null;
  const {creatorId, creatorUsername, title} = eventData;
  let recipientIds = [];
  if (eventData.audience === "followers") {
    const creatorDoc = await db.collection("users").doc(creatorId).get();
    recipientIds = creatorDoc.data().followerIds || [];
  } else {
    const hubDoc = await db.collection("hubs").doc(event.params.hubId).get();
    recipientIds = hubDoc.data().memberIds || [];
  }
  if (recipientIds.length === 0) return null;
  const batch = db.batch();
  recipientIds.forEach((userId) => {
    if (userId === creatorId) return;
    const userRef = db.collection("users").doc(userId);
    const notificationRef = userRef.collection("notifications").doc();
    const payload = {
      text: `${creatorUsername} convocou para a aula: "${title}"`,
      sourceType: "aula_convocada", sourceId: event.params.eventId,
      relatedHubId: event.params.hubId, meetLink: eventData.meetLink,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false,
    };
    batch.set(notificationRef, payload);
    batch.update(userRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
  });
  return batch.commit();
});

exports.followUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "...");
  const {uid} = context.auth;
  const {userId: targetUserId} = data;
  if (!targetUserId) throw new functions.https.HttpsError("invalid-argument", "...");
  const currentUserRef = db.collection("users").doc(uid);
  const targetUserRef = db.collection("users").doc(targetUserId);
  const [currentUserDoc, targetUserDoc] = await Promise.all([currentUserRef.get(), targetUserRef.get()]);
  if (!currentUserDoc.exists || !targetUserDoc.exists) throw new functions.https.HttpsError("not-found", "...");
  const {username: currentUserUsername} = currentUserDoc.data();
  const targetUserData = targetUserDoc.data();
  const {username: targetUserUsername} = targetUserData;
  const batch = db.batch();
  batch.update(currentUserRef, {followingIds: admin.firestore.FieldValue.arrayUnion(targetUserId)});
  batch.update(targetUserRef, {followerIds: admin.firestore.FieldValue.arrayUnion(uid)});
  const isCoNexo = targetUserData.followingIds?.includes(uid);
  if (isCoNexo) {
    const notifTargetPayload = {text: `Você e ${currentUserUsername} agora são Co-Nexos!`, sourceType: "new_conexo", sourceId: uid, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false};
    batch.set(targetUserRef.collection("notifications").doc(), notifTargetPayload);
    batch.update(targetUserRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
    const notifCurrentPayload = {text: `Você e ${targetUserUsername} agora são Co-Nexos!`, sourceType: "new_conexo", sourceId: targetUserId, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false};
    batch.set(currentUserRef.collection("notifications").doc(), notifCurrentPayload);
    batch.update(currentUserRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
  } else {
    const payload = {text: `${currentUserUsername} começou a te seguir.`, sourceType: "new_follower", sourceId: uid, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false};
    batch.set(targetUserRef.collection("notifications").doc(), payload);
    batch.update(targetUserRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});
  }
  await batch.commit();
  return {status: "success"};
});

exports.unfollowUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "...");
  const {uid} = context.auth;
  const {userId: targetUserId} = data;
  if (!targetUserId) throw new functions.https.HttpsError("invalid-argument", "...");
  const batch = db.batch();
  batch.update(db.collection("users").doc(uid), {followingIds: admin.firestore.FieldValue.arrayRemove(targetUserId)});
  batch.update(db.collection("users").doc(targetUserId), {followerIds: admin.firestore.FieldValue.arrayRemove(uid)});
  await batch.commit();
  return {status: "success"};
});

exports.processarConvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "...");
  const newUserId = context.auth.uid;
  const {referralUsername} = data;
  if (!referralUsername) throw new functions.https.HttpsError("invalid-argument", "...");
  const usersRef = db.collection("users");
  const q = await usersRef.where("username", "==", referralUsername).limit(1).get();
  if (q.empty) {
    logger.warn(`Referral username not found: ${referralUsername}`);
    return {status: "error", message: "Referrer not found"};
  }
  const referrerDoc = q.docs[0];
  const referrerId = referrerDoc.id;
  if (referrerId === newUserId) return {status: "success"};
  const newUserDoc = await usersRef.doc(newUserId).get();
  if (!newUserDoc.exists) throw new functions.https.HttpsError("not-found", "...");

  const batch = db.batch();
  const newUserRef = usersRef.doc(newUserId);
  const referrerRef = usersRef.doc(referrerId);

  batch.update(newUserRef, {
    followingIds: admin.firestore.FieldValue.arrayUnion(referrerId),
    followerIds: admin.firestore.FieldValue.arrayUnion(referrerId),
    referredBy: referrerId,
  });

  batch.update(referrerRef, {
    followerIds: admin.firestore.FieldValue.arrayUnion(newUserId),
    followingIds: admin.firestore.FieldValue.arrayUnion(newUserId),
    inviteCount: admin.firestore.FieldValue.increment(1),
  });

  const notifForReferrer = {text: `Você e ${newUserDoc.data().username} agora são Co-Nexos!`, sourceType: "new_conexo", sourceId: newUserId, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false};
  batch.set(referrerRef.collection("notifications").doc(), notifForReferrer);
  batch.update(referrerRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});

  const notifForNewUser = {text: `Você e ${referrerDoc.data().username} agora são Co-Nexos!`, sourceType: "new_conexo", sourceId: referrerId, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false};
  batch.set(newUserRef.collection("notifications").doc(), notifForNewUser);
  batch.update(newUserRef, {unreadNotificationCount: admin.firestore.FieldValue.increment(1)});

  await batch.commit();
  logger.info(`Invite from ${referrerId} for ${newUserId} processed.`);
  return {status: "success"};
});

exports.updateProfessorStats = functions.scheduler.onSchedule("every 24 hours", async (event) => {
  const professors = await db.collection("users").where("role", "==", "professor").get();
  if (professors.empty) {
    logger.info("Nenhum professor encontrado para atualizar estatísticas.");
    return null;
  }
  const promises = professors.docs.map((profDoc) => {
    const professorId = profDoc.id;
    return db.collection("posts").where("authorId", "==", professorId).get().then((posts) => {
      const stats = posts.docs.reduce((acc, post) => {
        acc.totalLikes += (post.data().likes || []).length;
        acc.totalComments += post.data().commentCount || 0;
        acc.totalDeckCreations += post.data().deckCreationCount || 0;
        return acc;
      }, {totalLikes: 0, totalComments: 0, totalDeckCreations: 0});
      logger.info(`Atualizando estatísticas para o professor ${professorId}`);
      return db.collection("users").doc(professorId).collection("professor_stats").doc("summary").set({
        ...stats, postCount: posts.size,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  });
  await Promise.all(promises);
  return null;
});

exports.processHubInvite = functions.firestore.onDocumentUpdated("hub_invites/{inviteId}", async (event) => {
  const {status: newStatus} = event.data.after.data();
  const {status: oldStatus} = event.data.before.data();
  if (newStatus === "accepted" && oldStatus === "pending") {
    const {hubId, toUserId} = event.data.after.data();
    const batch = db.batch();
    batch.update(db.collection("hubs").doc(hubId), {memberIds: admin.firestore.FieldValue.arrayUnion(toUserId)});
    batch.update(db.collection("chatRooms").doc(hubId), {memberIds: admin.firestore.FieldValue.arrayUnion(toUserId)});
    batch.delete(event.data.after.ref);
    await batch.commit();
  }
});
