import express from "express";
import { authenticate } from "../middleware/authMiddleware.js";
import {
    getTodayQuestion,
    answerDailyQuestion,
    getStreak
} from "../controllers/dailyQuestionController.js";

const router = express.Router();

/**
 * @route GET /daily-question/today
 * @desc Retorna a pergunta do dia atual
 * @access Private
 */
router.get("/today", authenticate, getTodayQuestion);

/**
 * @route POST /daily-question/answer
 * @desc Submete uma resposta para a pergunta do dia
 * @access Private
 */
router.post("/answer", authenticate, answerDailyQuestion);

/**
 * @route GET /daily-question/streak
 * @desc Retorna o streak atual do utilizador
 * @access Private
 */
router.get("/streak", authenticate, getStreak);

export default router;
