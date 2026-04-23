import supabase from "../services/supabase.js";
import { formatConversation } from "../utils/messages/messageFormatter.js";
import { calculateUnreadCount } from "../utils/messages/messageStatus.js";

/// Lists conversations visible to the requesting user.
export const listConversations = async (req, res) => {
    const { userId } = req.params;
    const {
        q,
        type, /// 'group', 'direct'
        is_pinned, /// 'true'
        unread, /// 'true'
        file_type, /// 'image', 'video', 'audio', 'document'
        date_from,
        date_to,
        only_usernames, /// 'true'
    } = req.query;

    if (!userId) {
        return res.status(400).json({ error: "User ID é obrigatório." });
    }

    try {
        let userConvQuery = supabase
            .from("conversation_user")
            .select("conversation_id, is_pinned, last_read_at")
            .eq("user_id", userId)
            .eq("is_archived", false); /// Never show archived conversations

        if (is_pinned === "true") {
            userConvQuery = userConvQuery.eq("is_pinned", true);
        }

        const { data: userConversations, error: convError } =
            await userConvQuery;
        if (convError) throw convError;

        if (!userConversations || userConversations.length === 0) {
            return res.json([]);
        }

        const conversationIds = userConversations.map((c) => c.conversation_id);
        const membershipMap = {};
        for (const uc of userConversations) {
            membershipMap[uc.conversation_id] = uc;
        }

        let dbQuery = supabase
            .from("conversations")
            .select(
                `
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
            `,
            )
            .in("id", conversationIds);

        if (type === "group") dbQuery = dbQuery.eq("is_group", true);
        if (type === "direct") dbQuery = dbQuery.eq("is_group", false);
        if (date_from) dbQuery = dbQuery.gte("updated_at", date_from);
        if (date_to) {
            const endOfDay = new Date(
                new Date(date_to).setHours(23, 59, 59, 999),
            ).toISOString();
            dbQuery = dbQuery.lte("updated_at", endOfDay);
        }

        let { data: conversations, error } = await dbQuery;
        if (error) throw error;
        if (!conversations || conversations.length === 0) return res.json([]);

        /// Computes unread counts in parallel for each conversation.
        const unreadCounts = {};
        await Promise.all(
            userConversations.map(async (uc) => {
                unreadCounts[uc.conversation_id] = await calculateUnreadCount(
                    uc.conversation_id,
                    userId,
                    uc.last_read_at
                );
            }),
        );

        if (unread === "true") {
            conversations = conversations.filter((c) => unreadCounts[c.id] > 0);
            if (conversations.length === 0) return res.json([]);
        }

        const searchQ = (q || "").trim().toLowerCase();
        const isNameSearchOnly = only_usernames === "true";

        const finalResult = [];

        await Promise.all(
            conversations.map(async (conv) => {
                const participants = Array.isArray(conv.conversation_user)
                    ? conv.conversation_user.map((cu) => cu.users)
                    : [];

                let metadataMatched = false;

                if (searchQ) {
                    if (
                        !isNameSearchOnly &&
                        conv.name &&
                        conv.name.toLowerCase().includes(searchQ)
                    ) {
                        metadataMatched = true;
                    }
                    for (const p of participants) {
                        if (
                            (p.username &&
                                p.username.toLowerCase().includes(searchQ)) ||
                            (p.name && p.name.toLowerCase().includes(searchQ))
                        ) {
                            metadataMatched = true;
                            break;
                        }
                    }
                }

                const needsQMatch = searchQ.length > 0;

                if (isNameSearchOnly && needsQMatch && !metadataMatched) {
                    return; /// drop
                }

                /// Builds message query filters for search matching.
                let msgQuery = supabase
                    .from("messages")
                    .select(
                        `
                id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, created_at, updated_at, edited_at, is_forwarded
            `,
                    )
                    .eq("conversation_id", conv.id)
                    .is("deleted_at", null)
                    .order("created_at", { ascending: false });

                let requiresSpecializedQuery = false;

                if (file_type === "images") {
                    msgQuery = msgQuery.ilike("attachment_type", "image/%");
                    requiresSpecializedQuery = true;
                } else if (file_type === "videos") {
                    msgQuery = msgQuery.ilike("attachment_type", "video/%");
                    requiresSpecializedQuery = true;
                } else if (file_type === "documents") {
                    msgQuery = msgQuery
                        .not("attachment_type", "is", null)
                        .not("attachment_type", "ilike", "image/%")
                        .not("attachment_type", "ilike", "video/%");
                    requiresSpecializedQuery = true;
                }

                let textMatchRequiredAtQueryLevel = false;

                if (
                    needsQMatch &&
                    !isNameSearchOnly &&
                    !metadataMatched &&
                    !file_type
                ) {
                    msgQuery = msgQuery.ilike("body", `%${searchQ}%`);
                    requiresSpecializedQuery = true;
                    textMatchRequiredAtQueryLevel = true;
                } else if (needsQMatch && !isNameSearchOnly && file_type) {
                    if (!metadataMatched) {
                        msgQuery = msgQuery.ilike("body", `%${searchQ}%`);
                        textMatchRequiredAtQueryLevel = true;
                    }
                }

                let previewMsg = null;

                if (requiresSpecializedQuery) {
                    const { data: matchedData } = await msgQuery.limit(1);
                    previewMsg =
                        matchedData && matchedData.length > 0
                            ? matchedData[0]
                            : null;

                    if (!previewMsg && textMatchRequiredAtQueryLevel) return; /// Drop
                    if (file_type && !previewMsg) return; /// Drop
                }

                /// If we didn't require a specialized query or we got a match on metadata but still need a preview message fallback:
                if (!previewMsg) {
                    const { data: latestRaw } = await supabase
                        .from("messages")
                        .select(
                            `
                    id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, created_at, updated_at, edited_at
                `,
                        )
                        .eq("conversation_id", conv.id)
                        .is("deleted_at", null)
                        .order("created_at", { ascending: false })
                        .limit(1);
                    previewMsg =
                        latestRaw && latestRaw.length > 0 ? latestRaw[0] : null;
                }

                finalResult.push(formatConversation(conv, membershipMap, unreadCounts, previewMsg));
            }),
        );

        finalResult.sort((a, b) => {
            if (a.is_pinned && !b.is_pinned) return -1;
            if (!a.is_pinned && b.is_pinned) return 1;
            return new Date(b.updated_at) - new Date(a.updated_at);
        });

        res.json(finalResult);
    } catch (err) {
        console.error("listConversations:", err);
        res.status(500).json({ error: "Erro ao listar conversas." });
    }
};

