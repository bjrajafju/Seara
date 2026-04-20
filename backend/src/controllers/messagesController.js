import supabase from "../services/supabase.js";
import axios from "axios";
import * as cheerio from "cheerio";

// Shared constants used by message handlers.
const DEFAULT_PAGE_SIZE = 30;

// Maps ephemeral mode to expiration duration in milliseconds.
const EPHEMERAL_MS = {
    0: 0,
    1: 24 * 60 * 60 * 1000,
    2: 7 * 24 * 60 * 60 * 1000,
    3: 30 * 24 * 60 * 60 * 1000,
};

const enrichMessagesWithReplyAndReactions = async (messages, requestingUserId) => {
    if (!messages || messages.length === 0) return messages;

    const messageIds = messages.map((m) => m.id);
    const replyIds = [...new Set(messages.map((m) => m.reply_to_message_id).filter(Boolean))];

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
                {
                    id: msg.id,
                    user_id: msg.user_id,
                    sender_username: msg.users?.username ?? null,
                    body: msg.deleted_at ? null : msg.body,
                    attachment_type: msg.deleted_at ? null : msg.attachment_type,
                    attachment_name: msg.deleted_at ? null : msg.attachment_name,
                    deleted_at: msg.deleted_at,
                },
            ]),
        );
    }

    const reactionsByMessage = new Map();
    const { data: reactionRows } = await supabase
        .from("message_reactions")
        .select("message_id, reaction, user_id")
        .in("message_id", messageIds);

    for (const row of reactionRows || []) {
        const messageReactionMap = reactionsByMessage.get(row.message_id) || new Map();
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

    return messages.map((msg) => ({
        ...msg,
        reply_to: msg.reply_to_message_id ? (replyMap.get(msg.reply_to_message_id) || null) : null,
        reactions: Array.from((reactionsByMessage.get(msg.id) || new Map()).values()),
    }));
};

