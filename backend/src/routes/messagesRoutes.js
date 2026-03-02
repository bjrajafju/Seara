import express from "express";
import {
    listConversations,
    createConversation,
} from "../controllers/messagesController.js";

const router = express.Router();

router.get("/conversations/:userId", listConversations);
router.post("/conversations", createConversation);

export default router;
