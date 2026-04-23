import supabase from "../../services/supabase.js";

/**
 * Calculates message read status based on other users' read timestamps
 * @param {Object} msg - Message object
 * @param {number} requestingUserId - ID of the user making the request
 * @param {Array} othersLastRead - Array of other users' last read timestamps
 * @returns {number} Status code (0=sent, 1=delivered, 2=read)
 */
export const calculateMessageStatus = (msg, requestingUserId = null, othersLastRead = []) => {
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
    return status;
};

/**
 * Fetches last read timestamps for other users in a conversation
 * @param {string} conversationId - Conversation ID
 * @param {number} requestingUserId - ID of the user making the request
 * @returns {Promise<Array>} Array of other users' last read timestamps
 */
export const fetchOthersLastRead = async (conversationId, requestingUserId) => {
    if (!requestingUserId) return [];

    const { data: otherReads } = await supabase
        .from("conversation_user")
        .select("user_id, last_read_at")
        .eq("conversation_id", conversationId)
        .neq("user_id", requestingUserId);

    return otherReads || [];
};

/**
 * Fetches the requesting user's last read timestamp
 * @param {string} conversationId - Conversation ID
 * @param {number} requestingUserId - ID of the user making the request
 * @returns {Promise<string|null>} Last read timestamp or null
 */
export const fetchMyLastRead = async (conversationId, requestingUserId) => {
    if (!requestingUserId) return null;

    const { data: myMembership } = await supabase
        .from("conversation_user")
        .select("last_read_at")
        .eq("conversation_id", conversationId)
        .eq("user_id", requestingUserId)
        .single();

    return myMembership?.last_read_at || null;
};

/**
 * Marks pending incoming messages as delivered
 * @param {string} conversationId - Conversation ID
 * @param {number} requestingUserId - ID of the user making the request
 * @returns {Promise<void>}
 */
export const markMessagesAsDelivered = async (conversationId, requestingUserId) => {
    if (!requestingUserId) return;

    const now = new Date().toISOString();
    await supabase
        .from("messages")
        .update({ delivered_at: now })
        .eq("conversation_id", conversationId)
        .neq("user_id", requestingUserId)
        .is("delivered_at", null);
};

/**
 * Calculates unread count for a conversation
 * @param {string} conversationId - Conversation ID
 * @param {number} userId - User ID
 * @param {string} lastReadAt - User's last read timestamp
 * @returns {Promise<number>} Unread message count
 */
export const calculateUnreadCount = async (conversationId, userId, lastReadAt) => {
    const { count } = await supabase
        .from("messages")
        .select("id", { count: "exact", head: true })
        .eq("conversation_id", conversationId)
        .is("deleted_at", null)
        .neq("user_id", userId)
        .gt("created_at", lastReadAt || "1970-01-01T00:00:00Z");

    return count || 0;
};
