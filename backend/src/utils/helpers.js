/**
 * Centralized helper utilities for the messaging system
 */

/**
 * Maps attachment MIME types to Portuguese display labels
 * @param {string} attachmentType - MIME type of attachment
 * @returns {string} Portuguese label for attachment type
 */
export const getAttachmentLabel = (attachmentType) => {
    if (!attachmentType) return 'ficheiro';
    
    if (attachmentType.startsWith('image/')) return 'imagem';
    if (attachmentType.startsWith('video/')) return 'vídeo';
    if (attachmentType.startsWith('audio/')) return 'áudio';
    
    return 'ficheiro';
};

/**
 * Maps theme ID to Portuguese display name
 * @param {number} themeId - Theme ID from database
 * @returns {string} Portuguese theme name
 */
export const getThemeDisplayName = (themeId) => {
    const themeNames = {
        0: "Padrão",
        1: "Oceano",
        2: "Pôr do Sol",
        3: "Floresta",
        4: "Meia-noite",
        5: "AMOLED",
        6: "Nord",
        7: "Dracula",
        8: "Mocha",
        9: "Rosa",
        10: "Sakura",
        11: "Ambar",
        12: "Artico",
        13: "Lavanda",
        14: "Coral",
        15: "Ardosia",
        16: "Esmeralda",
        17: "Cobre",
        18: "Aguarela",
        19: "Vulcao",
        20: "Nebula",
        21: "Branco Puro",
        22: "Outono",
        23: "Gelo",
        24: "Roxo Escuro",
    };
    return themeNames[themeId] || "Padrão";
};

/**
 * Creates a safe reply object with proper fallbacks
 * @param {Object|null} replyMessage - Raw reply message from database
 * @returns {Object} Safe reply object with consistent structure
 */
export const createSafeReplyObject = (replyMessage) => {
    if (!replyMessage) {
        return {
            id: null,
            user_id: null,
            sender_username: null,
            body: null,
            attachment_type: null,
            attachment_name: null,
            attachment_label: null,
            deleted_at: null,
            is_deleted: true,
            is_missing: true,
            fallback_text: "Mensagem indisponível"
        };
    }

    if (replyMessage.deleted_at) {
        return {
            id: replyMessage.id,
            user_id: replyMessage.user_id,
            sender_username: replyMessage.users?.username ?? null,
            body: null,
            attachment_type: null,
            attachment_name: null,
            attachment_label: null,
            deleted_at: replyMessage.deleted_at,
            is_deleted: true,
            is_missing: false,
            fallback_text: "Mensagem eliminada"
        };
    }

    return {
        id: replyMessage.id,
        user_id: replyMessage.user_id,
        sender_username: replyMessage.users?.username ?? null,
        body: replyMessage.body,
        attachment_type: replyMessage.attachment_type,
        attachment_name: replyMessage.attachment_name,
        attachment_label: replyMessage.attachment_type ? getAttachmentLabel(replyMessage.attachment_type) : null,
        deleted_at: replyMessage.deleted_at,
        is_deleted: false,
        is_missing: false,
        fallback_text: null
    };
};

/**
 * Filters system users from participants list
 * @param {Array} participants - Array of participant objects
 * @returns {Array} Filtered participants without system users
 */
export const filterSystemUsers = (participants) => {
    if (!Array.isArray(participants)) return [];
    
    return participants.filter(participant => {
        const username = participant.username?.toLowerCase();
        // Exclude system users by username (primary method since no is_system flag exists)
        return username !== 'system' && username !== 'sistema';
    });
};
