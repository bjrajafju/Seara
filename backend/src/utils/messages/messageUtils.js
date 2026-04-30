import supabase from "../../services/supabase.js";
import { createSafeReplyObject } from "../helpers.js";

/// Maps ephemeral mode to expiration duration in milliseconds.
export const EPHEMERAL_MS = {
    0: 0,
    1: 24 * 60 * 60 * 1000,
    2: 7 * 24 * 60 * 60 * 1000,
    3: 30 * 24 * 60 * 60 * 1000,
};

/// Default page size for message pagination
export const DEFAULT_PAGE_SIZE = 30;

/**
 * Validates reply message and returns safe reply ID
 * @param {number} replyToMessageId - ID of the message to reply to
 * @param {string} conversationId - Current conversation ID
 * @returns {Promise<number|null>} Safe reply message ID or null
 */
export const validateReplyMessage = async (replyToMessageId, conversationId) => {
    if (!replyToMessageId) return null;

    const { data: replyTarget, error: replyErr } = await supabase
        .from("messages")
        .select("id, conversation_id")
        .eq("id", replyToMessageId)
        .single();

    if (replyErr || !replyTarget) {
        throw new Error("Mensagem de resposta inválida.");
    }
    if (Number(replyTarget.conversation_id) !== Number(conversationId)) {
        throw new Error("A resposta deve apontar para a mesma conversa.");
    }
    return replyTarget.id;
};

/**
 * Calculates expiration timestamp for ephemeral messages
 * @param {number} ephemeralDuration - Ephemeral duration mode
 * @returns {string|null} ISO timestamp or null
 */
export const calculateExpirationTime = (ephemeralDuration) => {
    if (ephemeralDuration <= 0) return null;

    const durationMs = EPHEMERAL_MS[ephemeralDuration] || 0;
    if (durationMs > 0) {
        return new Date(Date.now() + durationMs).toISOString();
    }
    return null;
};

/**
 * Validates message age for edit/delete operations
 * @param {string} createdAt - Message creation timestamp
 * @param {number} maxAgeHours - Maximum age in hours (default: 24)
 * @returns {boolean} True if message can be edited/deleted
 */
export const validateMessageAge = (createdAt, maxAgeHours = 24) => {
    const ageHours = (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60);
    return ageHours < maxAgeHours;
};

/**
 * Enriches messages with reply and reaction data
 * @param {Array} messages - Array of message objects
 * @param {number} requestingUserId - ID of the user making the request
 * @returns {Promise<Array>} Messages enriched with replies and reactions
 */
export const enrichMessagesWithReplyAndReactions = async (messages, requestingUserId) => {
    if (!messages || messages.length === 0) return messages;

    const messageIds = messages.map((m) => m.id);
    const replyIds = [
        ...new Set(messages.map((m) => m.reply_to_message_id).filter(Boolean)),
    ];

    let replyMap = new Map();
    if (replyIds.length > 0) {
        const { data: replyMessages } = await supabase
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
            .in("id", replyIds);

        replyMap = new Map(
            (replyMessages || []).map((msg) => [
                msg.id,
                createSafeReplyObject(msg),
            ]),
        );
    }

    const reactionsByMessage = new Map();
    const { data: reactionRows } = await supabase
        .from("message_reactions")
        .select("message_id, reaction, user_id")
        .in("message_id", messageIds);

    for (const row of reactionRows || []) {
        const messageReactionMap =
            reactionsByMessage.get(row.message_id) || new Map();
        const entry = messageReactionMap.get(row.reaction) || {
            reaction: row.reaction,
            count: 0,
            reacted_by_me: false,
        };
        entry.count += 1;
        if (requestingUserId && row.user_id === requestingUserId) {
            entry.reacted_by_me = true;
        }
        messageReactionMap.set(row.reaction, entry);
        reactionsByMessage.set(row.message_id, messageReactionMap);
    }

    return messages.map((msg) => {
        return {
            ...msg,
            reply_to: msg.reply_to_message_id
                ? replyMap.get(msg.reply_to_message_id) || createSafeReplyObject(null)
                : null,
            reactions: Array.from(
                (reactionsByMessage.get(msg.id) || new Map()).values(),
            ),
        };
    });
};

