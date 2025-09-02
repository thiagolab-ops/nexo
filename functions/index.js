const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

admin.initializeApp();
const db = admin.firestore();

exports.processHubInvite = onDocumentUpdated("hub_invites/{inviteId}", async (event) => {
  const newData = event.data.after.data();
  const oldData = event.data.before.data();

  if (newData.status === "accepted" && oldData.status === "pending") {
    const {hubId, toUserId} = newData;
    const hubRef = db.collection("hubs").doc(hubId);
    
    await hubRef.update({memberIds: admin.firestore.FieldValue.arrayUnion(toUserId)});
    
    await event.data.after.ref.delete();
    
    logger.info(`Usuário ${toUserId} adicionado ao Hub ${hubId}.`);
  }
});

exports.onAulaConvocada = onDocumentCreated("hubs/{hubId}/events/{eventId}", async (event) => {
  const eventData = event.data.data();
  
  if (!eventData.meetLink || eventData.meetLink.trim() === '' || !eventData.audience) {
    return null;
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
    return null;
  }
  
  const batch = db.batch();
  recipientIds.forEach((userId) => {
    if (userId === creatorId) return;

    const notificationRef = db.collection("users").doc(userId).collection("notifications").doc();
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
  });

  return batch.commit();
});

exports.updateProfessorStats = onSchedule("every 24 hours", async (event) => {
  const professorsSnapshot = await db.collection("users").where("role", "==", "professor").get();
  if (professorsSnapshot.empty) {
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
  return null;
});

exports.followUser = onCall(async (request) => {
  if (!request.auth) { throw new HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado."); }
  const currentUserId = request.auth.uid;
  const targetUserId = request.data.userId;
  if (!targetUserId) { throw new HttpsError("invalid-argument", "A função deve ser chamada com um 'userId'."); }
  const currentUserRef = db.collection("users").doc(currentUserId);
  const targetUserRef = db.collection("users").doc(targetUserId);
  const batch = db.batch();
  batch.update(currentUserRef, {followingIds: admin.firestore.FieldValue.arrayUnion(targetUserId)});
  batch.update(targetUserRef, {followerIds: admin.firestore.FieldValue.arrayUnion(currentUserId)});
  const currentUserDoc = await currentUserRef.get();
  if (currentUserDoc.exists) {
    const currentUserUsername = currentUserDoc.data().username;
    const notificationPayload = {
      text: `${currentUserUsername} começou a te seguir.`,
      sourceType: "new_follower",
      sourceId: currentUserId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    const notificationRef = targetUserRef.collection("notifications").doc();
    batch.set(notificationRef, notificationPayload);
  }
  await batch.commit();
  return {status: "success"};
});

exports.unfollowUser = onCall(async (request) => {
  if (!request.auth) { throw new HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado."); }
  const currentUserId = request.auth.uid;
  const targetUserId = request.data.userId;
  if (!targetUserId) { throw new HttpsError("invalid-argument", "A função deve ser chamada com um 'userId'."); }
  const currentUserRef = db.collection("users").doc(currentUserId);
  const targetUserRef = db.collection("users").doc(targetUserId);
  const batch = db.batch();
  batch.update(currentUserRef, {followingIds: admin.firestore.FieldValue.arrayRemove(targetUserId)});
  batch.update(targetUserRef, {followerIds: admin.firestore.FieldValue.arrayRemove(currentUserId)});
  await batch.commit();
  return {status: "success"};
});