/// Creates a direct or group conversation.
export const createConversation = async (req, res) => {
    const { creatorId, participantIds, name } = req.body;

    if (!creatorId || !participantIds || participantIds.length === 0) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const allParticipants = [...new Set([creatorId, ...participantIds])];
        const isGroup = allParticipants.length > 2;

        /// Handles direct message conversation behavior.
        if (!isGroup) {
            const { data: conversations, error } = await supabase
                .from("conversations")
                .select(
                    `
                    id,
                    conversation_user ( user_id, is_archived )
                `,
                )
                .eq("is_group", false);

            if (error) throw error;

            const existingConversation = conversations.find((conv) => {
                const ids = conv.conversation_user.map((u) => u.user_id).sort();
                return (
                    JSON.stringify(ids) ===
                    JSON.stringify([...allParticipants].sort())
                );
            });

            if (existingConversation) {
                /// Unarchive if archived
                const archivedEntries =
                    existingConversation.conversation_user.filter(
                        (u) => u.is_archived,
                    );
                if (archivedEntries.length > 0) {
                    await supabase
                        .from("conversation_user")
                        .update({ is_archived: false })
                        .eq("conversation_id", existingConversation.id);
                }

                /// Return full conversation
                const { data: fullConversation, error: fullError } =
                    await supabase
                        .from("conversations")
                        .select(
                            `
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
                            messages (
                                id,
                                conversation_id,
                                user_id,
                                body,
                                attachment,
                                attachment_type,
                                attachment_name,
                                created_at,
                                updated_at
                            )
                        `,
                        )
                        .eq("id", existingConversation.id)
                        .single();

                if (fullError) throw fullError;

                return res.json({
                    id: fullConversation.id,
                    name: fullConversation.name,
                    is_group: fullConversation.is_group,
                    participants: fullConversation.conversation_user.map(
                        (cu) => cu.users,
                    ),
                    messages: fullConversation.messages ?? [],
                    created_at: fullConversation.created_at,
                    updated_at: fullConversation.updated_at,
                });
            }
        }

        /// Creates the conversation record.
        const { data: newConversation, error } = await supabase
            .from("conversations")
            .insert({
                name: isGroup ? name : null,
                is_group: isGroup,
            })
            .select()
            .single();

        if (error) throw error;

        /// Inserts participants with default or admin roles.
        const inserts = allParticipants.map((uid) => ({
            conversation_id: newConversation.id,
            user_id: uid,
            role: uid === creatorId ? 1 : 0, /// creator = admin
            is_creator: uid === creatorId,
        }));

        const { error: insertError } = await supabase
            .from("conversation_user")
            .insert(inserts);

        if (insertError) throw insertError;

        /// Creates default settings for new conversations.
        const { error: settingsError } = await supabase
            .from("conversation_settings")
            .insert({ conversation_id: newConversation.id });

        if (settingsError) throw settingsError;

        /// Returns the formatted conversation payload.
        const { data: fullConversation } = await supabase
            .from("conversations")
            .select(
                `
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
                )
            `,
            )
            .eq("id", newConversation.id)
            .single();

        return res.status(201).json({
            ...fullConversation,
            participants: fullConversation.conversation_user.map(
                (cu) => cu.users,
            ),
            messages: [],
        });
    } catch (err) {
        console.error("createConversation:", err);
        res.status(500).json({ error: "Erro ao criar conversa." });
    }
};
