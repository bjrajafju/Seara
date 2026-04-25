import supabase from "../services/supabase.js";
import {
    formatMessage,
    formatSendMessageResponse,
    fetchAndFormatReplyMessage,
    formatEditMessageResponse
} from "../utils/messages/messageFormatter.js";
import { createSafeReplyObject } from "../utils/helpers.js";
import {
    fetchOthersLastRead,
    fetchMyLastRead,
    markMessagesAsDelivered
} from "../utils/messages/messageStatus.js";
import {
    DEFAULT_PAGE_SIZE,
    validateReplyMessage,
    calculateExpirationTime,
    validateMessageAge,
    enrichMessagesWithReplyAndReactions,
    updateConversationTimestamp,
    validateSendMessagePermissions
} from "../utils/messages/messageUtils.js";

/// Returns paginated messages for a conversation.
export const getMessages = async (req, res) => {
    const { conversationId } = req.params;
    const limit = parseInt(req.query.limit) || DEFAULT_PAGE_SIZE;
    const before = req.query.before ? parseInt(req.query.before) : null;
    const around = req.query.around ? parseInt(req.query.around) : null;
    const requestingUserId = req.query.userId
        ? parseInt(req.query.userId)
        : null;

    if (!conversationId) {
        return res
            .status(400)
            .json({ error: "Conversation ID é obrigatório." });
    }

    try {
        const now = new Date().toISOString();

        /// Marks pending incoming messages as delivered.
        await markMessagesAsDelivered(conversationId, requestingUserId);

        if (around) {
            /// Get the target message
            const { data: targetMsg, error: targetErr } = await supabase
                .from("messages")
                .select("created_at, id")
                .eq("id", around)
                .eq("conversation_id", conversationId)
                .single();

            if (targetErr || !targetMsg) {
                return res
                    .status(404)
                    .json({ error: "Mensagem não encontrada." });
            }

            const aroundLimit = Math.floor(limit / 2);

            /// Get messages BEFORE the target
            const { data: before_msgs } = await supabase
                .from("messages")
                .select(
                    `
                    id,
                    conversation_id,
                    user_id,
                    body,
                    attachment,
                    attachment_type,
                    attachment_name,
                    reply_to_message_id,
                    delivered_at,
                    expires_at,
                    is_system,
                    created_at,
                    updated_at,
                    edited_at,
                    is_forwarded,
                    users (
                        id,
                        username,
                        avatar
                    )
                `,
                )
                .eq("conversation_id", conversationId)
                .is("deleted_at", null)
                .or(`expires_at.is.null,expires_at.gt.${now}`)
                .lt("created_at", targetMsg.created_at)
                .order("created_at", { ascending: false })
                .limit(aroundLimit);

            /// Get the target message details
            const { data: target_full } = await supabase
                .from("messages")
                .select(
                    `
                    id,
                    conversation_id,
                    user_id,
                    body,
                    attachment,
                    attachment_type,
                    attachment_name,
                    reply_to_message_id,
                    delivered_at,
                    expires_at,
                    is_system,
                    created_at,
                    updated_at,
                    edited_at,
                    is_forwarded,
                    users (
                        id,
                        username,
                        avatar
                    )
                `,
                )
                .eq("id", around)
                .single();

            /// Get messages AFTER the target
            const { data: after_msgs } = await supabase
                .from("messages")
                .select(
                    `
                    id,
                    conversation_id,
                    user_id,
                    body,
                    attachment,
                    attachment_type,
                    attachment_name,
                    reply_to_message_id,
                    delivered_at,
                    expires_at,
                    is_system,
                    created_at,
                    updated_at,
                    edited_at,
                    is_forwarded,
                    users (
                        id,
                        username,
                        avatar
                    )
                `,
                )
                .eq("conversation_id", conversationId)
                .is("deleted_at", null)
                .or(`expires_at.is.null,expires_at.gt.${now}`)
                .gt("created_at", targetMsg.created_at)
                .order("created_at", { ascending: true })
                .limit(aroundLimit + 5);

            const combined = [
                ...(before_msgs || []).reverse(),
                target_full,
                ...(after_msgs || []),
            ];

            let othersLastRead = await fetchOthersLastRead(conversationId, requestingUserId);

            const formatted = combined.map((msg) => formatMessage(msg, requestingUserId, othersLastRead));

            const targetIndex = formatted.findIndex((m) => m.id === around);
            const enrichedAround = await enrichMessagesWithReplyAndReactions(
                formatted,
                requestingUserId,
            );

            let myLastReadAt = await fetchMyLastRead(conversationId, requestingUserId);

            return res.json({
                messages: enrichedAround,
                has_more: false,
                target_index: targetIndex,
                target_message_id: around,
                last_read_at: myLastReadAt,
            });
        }

        let query = supabase
            .from("messages")
            .select(
                `
                id,
                conversation_id,
                user_id,
                body,
                attachment,
                attachment_type,
                attachment_name,
                reply_to_message_id,
                delivered_at,
                expires_at,
                is_system,
                created_at,
                updated_at,
                edited_at,
                is_forwarded,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .eq("conversation_id", conversationId)
            .is("deleted_at", null)
            .or(`expires_at.is.null,expires_at.gt.${now}`)
            .order("created_at", { ascending: false })
            .limit(limit + 1);

        /// Applies cursor pagination to load older messages.
        if (before) {
            /// Get the created_at of the cursor message
            const { data: cursorMsg } = await supabase
                .from("messages")
                .select("created_at")
                .eq("id", before)
                .single();

            if (cursorMsg) {
                query = query.lt("created_at", cursorMsg.created_at);
            }
        }

        const { data: messages, error } = await query;

        if (error) throw error;

        /// Checks whether additional messages are available.
        const hasMore = messages.length > limit;
        const pageMessages = hasMore ? messages.slice(0, limit) : messages;

        /// Get last_read_at for other participants (for read receipts)
        let othersLastRead = await fetchOthersLastRead(conversationId, requestingUserId);

        /// Formats message rows for API response.
        const formatted = pageMessages
            .map((msg) => formatMessage(msg, requestingUserId, othersLastRead))
            .reverse(); /// Reverse so oldest first
        const enrichedMessages = await enrichMessagesWithReplyAndReactions(
            formatted,
            requestingUserId,
        );

        /// Get my last_read_at for unread divider
        let myLastReadAt = await fetchMyLastRead(conversationId, requestingUserId);

        res.json({
            messages: enrichedMessages,
            has_more: hasMore,
            last_read_at: myLastReadAt,
        });
    } catch (err) {
        console.error("getMessages:", err);
        res.status(500).json({ error: "Erro ao buscar mensagens." });
    }
};

/// Sends a message to the conversation.
export const sendMessage = async (req, res) => {
    const { conversationId } = req.params;
    const {
        userId,
        body,
        attachment,
        attachment_type,
        attachment_name,
        is_forwarded,
        reply_to_message_id,
    } = req.body;

    if (!conversationId || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        /// Validates sender permissions before creating the message.
        const settings = await validateSendMessagePermissions(conversationId, userId);

        let safeReplyToMessageId = await validateReplyMessage(reply_to_message_id, conversationId);

        /// Additional validation for forwarded messages to ensure conversation consistency
        if (is_forwarded && req.body.original_conversation_id) {
            const originalConversationId = req.body.original_conversation_id;
            if (String(originalConversationId) !== String(conversationId)) {
                // Reject forwarded messages that don't match the target conversation
                return res.status(400).json({ 
                    error: "Forwarded message conversation mismatch. The message was forwarded from a different conversation." 
                });
            }
        }

        /// Calculates expiration timestamp for ephemeral messages.
        const expiresAt = calculateExpirationTime(settings?.ephemeral_duration || 0);

        /// Insert message
        const { data: message, error } = await supabase
            .from("messages")
            .insert({
                conversation_id: parseInt(conversationId),
                user_id: userId,
                body: body ?? "",
                attachment: attachment ?? null,
                attachment_type: attachment_type ?? null,
                attachment_name: attachment_name ?? null,
                reply_to_message_id: safeReplyToMessageId,
                expires_at: expiresAt,
                is_forwarded: is_forwarded || false,
            })
            .select(
                `
                id,
                conversation_id,
                user_id,
                body,
                attachment,
                attachment_type,
                attachment_name,
                reply_to_message_id,
                delivered_at,
                expires_at,
                created_at,
                updated_at,
                is_forwarded,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .single();

        if (error) throw error;

        // Build proper reply object using the same logic as enrichMessagesWithReplyAndReactions
        let replyTo = null;
        if (message.reply_to_message_id) {
            try {
                const { data: replyMessage, error: replyError } = await supabase
                    .from("messages")
                    .select(`
                        id,
                        user_id,
                        body,
                        attachment_type,
                        attachment_name,
                        deleted_at,
                        users (
                            username
                        )
                    `)
                    .eq("id", message.reply_to_message_id)
                    .single();
                
                if (replyError) {
                    console.error("Error fetching reply message:", replyError);
                    // If there's an error fetching the reply message, create a missing reply object
                    replyTo = createSafeReplyObject(null);
                } else {
                    replyTo = createSafeReplyObject(replyMessage);
                }
            } catch (err) {
                console.error("Exception fetching reply message:", err);
                replyTo = createSafeReplyObject(null);
            }
        }

        /// Touches conversation timestamp after sending a message.
        await updateConversationTimestamp(conversationId);

        res.status(201).json(formatSendMessageResponse(message, replyTo));
    } catch (err) {
        console.error("sendMessage:", err);
        
        // Check if this is a permission error
        if (err.message && (
            err.message.includes("Apenas admins podem enviar mensagens") ||
            err.message.includes("Ninguém pode enviar mensagens") ||
            err.message.includes("não pode enviar mensagens") ||
            err.message.includes("permission") ||
            err.message.includes("authorized")
        )) {
            return res.status(403).json({ 
                error: "You are not allowed to send messages in this conversation" 
            });
        }
        
        res.status(500).json({ error: "Erro ao enviar mensagem." });
    }
};

/// Updates an editable message body.
export const editMessage = async (req, res) => {
    const { conversationId, messageId } = req.params;
    const { body } = req.body;

    if (!messageId || !body) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const { data: targetMsg, error: fetchErr } = await supabase
            .from("messages")
            .select("created_at")
            .eq("id", messageId)
            .single();

        if (fetchErr || !targetMsg)
            return res.status(404).json({ error: "Mensagem não encontrada." });

        if (!validateMessageAge(targetMsg.created_at)) {
            return res
                .status(403)
                .json({
                    error: "Apenas pode editar mensagens enviadas nas últimas 24 horas.",
                });
        }

        const { data: message, error } = await supabase
            .from("messages")
            .update({
                body,
                updated_at: new Date().toISOString(),
                edited_at: new Date().toISOString(),
            })
            .eq("id", messageId)
            .eq("conversation_id", conversationId)
            .select(
                `
                id,
                conversation_id,
                user_id,
                body,
                attachment,
                attachment_type,
                attachment_name,
                delivered_at,
                expires_at,
                created_at,
                updated_at,
                edited_at,
                deleted_at,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .single();

        if (error) throw error;

        res.json(formatEditMessageResponse(message));
    } catch (err) {
        console.error("editMessage:", err);
        res.status(500).json({ error: "Erro ao editar mensagem." });
    }
};

/// Soft-deletes a message in this conversation.
export const deleteMessage = async (req, res) => {
    const { conversationId, messageId } = req.params;

    if (!messageId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const { data: targetMsg, error: fetchErr } = await supabase
            .from("messages")
            .select("created_at")
            .eq("id", messageId)
            .single();

        if (fetchErr || !targetMsg)
            return res.status(404).json({ error: "Mensagem não encontrada." });

        if (!validateMessageAge(targetMsg.created_at)) {
            return res
                .status(403)
                .json({
                    error: "Apenas pode eliminar mensagens enviadas nas últimas 24 horas.",
                });
        }

        /// Marks message as deleted without removing the record.
        const { error } = await supabase
            .from("messages")
            .update({ deleted_at: new Date().toISOString() })
            .eq("id", messageId)
            .eq("conversation_id", conversationId);

        if (error) throw error;

        res.status(204).send();
    } catch (err) {
        console.error("deleteMessage:", err);
        res.status(500).json({ error: "Erro ao eliminar mensagem." });
    }
};
