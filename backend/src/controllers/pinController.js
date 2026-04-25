import supabase from "../services/supabase.js";
import { formatPinnedMessage } from "../utils/messages/messageFormatter.js";

/// Returns pinned messages for a conversation.
export const getPinnedMessages = async (req, res) => {
    const { conversationId } = req.params;
    const { limit, cursor } = req.query;

    if (!conversationId) {
        return res.status(400).json({ error: "Conversation ID obrigatório." });
    }

    try {
        // Apply limit with default
        const pageLimit = parseInt(limit) || 50;
        
        let query = supabase
            .from("pinned_messages")
            .select(
                `
                id,
                message_id,
                created_at,
                messages (
                    id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, delivered_at, expires_at, created_at, updated_at, edited_at, is_forwarded,
                    users ( id, username, avatar )
                )
            `,
            )
            .eq("conversation_id", conversationId)
            .order("created_at", { ascending: true });

        // Apply cursor pagination
        if (cursor) {
            query = query.gt("created_at", cursor);
        }

        query = query.limit(pageLimit + 1); // +1 to check if there are more

        const { data: pins, error } = await query;

        if (error) throw error;

        const formatted = pins
            .map((pin) => formatPinnedMessage(pin))
            .filter((m) => m !== null);

        // Check if there are more results
        const hasMore = pins.length > pageLimit;
        const pageResults = hasMore ? formatted.slice(0, pageLimit) : formatted;
        
        // Get next cursor (timestamp of last item)
        let nextCursor = null;
        if (hasMore && pageResults.length > 0) {
            nextCursor = pins[pageLimit - 1].created_at;
        }

        res.json({
            messages: pageResults,
            has_more: hasMore,
            next_cursor: nextCursor,
        });
    } catch (err) {
        console.error("getPinnedMessages error:", err);
        res.status(500).json({ error: "Erro ao buscar mensagens fixadas." });
    }
};

/// Pins or unpins a message.
export const toggleMessagePin = async (req, res) => {
    const { conversationId, messageId } = req.params;
    const authId = req.user.id; /// From authMiddleware (UUID)

    if (!conversationId || !messageId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        /// Resolves internal user id from authenticated auth id.
        const { data: userRecord } = await supabase
            .from("users")
            .select("id")
            .eq("auth_id", authId)
            .single();

        if (!userRecord) {
            return res
                .status(401)
                .json({ error: "Utilizador interno não encontrado." });
        }
        const userId = userRecord.id;

        /// Verifies message ownership for this conversation.
        const { data: msg } = await supabase
            .from("messages")
            .select("id")
            .eq("id", messageId)
            .eq("conversation_id", conversationId)
            .single();

        if (!msg) {
            return res.status(404).json({ error: "Mensagem não encontrada." });
        }

        /// Checks current pin state before toggling.
        const { data: existingPin } = await supabase
            .from("pinned_messages")
            .select("id")
            .eq("conversation_id", conversationId)
            .eq("message_id", messageId)
            .single();

        if (existingPin) {
            /// Removes the message from pinned list.
            const { error: deleteErr } = await supabase
                .from("pinned_messages")
                .delete()
                .eq("id", existingPin.id);

            if (deleteErr) throw deleteErr;
            return res
                .status(200)
                .json({ status: "unpinned", message_id: messageId });
        } else {
            /// Adds the message to pinned list.
            const { error: insertErr } = await supabase
                .from("pinned_messages")
                .insert({
                    conversation_id: conversationId,
                    message_id: messageId,
                    pinned_by: userId,
                });

            if (insertErr) throw insertErr;
            return res
                .status(200)
                .json({ status: "pinned", message_id: messageId });
        }
    } catch (err) {
        console.error("toggleMessagePin error:", err);
        res.status(500).json({
            error: "Erro ao alternar fixação da mensagem.",
        });
    }
};