/**
 * Builds message query with filters for search and file types
 * @param {Object} supabase - Supabase client instance
 * @param {string} conversationId - Conversation ID
 * @param {Object} filters - Filter options
 * @returns {Object} Supabase query object
 */
export const buildMessageQuery = (supabase, conversationId, filters = {}) => {
    const {
        searchQ,
        isNameSearchOnly,
        metadataMatched,
        fileType,
        before,
        limit,
        around,
        now
    } = filters;

    let query = supabase
        .from("messages")
        .select(`
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
        `)
        .eq("conversation_id", conversationId)
        .is("deleted_at", null);

    if (now) {
        query = query.or(`expires_at.is.null,expires_at.gt.${now}`);
    }

    let requiresSpecializedQuery = false;

    if (fileType === "images") {
        query = query.ilike("attachment_type", "image/%");
        requiresSpecializedQuery = true;
    } else if (fileType === "videos") {
        query = query.ilike("attachment_type", "video/%");
        requiresSpecializedQuery = true;
    } else if (fileType === "documents") {
        query = query
            .not("attachment_type", "is", null)
            .not("attachment_type", "ilike", "image/%")
            .not("attachment_type", "ilike", "video/%");
        requiresSpecializedQuery = true;
    }

    let textMatchRequiredAtQueryLevel = false;

    if (
        searchQ &&
        !isNameSearchOnly &&
        !metadataMatched &&
        !fileType
    ) {
        query = query.ilike("body", `%${searchQ}%`);
        requiresSpecializedQuery = true;
        textMatchRequiredAtQueryLevel = true;
    } else if (searchQ && !isNameSearchOnly && fileType) {
        if (!metadataMatched) {
            query = query.ilike("body", `%${searchQ}%`);
            textMatchRequiredAtQueryLevel = true;
        }
    }

    if (around) {
        // Handle around pagination separately
        return { query, requiresSpecializedQuery, textMatchRequiredAtQueryLevel };
    }

    query = query.order("created_at", { ascending: false });

    if (limit) {
        query = query.limit(limit + 1); // +1 to check if there are more
    }

    if (before) {
        // Apply cursor pagination
        return { query, requiresSpecializedQuery, textMatchRequiredAtQueryLevel, needsCursor: true };
    }

    return { query, requiresSpecializedQuery, textMatchRequiredAtQueryLevel };
};

/**
 * Updates conversation timestamp
 * @param {string} conversationId - Conversation ID
 * @returns {Promise<void>}
 */
export const updateConversationTimestamp = async (conversationId) => {
    await supabase
        .from("conversations")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", conversationId);
};

/**
 * Validates user permissions for sending messages
 * @param {string} conversationId - Conversation ID
 * @param {number} userId - User ID
 * @returns {Promise<void>} Throws error if not authorized
 */
export const validateSendMessagePermissions = async (conversationId, userId) => {
    const { data: settings } = await supabase
        .from("conversation_settings")
        .select("who_can_send_messages, ephemeral_duration")
        .eq("conversation_id", conversationId)
        .single();

    if (settings) {
        if (settings.who_can_send_messages === 1) {
            // Restricts sending to admins when announcement mode is enabled
            const { data: membership } = await supabase
                .from("conversation_user")
                .select("role, is_creator")
                .eq("conversation_id", conversationId)
                .eq("user_id", userId)
                .single();

            if (!membership || (membership.role !== 1 && !membership.is_creator)) {
                throw new Error("Apenas admins podem enviar mensagens nesta conversa.");
            }
        } else if (settings.who_can_send_messages === 2) {
            // Nobody can send messages
            throw new Error("Ninguém pode enviar mensagens nesta conversa.");
        }
    }

    return settings;
};
