import express from "express";
import { authenticate } from "../middleware/authMiddleware.js";
import {
    listConversations,
    createConversation,
    getMessages,
    sendMessage,
    editMessage,
    deleteMessage,
    getLinkPreview,
    getPinnedMessages,
    toggleMessagePin,
    toggleMessageReaction,
} from "../controllers/messagesController.js";
import {
    getConversationDetails,
    updateConversationName,
    updateConversationImage,
    addMembers,
    removeMember,
    updateMemberRole,
    updateSettings,
    updateNotifications,
    leaveConversation,
    togglePin,
    markAsRead,
    searchConversationMessages,
    getSharedMedia,
} from "../controllers/conversationSettingsController.js";

const router = express.Router();

router.use(authenticate);

// Conversation listing and creation routes.
router.get("/link-preview", getLinkPreview);

router.get("/conversations/:userId", listConversations);
router.post("/conversations", createConversation);

// Message retrieval routes.
router.get("/conversations/:conversationId/messages", getMessages);
router.post("/conversations/:conversationId/messages", sendMessage);
router.put("/conversations/:conversationId/messages/:messageId", editMessage);
router.delete("/conversations/:conversationId/messages/:messageId", deleteMessage);
router.post("/:id/reactions", toggleMessageReaction);

// Pinned message routes.
router.get("/conversations/:conversationId/messages/pinned", getPinnedMessages);
router.put("/conversations/:conversationId/messages/:messageId/pin", toggleMessagePin);

// Conversation details and settings routes.
router.get("/conversations/:id/details", getConversationDetails);
router.put("/conversations/:id/name", updateConversationName);
router.put("/conversations/:id/image", updateConversationImage);

// Member management routes.
router.post("/conversations/:id/members", addMembers);
router.delete("/conversations/:id/members/:targetId", removeMember);
router.put("/conversations/:id/members/:targetId/role", updateMemberRole);

// Settings and notification routes.
router.put("/conversations/:id/settings", updateSettings);
router.put("/conversations/:id/notifications", updateNotifications);

// Conversation action routes.
router.post("/conversations/:id/leave", leaveConversation);
router.put("/conversations/:id/pin", togglePin);
router.post("/conversations/:id/read", markAsRead);

// Search and shared media routes.
router.get("/conversations/:id/search", searchConversationMessages);
router.get("/conversations/:id/media", getSharedMedia);

export default router;
