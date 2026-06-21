import supabase from "../services/supabase.js";
import { formatConversation } from "../utils/messages/messageFormatter.js";
import { calculateUnreadCount } from "../utils/messages/messageStatus.js";
import { filterSystemUsers } from "../utils/helpers.js";

/// All this é so para debug mas vou deixar aqui até ao fim porque pode ser útil depois
export const listConversationsSimple = async (req, res) => {
    const { userId } = req.params;

    if (!userId) {
        return res.status(400).json({ error: "User ID é obrigatório." });
    }

    try {
        console.log(`[SIMPLE] listConversations called for userId: ${userId}`);

        // Get user conversations
        let userConvQuery = supabase
            .from("conversation_user")
            .select("conversation_id, is_pinned, last_read_at")
            .eq("user_id", userId)
            .eq("is_archived", false);

        const { data: userConversations, error: convError } = await userConvQuery;
        if (convError) throw convError;

        console.log(`[SIMPLE] userConversations found:`, userConversations?.length || 0);

        if (!userConversations || userConversations.length === 0) {
            console.log(`[SIMPLE] No user conversations found`);
            return res.json([]);
        }

        // Get conversation details
        const conversationIds = userConversations.map((c) => c.conversation_id);
        console.log(`[SIMPLE] Conversation IDs:`, conversationIds);

        const { data: conversations, error: convDetailsError } = await supabase
            .from("conversations")
            .select(`
                id,
                name,
                is_group,
                created_at,
                updated_at,
                conversation_user (
                    users (
                        id,
                        username,
                        name,
                        avatar
                    )
                ),
                conversation_settings (
                    image
                )
            `)
            .in("id", conversationIds);

        if (convDetailsError) throw convDetailsError;

        console.log(`[SIMPLE] Conversations found:`, conversations?.length || 0);

        if (!conversations || conversations.length === 0) {
            console.log(`[SIMPLE] No conversations found`);
            return res.json([]);
        }

        // Format and return
        const membershipMap = {};
        for (const uc of userConversations) {
            membershipMap[uc.conversation_id] = uc;
        }

        const formattedConversations = conversations.map(conv => {
            const participants = Array.isArray(conv.conversation_user)
                ? filterSystemUsers(conv.conversation_user.map((cu) => cu.users))
                : [];

            return {
                id: conv.id,
                name: conv.name,
                is_group: conv.is_group,
                image: conv.conversation_settings?.[0]?.image || conv.conversation_settings?.image || null,
                participants,
                messages: [], // No preview messages in simple version
                is_pinned: membershipMap[conv.id]?.is_pinned || false,
                unread_count: 0, // No unread count in simple version
                created_at: conv.created_at,
                updated_at: conv.updated_at,
            };
        });

        console.log(`[SIMPLE] Returning ${formattedConversations.length} conversations`);
        res.json(formattedConversations);

    } catch (err) {
        console.error("[SIMPLE] listConversations error:", err);
        res.status(500).json({ error: "Erro ao listar conversas." });
    }
};
