import supabase from "../../services/supabase.js";

/**
 * Formats a message object for API response
 * @param {Object} msg - Raw message object from database
 * @param {number} requestingUserId - ID of the user making the request
 * @param {Array} othersLastRead - Array of other users' last read timestamps
 * @returns {Object} Formatted message object
 */
export const formatMessage = (msg, requestingUserId = null, othersLastRead = []) => {
    // Determine read status for messages sent by requesting user
    let status = 0; // sent
    if (msg.user_id === requestingUserId) {
        if (msg.delivered_at) status = 1; // delivered
        // Check if any other user has read it
        const isRead = othersLastRead.some(
            (r) =>
                r.last_read_at &&
                new Date(r.last_read_at) >= new Date(msg.created_at),
        );
        if (isRead) status = 2; // read
    }

    return {
        id: msg.id,
        conversation_id: msg.conversation_id,
        user_id: msg.user_id,
        body: msg.body,
        attachment: msg.attachment,
        attachment_type: msg.attachment_type,
        attachment_name: msg.attachment_name,
        reply_to_message_id: msg.reply_to_message_id,
        delivered_at: msg.delivered_at,
        expires_at: msg.expires_at,
        is_system: msg.is_system || false,
        status,
        is_forwarded: msg.is_forwarded || false,
        created_at: msg.created_at,
        updated_at: msg.updated_at,
        edited_at: msg.edited_at,
        sender_username: msg.users?.username ?? null,
        sender_avatar: msg.users?.avatar ?? null,
    };
};

/**
 * Formats a reply message object
 * @param {Object} replyMessage - Raw reply message from database
 * @returns {Object|null} Formatted reply object or null
 */
export const formatReplyMessage = (replyMessage) => {
    if (!replyMessage) return null;

    return {
        id: replyMessage.id,
        user_id: replyMessage.user_id,
        sender_username: replyMessage.users?.username ?? null,
        body: replyMessage.deleted_at ? null : replyMessage.body,
        attachment_type: replyMessage.deleted_at ? null : replyMessage.attachment_type,
        attachment_name: replyMessage.deleted_at ? null : replyMessage.attachment_name,
        deleted_at: replyMessage.deleted_at,
    };
};

/**
 * Formats a message for sending response
 * @param {Object} message - Message object from database
 * @param {Object|null} replyTo - Formatted reply object
 * @returns {Object} Formatted message for API response
 */
export const formatSendMessageResponse = (message, replyTo = null) => {
    return {
        id: message.id,
        conversation_id: message.conversation_id,
        user_id: message.user_id,
        body: message.body,
        attachment: message.attachment,
        attachment_type: message.attachment_type,
        attachment_name: message.attachment_name,
        reply_to_message_id: message.reply_to_message_id,
        reply_to: replyTo,
        delivered_at: message.delivered_at,
        status: 0, // just sent
        is_forwarded: message.is_forwarded || false,
        created_at: message.created_at,
        updated_at: message.updated_at,
        sender_username: message.users?.username ?? null,
        sender_avatar: message.users?.avatar ?? null,
        reactions: [],
    };
};

/**
 * Formats a pinned message
 * @param {Object} pin - Pinned message object from database
 * @returns {Object|null} Formatted pinned message or null
 */
export const formatPinnedMessage = (pin) => {
    const msg = pin.messages;
    if (!msg) return null;

    return {
        id: msg.id,
        conversation_id: msg.conversation_id,
        user_id: msg.user_id,
        body: msg.body,
        attachment: msg.attachment,
        attachment_type: msg.attachment_type,
        attachment_name: msg.attachment_name,
        delivered_at: msg.delivered_at,
        is_forwarded: msg.is_forwarded || false,
        created_at: msg.created_at,
        updated_at: msg.updated_at,
        edited_at: msg.edited_at,
        sender_username: msg.users?.username ?? null,
        sender_avatar: msg.users?.avatar ?? null,
        pinned_id: pin.id,
    };
};

/**
 * Formats an edited message response
 * @param {Object} message - Edited message from database
 * @returns {Object} Formatted edited message
 */
export const formatEditMessageResponse = (message) => {
    return {
        id: message.id,
        conversation_id: message.conversation_id,
        user_id: message.user_id,
        body: message.body,
        attachment: message.attachment,
        attachment_type: message.attachment_type,
        attachment_name: message.attachment_name,
        delivered_at: message.delivered_at,
        status: 0,
        is_forwarded: message.is_forwarded || false,
        created_at: message.created_at,
        updated_at: message.updated_at,
        edited_at: message.edited_at,
        sender_username: message.users?.username ?? null,
        sender_avatar: message.users?.avatar ?? null,
    };
};

/**
 * Formats conversation object for API response
 * @param {Object} conv - Raw conversation object
 * @param {Object} membershipMap - Map of conversation memberships
 * @param {Object} unreadCounts - Map of unread counts
 * @param {Object|null} previewMsg - Preview message object
 * @returns {Object} Formatted conversation
 */
export const formatConversation = (conv, membershipMap, unreadCounts, previewMsg = null) => {
    const participants = Array.isArray(conv.conversation_user)
        ? conv.conversation_user.map((cu) => cu.users)
        : [];

    const image =
        conv.conversation_settings?.[0]?.image ||
        conv.conversation_settings?.image ||
        null;

    return {
        id: conv.id,
        name: conv.name,
        is_group: conv.is_group,
        image,
        participants,
        messages: previewMsg ? [previewMsg] : [],
        is_pinned: membershipMap[conv.id]?.is_pinned || false,
        unread_count: unreadCounts[conv.id] || 0,
        created_at: conv.created_at,
        updated_at: conv.updated_at,
    };
};

/**
 * Fetches and formats reply message for a given message ID
 * @param {number} replyToMessageId - ID of the message to reply to
 * @returns {Promise<Object|null>} Formatted reply message or null
 */
export const fetchAndFormatReplyMessage = async (replyToMessageId) => {
    if (!replyToMessageId) return null;

    const { data: replyMessage } = await supabase
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
        .eq("id", replyToMessageId)
        .single();

    return formatReplyMessage(replyMessage);
};