// Lists conversations visible to the requesting user.
export const listConversations = async (req, res) => {
    const { userId } = req.params;
    const {
        q,
        type,           // 'group', 'direct'
        is_pinned,      // 'true'
        unread,         // 'true'
        file_type,      // 'image', 'video', 'audio', 'document'
        date_from,
        date_to,
        only_usernames  // 'true'
    } = req.query;

    if (!userId) {
        return res.status(400).json({ error: "User ID é obrigatório." });
    }

    try {
        let userConvQuery = supabase
            .from("conversation_user")
            .select("conversation_id, is_pinned, last_read_at")
            .eq("user_id", userId)
            .eq("is_archived", false); // Never show archived conversations
            
        if (is_pinned === 'true') {
            userConvQuery = userConvQuery.eq("is_pinned", true);
        }

        const { data: userConversations, error: convError } = await userConvQuery;
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

        if (type === 'group') dbQuery = dbQuery.eq("is_group", true);
        if (type === 'direct') dbQuery = dbQuery.eq("is_group", false);
        if (date_from) dbQuery = dbQuery.gte("updated_at", date_from);
        if (date_to) {
            const endOfDay = new Date(new Date(date_to).setHours(23,59,59,999)).toISOString();
            dbQuery = dbQuery.lte("updated_at", endOfDay);
        }

        let { data: conversations, error } = await dbQuery;
        if (error) throw error;
        if (!conversations || conversations.length === 0) return res.json([]);

        // Computes unread counts in parallel for each conversation.
        const unreadCounts = {};
        await Promise.all(userConversations.map(async (uc) => {
            const { count } = await supabase
                .from("messages")
                .select("id", { count: "exact", head: true })
                .eq("conversation_id", uc.conversation_id)
                .is("deleted_at", null)
                .neq("user_id", userId)
                .gt("created_at", uc.last_read_at || "1970-01-01T00:00:00Z");
            unreadCounts[uc.conversation_id] = count || 0;
        }));

        if (unread === 'true') {
            conversations = conversations.filter(c => unreadCounts[c.id] > 0);
            if (conversations.length === 0) return res.json([]);
        }

        const searchQ = (q || '').trim().toLowerCase();
        const isNameSearchOnly = only_usernames === 'true';

        const finalResult = [];

        await Promise.all(conversations.map(async (conv) => {
            const participants = Array.isArray(conv.conversation_user)
                ? conv.conversation_user.map(cu => cu.users)
                : [];

            let metadataMatched = false;

            if (searchQ) {
                if (!isNameSearchOnly && conv.name && conv.name.toLowerCase().includes(searchQ)) {
                    metadataMatched = true;
                }
                for (const p of participants) {
                    if ((p.username && p.username.toLowerCase().includes(searchQ)) || 
                        (p.name && p.name.toLowerCase().includes(searchQ))) {
                        metadataMatched = true;
                        break;
                    }
                }
            }

            const needsQMatch = searchQ.length > 0;

            if (isNameSearchOnly && needsQMatch && !metadataMatched) {
                return; // drop
            }

            // Builds message query filters for search matching.
            let msgQuery = supabase.from("messages").select(`
                id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, created_at, updated_at, edited_at, is_forwarded
            `).eq("conversation_id", conv.id).is("deleted_at", null).order('created_at', { ascending: false });

            let requiresSpecializedQuery = false;

            if (file_type === 'images') { msgQuery = msgQuery.ilike('attachment_type', 'image/%'); requiresSpecializedQuery = true; }
            else if (file_type === 'videos') { msgQuery = msgQuery.ilike('attachment_type', 'video/%'); requiresSpecializedQuery = true; }
            else if (file_type === 'documents') {
                msgQuery = msgQuery.not('attachment_type', 'is', null)
                    .not('attachment_type', 'ilike', 'image/%')
                    .not('attachment_type', 'ilike', 'video/%');
                requiresSpecializedQuery = true;
            }

            let textMatchRequiredAtQueryLevel = false;

            if (needsQMatch && !isNameSearchOnly && !metadataMatched && !file_type) {
                msgQuery = msgQuery.ilike('body', `%${searchQ}%`);
                requiresSpecializedQuery = true;
                textMatchRequiredAtQueryLevel = true;
            } else if (needsQMatch && !isNameSearchOnly && file_type) {
                if (!metadataMatched) {
                    msgQuery = msgQuery.ilike('body', `%${searchQ}%`);
                    textMatchRequiredAtQueryLevel = true;
                }
            }

            let previewMsg = null;

            if (requiresSpecializedQuery) {
                const { data: matchedData } = await msgQuery.limit(1);
                previewMsg = matchedData && matchedData.length > 0 ? matchedData[0] : null;

                if (!previewMsg && textMatchRequiredAtQueryLevel) return; // Drop
                if (file_type && !previewMsg) return; // Drop
            }

            // If we didn't require a specialized query or we got a match on metadata but still need a preview message fallback:
            if (!previewMsg) {
                const { data: latestRaw } = await supabase.from("messages").select(`
                    id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, created_at, updated_at, edited_at
                `).eq("conversation_id", conv.id).is("deleted_at", null).order('created_at', { ascending: false }).limit(1);
                previewMsg = latestRaw && latestRaw.length > 0 ? latestRaw[0] : null;
            }

            const image = conv.conversation_settings?.[0]?.image || conv.conversation_settings?.image || null;

            finalResult.push({
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
            });
        }));

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

// Creates a direct or group conversation.
export const createConversation = async (req, res) => {
    const { creatorId, participantIds, name } = req.body;

    if (!creatorId || !participantIds || participantIds.length === 0) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const allParticipants = [...new Set([creatorId, ...participantIds])];
        const isGroup = allParticipants.length > 2;

        // Handles direct message conversation behavior.
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
                const ids = conv.conversation_user
                    .map((u) => u.user_id)
                    .sort();
                return (
                    JSON.stringify(ids) ===
                    JSON.stringify([...allParticipants].sort())
                );
            });

            if (existingConversation) {
                // Unarchive if archived
                const archivedEntries = existingConversation.conversation_user.filter(
                    (u) => u.is_archived,
                );
                if (archivedEntries.length > 0) {
                    await supabase
                        .from("conversation_user")
                        .update({ is_archived: false })
                        .eq("conversation_id", existingConversation.id);
                }

                // Return full conversation
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

        // Creates the conversation record.
        const { data: newConversation, error } = await supabase
            .from("conversations")
            .insert({
                name: isGroup ? name : null,
                is_group: isGroup,
            })
            .select()
            .single();

        if (error) throw error;

        // Inserts participants with default or admin roles.
        const inserts = allParticipants.map((uid) => ({
            conversation_id: newConversation.id,
            user_id: uid,
            role: uid === creatorId ? 1 : 0, // creator = admin
            is_creator: uid === creatorId,
        }));

        const { error: insertError } = await supabase
            .from("conversation_user")
            .insert(inserts);

        if (insertError) throw insertError;

        // Creates default settings for new conversations.
        const { error: settingsError } = await supabase
            .from("conversation_settings")
            .insert({ conversation_id: newConversation.id });

        if (settingsError) throw settingsError;

        // Returns the formatted conversation payload.
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

// Returns paginated messages for a conversation.
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

        // Marks pending incoming messages as delivered.
        if (requestingUserId) {
            await supabase
                .from("messages")
                .update({ delivered_at: now })
                .eq("conversation_id", conversationId)
                .neq("user_id", requestingUserId)
                .is("delivered_at", null);
        }

        if (around) {
            // Get the target message
            const { data: targetMsg, error: targetErr } = await supabase
                .from("messages")
                .select("created_at, id")
                .eq("id", around)
                .eq("conversation_id", conversationId)
                .single();

            if (targetErr || !targetMsg) {
                return res.status(404).json({ error: "Mensagem não encontrada." });
            }

            const aroundLimit = Math.floor(limit / 2);

            // Get messages BEFORE the target
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
                `
                )
                .eq("conversation_id", conversationId)
                .is("deleted_at", null)
                .or(`expires_at.is.null,expires_at.gt.${now}`)
                .lt("created_at", targetMsg.created_at)
                .order("created_at", { ascending: false })
                .limit(aroundLimit);

            // Get the target message details
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
                `
                )
                .eq("id", around)
                .single();

            // Get messages AFTER the target
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
                `
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

            let othersLastRead = [];
            if (requestingUserId) {
                const { data: otherReads } = await supabase
                    .from("conversation_user")
                    .select("user_id, last_read_at")
                    .eq("conversation_id", conversationId)
                    .neq("user_id", requestingUserId);

                othersLastRead = otherReads || [];
            }

            const formatted = combined.map((msg) => {
                let status = 0;
                if (msg.user_id === requestingUserId) {
                    if (msg.delivered_at) status = 1;
                    const isRead = othersLastRead.some(
                        (r) =>
                            r.last_read_at &&
                            new Date(r.last_read_at) >=
                                new Date(msg.created_at),
                    );
                    if (isRead) status = 2;
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
                    is_system: msg.is_system || false,
                    status,
                    is_forwarded: msg.is_forwarded || false,
                    created_at: msg.created_at,
                    updated_at: msg.updated_at,
                    edited_at: msg.edited_at,
                    sender_username: msg.users?.username ?? null,
                    sender_avatar: msg.users?.avatar ?? null,
                };
            });

            const targetIndex = formatted.findIndex((m) => m.id === around);
            const enrichedAround = await enrichMessagesWithReplyAndReactions(formatted, requestingUserId);

            let myLastReadAt = null;
            if (requestingUserId) {
                const { data: myMembership } = await supabase
                    .from("conversation_user")
                    .select("last_read_at")
                    .eq("conversation_id", conversationId)
                    .eq("user_id", requestingUserId)
                    .single();

                myLastReadAt = myMembership?.last_read_at || null;
            }

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

        // Applies cursor pagination to load older messages.
        if (before) {
            // Get the created_at of the cursor message
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

        // Checks whether additional messages are available.
        const hasMore = messages.length > limit;
        const pageMessages = hasMore ? messages.slice(0, limit) : messages;

        // Get last_read_at for other participants (for read receipts) 
        let othersLastRead = [];
        if (requestingUserId) {
            const { data: otherReads } = await supabase
                .from("conversation_user")
                .select("user_id, last_read_at")
                .eq("conversation_id", conversationId)
                .neq("user_id", requestingUserId);

            othersLastRead = otherReads || [];
        }

        // Formats message rows for API response.
        const formatted = pageMessages
            .map((msg) => {
                // Determine read status for messages sent by requesting user
                let status = 0; // sent
                if (msg.user_id === requestingUserId) {
                    if (msg.delivered_at) status = 1; // delivered
                    // Check if any other user has read it
                    const isRead = othersLastRead.some(
                        (r) =>
                            r.last_read_at &&
                            new Date(r.last_read_at) >=
                                new Date(msg.created_at),
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
                    is_system: msg.is_system || false,
                    status,
                    is_forwarded: msg.is_forwarded || false,
                    created_at: msg.created_at,
                    updated_at: msg.updated_at,
                    sender_username: msg.users?.username ?? null,
                    sender_avatar: msg.users?.avatar ?? null,
                };
            })
            .reverse(); // Reverse so oldest first
        const enrichedMessages = await enrichMessagesWithReplyAndReactions(formatted, requestingUserId);

        // Get my last_read_at for unread divider
        let myLastReadAt = null;
        if (requestingUserId) {
            const { data: myMembership } = await supabase
                .from("conversation_user")
                .select("last_read_at")
                .eq("conversation_id", conversationId)
                .eq("user_id", requestingUserId)
                .single();

            myLastReadAt = myMembership?.last_read_at || null;
        }

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

// Sends a message to the conversation.
export const sendMessage = async (req, res) => {
    const { conversationId } = req.params;
    const { userId, body, attachment, attachment_type, attachment_name, is_forwarded, reply_to_message_id } =
        req.body;

    if (!conversationId || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // Validates sender permissions before creating the message.
        const { data: settings } = await supabase
            .from("conversation_settings")
            .select("who_can_send_messages, ephemeral_duration")
            .eq("conversation_id", conversationId)
            .single();

        if (settings && settings.who_can_send_messages === 1) {
            // Restricts sending to admins when announcement mode is enabled.
            const { data: membership } = await supabase
                .from("conversation_user")
                .select("role, is_creator")
                .eq("conversation_id", conversationId)
                .eq("user_id", userId)
                .single();

            if (!membership || (membership.role !== 1 && !membership.is_creator)) {
                return res.status(403).json({
                    error: "Apenas admins podem enviar mensagens nesta conversa.",
                });
            }
        }

        let safeReplyToMessageId = null;
        if (reply_to_message_id) {
            const { data: replyTarget, error: replyErr } = await supabase
                .from("messages")
                .select("id, conversation_id")
                .eq("id", reply_to_message_id)
                .single();

            if (replyErr || !replyTarget) {
                return res.status(400).json({ error: "Mensagem de resposta inválida." });
            }
            if (Number(replyTarget.conversation_id) !== Number(conversationId)) {
                return res.status(400).json({ error: "A resposta deve apontar para a mesma conversa." });
            }
            safeReplyToMessageId = replyTarget.id;
        }

        // Calculates expiration timestamp for ephemeral messages.
        let expiresAt = null;
        if (settings && settings.ephemeral_duration > 0) {
            const durationMs = EPHEMERAL_MS[settings.ephemeral_duration] || 0;
            if (durationMs > 0) {
                expiresAt = new Date(Date.now() + durationMs).toISOString();
            }
        }

        // Insert message
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

        let replyTo = null;
        if (message.reply_to_message_id) {
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
                .eq("id", message.reply_to_message_id)
                .single();

            if (replyMessage) {
                replyTo = {
                    id: replyMessage.id,
                    user_id: replyMessage.user_id,
                    sender_username: replyMessage.users?.username ?? null,
                    body: replyMessage.deleted_at ? null : replyMessage.body,
                    attachment_type: replyMessage.deleted_at ? null : replyMessage.attachment_type,
                    attachment_name: replyMessage.deleted_at ? null : replyMessage.attachment_name,
                    deleted_at: replyMessage.deleted_at,
                };
            }
        }

        // Touches conversation timestamp after sending a message.
        await supabase
            .from("conversations")
            .update({ updated_at: new Date().toISOString() })
            .eq("id", conversationId);

        res.status(201).json({
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
        });
    } catch (err) {
        console.error("sendMessage:", err);
        res.status(500).json({ error: "Erro ao enviar mensagem." });
    }
};

// Adds or removes a reaction atomically.
export const toggleMessageReaction = async (req, res) => {
    const messageId = Number(req.params.id);
    const { userId, reaction } = req.body || {};

    if (!messageId || !userId || !reaction) {
        return res.status(400).json({ error: "Dados inválidos para reação." });
    }

    try {
        const { data: message, error: messageErr } = await supabase
            .from("messages")
            .select("id, conversation_id")
            .eq("id", messageId)
            .single();

        if (messageErr || !message) {
            return res.status(404).json({ error: "Mensagem não encontrada." });
        }

        const { error: insertErr } = await supabase
            .from("message_reactions")
            .insert({
                message_id: messageId,
                user_id: userId,
                reaction,
            });

        let added = true;
        if (insertErr) {
            if (insertErr.code !== "23505") throw insertErr;

            const { error: deleteErr } = await supabase
                .from("message_reactions")
                .delete()
                .eq("message_id", messageId)
                .eq("user_id", userId)
                .eq("reaction", reaction);

            if (deleteErr) throw deleteErr;
            added = false;
        }

        return res.status(200).json({
            message_id: messageId,
            conversation_id: message.conversation_id,
            reaction,
            added,
        });
    } catch (err) {
        console.error("toggleMessageReaction:", err);
        return res.status(500).json({ error: "Erro ao alternar reação." });
    }
};

// Search is handled by listConversations filters.

// Updates an editable message body.
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

        if (fetchErr || !targetMsg) return res.status(404).json({ error: "Mensagem não encontrada." });

        const ageHours = (Date.now() - new Date(targetMsg.created_at).getTime()) / (1000 * 60 * 60);
        if (ageHours >= 24) {
            return res.status(403).json({ error: "Apenas pode editar mensagens enviadas nas últimas 24 horas." });
        }

        const { data: message, error } = await supabase
            .from("messages")
            .update({ body, updated_at: new Date().toISOString(), edited_at: new Date().toISOString() })
            .eq("id", messageId)
            .eq("conversation_id", conversationId)
            .select(`
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
            `)
            .single();

        if (error) throw error;
        
        res.json({
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
        });
    } catch (err) {
        console.error("editMessage:", err);
        res.status(500).json({ error: "Erro ao editar mensagem." });
    }
};

// Soft-deletes a message in this conversation.
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

        if (fetchErr || !targetMsg) return res.status(404).json({ error: "Mensagem não encontrada." });

        const ageHours = (Date.now() - new Date(targetMsg.created_at).getTime()) / (1000 * 60 * 60);
        if (ageHours >= 24) {
            return res.status(403).json({ error: "Apenas pode eliminar mensagens enviadas nas últimas 24 horas." });
        }

        // Marks message as deleted without removing the record.
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

// Fetches metadata for URL previews.
export const getLinkPreview = async (req, res) => {
    const { url } = req.query;

    if (!url) {
        return res.status(400).json({ error: "URL obrigatório" });
    }

    try {
        const response = await axios.get(url, {
            timeout: 5000,
            headers: {
                "User-Agent":
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            },
        });

        const html = response.data;
        const $ = cheerio.load(html);

        const getMetaTag = (names) => {
            for (const name of names) {
                const element = $(
                    `meta[property='${name}'], meta[name='${name}']`,
                );
                const content = element.attr("content");
                if (content && content.trim().length > 0) {
                    return content.trim();
                }
            }
            return null;
        };

        const title =
            getMetaTag(["og:title", "twitter:title"]) ||
            $("title").text().trim() ||
            null;
        const description = getMetaTag([
            "og:description",
            "twitter:description",
            "description",
        ]);
        const imageUrl = getMetaTag(["og:image", "twitter:image", "image"]);

        return res.json({
            title,
            description,
            imageUrl,
            url,
        });
    } catch (err) {
        console.error("getLinkPreview error:", err.message);
        // Returns null preview data when metadata scraping fails.
        return res.json(null);
    }
};

// Returns pinned messages for a conversation.
export const getPinnedMessages = async (req, res) => {
    const { conversationId } = req.params;

    if (!conversationId) {
        return res.status(400).json({ error: "Conversation ID obrigatório." });
    }

    try {
        const { data: pins, error } = await supabase
            .from("pinned_messages")
            .select(`
                id,
                message_id,
                messages (
                    id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, delivered_at, expires_at, created_at, updated_at, edited_at, is_forwarded,
                    users ( id, username, avatar )
                )
            `)
            .eq("conversation_id", conversationId)
            .order("created_at", { ascending: true });

        if (error) throw error;

        const formatted = pins.map((pin) => {
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
                pinned_id: pin.id
            };
        }).filter(m => m !== null);

        res.json(formatted);
    } catch (err) {
        console.error("getPinnedMessages error:", err);
        res.status(500).json({ error: "Erro ao buscar mensagens fixadas." });
    }
};

// Pins or unpins a message.
export const toggleMessagePin = async (req, res) => {
    const { conversationId, messageId } = req.params;
    const authId = req.user.id; // From authMiddleware (UUID)

    if (!conversationId || !messageId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // Resolves internal user id from authenticated auth id.
        const { data: userRecord } = await supabase
            .from("users")
            .select("id")
            .eq("auth_id", authId)
            .single();

        if (!userRecord) {
            return res.status(401).json({ error: "Utilizador interno não encontrado." });
        }
        const userId = userRecord.id;

        // Verifies message ownership for this conversation.
        const { data: msg } = await supabase
            .from("messages")
            .select("id")
            .eq("id", messageId)
            .eq("conversation_id", conversationId)
            .single();

        if (!msg) {
            return res.status(404).json({ error: "Mensagem não encontrada." });
        }

        // Checks current pin state before toggling.
        const { data: existingPin } = await supabase
            .from("pinned_messages")
            .select("id")
            .eq("conversation_id", conversationId)
            .eq("message_id", messageId)
            .single();

        if (existingPin) {
            // Removes the message from pinned list.
            const { error: deleteErr } = await supabase
                .from("pinned_messages")
                .delete()
                .eq("id", existingPin.id);

            if (deleteErr) throw deleteErr;
            return res.status(200).json({ status: "unpinned", message_id: messageId });
        } else {
            // Adds the message to pinned list.
            const { error: insertErr } = await supabase
                .from("pinned_messages")
                .insert({
                    conversation_id: conversationId,
                    message_id: messageId,
                    pinned_by: userId
                });

            if (insertErr) throw insertErr;
            return res.status(200).json({ status: "pinned", message_id: messageId });
        }
    } catch (err) {
        console.error("toggleMessagePin error:", err);
        res.status(500).json({ error: "Erro ao alternar fixação da mensagem." });
    }
};
