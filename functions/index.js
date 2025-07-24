/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
admin.initializeApp();

// Notification for new chat messages
exports.sendChatNotification = onDocumentCreated("chat_rooms/{chatRoomId}/messages/{messageId}", async (event) => {
  const message = event.data.data();
  const chatRoomId = event.params.chatRoomId;
  const senderId = message.senderId;

  // Get the recipient's ID from the chat room ID
  const userIds = chatRoomId.split("-");
  const recipientId = userIds.find((id) => id !== senderId);

  if (!recipientId) {
    logger.log("Recipient ID not found.");
    return;
  }

  // Get sender's and recipient's data
  const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
  const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();

  if (!senderDoc.exists || !recipientDoc.exists) {
    logger.log("Sender or recipient not found.");
    return;
  }

  const senderName = senderDoc.data().displayName;
  const recipientToken = recipientDoc.data().fcmToken;

  if (!recipientToken) {
    logger.log("Recipient FCM token not found.");
    return;
  }

  const payload = {
    notification: {
      title: `New message from ${senderName}`,
      body: message.text,
      sound: "default",
    },
    data: {
      type: "chat",
      chatRoomId: chatRoomId,
      senderId: senderId,
    },
  };

  try {
    await admin.messaging().sendToDevice(recipientToken, payload);
    logger.log("Chat notification sent successfully.");
  } catch (error) {
    logger.error("Error sending chat notification:", error);
  }
});

// Notification for friend requests
exports.sendFriendRequestNotification = onDocumentWritten("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const beforeRequests = before.friendRequestsReceived || [];
  const afterRequests = after.friendRequestsReceived || [];

  // Check if a new request was added
  if (afterRequests.length > beforeRequests.length) {
    const newRequestorId = afterRequests.find((id) => !beforeRequests.includes(id));

    if (!newRequestorId) return;

    const requestorDoc = await admin.firestore().collection("users").doc(newRequestorId).get();
    if (!requestorDoc.exists) return;

    const requestorName = requestorDoc.data().displayName;
    const recipientToken = after.fcmToken;

    if (!recipientToken) return;

    const payload = {
      notification: {
        title: "New Friend Request",
        body: `${requestorName} sent you a friend request.`,
        sound: "default",
      },
      data: {
        type: "friend_request",
        senderId: newRequestorId,
      },
    };

    try {
      await admin.messaging().sendToDevice(recipientToken, payload);
      logger.log("Friend request notification sent successfully.");
    } catch (error) {
      logger.error("Error sending friend request notification:", error);
    }
  }
});

// Notification for accepted friend requests
exports.sendFriendRequestAcceptedNotification = onDocumentWritten("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const beforeFriends = before.friends || [];
  const afterFriends = after.friends || [];

  // Check if a new friend was added
  if (afterFriends.length > beforeFriends.length) {
    const newFriendId = afterFriends.find((id) => !beforeFriends.includes(id));

    if (!newFriendId) return;

    // The user who accepted the request is the one whose document changed
    const acceptorName = after.displayName;
    const originalRequestorDoc = await admin.firestore().collection("users").doc(newFriendId).get();

    if (!originalRequestorDoc.exists) return;

    const originalRequestorToken = originalRequestorDoc.data().fcmToken;

    if (!originalRequestorToken) return;

    const payload = {
      notification: {
        title: "Friend Request Accepted",
        body: `${acceptorName} accepted your friend request.`,
        sound: "default",
      },
      data: {
        type: "friend_request_accepted",
        accepterId: event.params.userId,
      },
    };

    try {
      await admin.messaging().sendToDevice(originalRequestorToken, payload);
      logger.log("Friend request accepted notification sent successfully.");
    } catch (error) {
      logger.error("Error sending accepted notification:", error);
    }
  }
});
