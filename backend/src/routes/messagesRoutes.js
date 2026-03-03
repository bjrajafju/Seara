import express from "express";
import {
    listConversations,
    createConversation,
    getMessages,
    sendMessage,
} from "../controllers/messagesController.js";

const router = express.Router();

router.get("/conversations/:userId", listConversations);
router.post("/conversations", createConversation);
router.get("/conversations/:conversationId/messages", getMessages);
router.post("/conversations/:conversationId/messages", sendMessage);

export default router;
