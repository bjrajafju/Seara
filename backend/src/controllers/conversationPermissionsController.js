import supabase from "../services/supabase.js";
import { validateSendMessagePermissions } from "../utils/messages/messageUtils.js";

/**
 * Checks if a user can send messages in a conversation
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
export const checkSendMessagePermissions = async (req, res) => {
    const { conversationId, userId } = req.params;

    if (!conversationId || !userId) {
        return res.status(400).json({ error: "Conversation ID e User ID são obrigatórios." });
    }

    try {
        // Check if user is a participant in the conversation
        const { data: membership, error: membershipError } = await supabase
            .from("conversation_user")
            .select("role, is_creator, is_archived")
            .eq("conversation_id", conversationId)
            .eq("user_id", userId)
            .single();

        if (membershipError || !membership) {
            return res.json({
                can_send: false,
                reason: "not_participant",
                message: "Não é participante desta conversa."
            });
        }

        if (membership.is_archived) {
            return res.json({
                can_send: false,
                reason: "archived",
                message: "Esta conversa está arquivada."
            });
        }

        try {
            // This will throw an error if user cannot send messages
            await validateSendMessagePermissions(conversationId, userId);
            
            return res.json({
                can_send: true,
                reason: "allowed",
                message: "Pode enviar mensagens."
            });
        } catch (permissionError) {
            return res.json({
                can_send: false,
                reason: "restricted",
                message: permissionError.message || "Sem permissão para enviar mensagens."
            });
        }
    } catch (err) {
        console.error("checkSendMessagePermissions:", err);
        res.status(500).json({ error: "Erro ao verificar permissões." });
    }
};
