const admin = require("firebase-admin");
const functions = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");

const {defineSecret} = require("firebase-functions/params");
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

admin.initializeApp();
const db = admin.firestore();

exports.createCheckoutSession = functions.https.onCall({secrets: [stripeSecretKey]}, async (data, context) => {
  const stripe = require("stripe")(stripeSecretKey.value());
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado.");
  }
  const userId = context.auth.uid;
  const priceId = data.priceId;
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  const userData = userDoc.data();
  let stripeCustomerId = userData.stripeCustomerId;
  if (!stripeCustomerId) {
    const customer = await stripe.customers.create({
      email: context.auth.token.email,
      metadata: {firebaseUID: userId},
    });
    stripeCustomerId = customer.id;
    await userRef.update({stripeCustomerId: stripeCustomerId});
  }

  // Em produção, mude para o domínio real (daxu.app/perfil ou algo assim)
  const successUrl = "http://localhost:5000/";
  const cancelUrl = "http://localhost:5000/";

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

// ... (todas as outras funções permanecem como estavam) ...
