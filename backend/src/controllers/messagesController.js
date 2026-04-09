import supabase from "../services/supabase.js";
import axios from "axios";
import * as cheerio from "cheerio";

// ── Constants ────────────────────────────────────────────────────
const DEFAULT_PAGE_SIZE = 30;

// Ephemeral duration in ms: 0=off, 1=24h, 2=7d, 3=30d
const EPHEMERAL_MS = {
    0: 0,
    1: 24 * 60 * 60 * 1000,
    2: 7 * 24 * 60 * 60 * 1000,
    3: 30 * 24 * 60 * 60 * 1000,
};

// ══════════════════════════════════════════════════════════════════
// GET /conversations/:userId — List conversations
// ══════════════════════════════════════════════════════════════════
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
        // 1. Get Base Memberships
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

        // 2. Fetch Conversations Metadata
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

        // Compute Unread Counts via parallel promises
        const unreadCounts = {};
        await Promise.all(userConversations.map(async (uc) => {
            const { count } = await supabase
                .from("messages")
                .select("id", { count: "exact", head: true })
                .eq("conversation_id", uc.conversation_id)
                .neq("user_id", userId)
                .gt("created_at", uc.last_read_at || "1970-01-01T00:00:00Z");
            unreadCounts[uc.conversation_id] = count || 0;
        }));

        if (unread === 'true') {
            conversations = conversations.filter(c => unreadCounts[c.id] > 0);
            if (conversations.length === 0) return res.json([]);
        }

        // 3. Search Matching (Text & Files) via Parallel Evaluator
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

            // Message querying
            let msgQuery = supabase.from("messages").select(`
                id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, created_at, updated_at
            `).eq("conversation_id", conv.id).order('created_at', { ascending: false });

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
                    id, conversation_id, user_id, body, attachment, attachment_type, attachment_name, created_at, updated_at
                `).eq("conversation_id", conv.id).order('created_at', { ascending: false }).limit(1);
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

// ══════════════════════════════════════════════════════════════════
// POST /conversations — Create conversation
// ══════════════════════════════════════════════════════════════════
export const createConversation = async (req, res) => {
    const { creatorId, participantIds, name } = req.body;

    if (!creatorId || !participantIds || participantIds.length === 0) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const allParticipants = [...new Set([creatorId, ...participantIds])];
        const isGroup = allParticipants.length > 2;

        // ── 1:1: check for existing (including archived) ─────────────
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

        // ── Create conversation ──────────────────────────────────────
        const { data: newConversation, error } = await supabase
            .from("conversations")
            .insert({
                name: isGroup ? name : null,
                is_group: isGroup,
            })
            .select()
            .single();

        if (error) throw error;

        // ── Insert participants with roles ────────────────────────────
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

        // ── Create default settings ──────────────────────────────────
        const { error: settingsError } = await supabase
            .from("conversation_settings")
            .insert({ conversation_id: newConversation.id });

        if (settingsError) throw settingsError;

        // ── Return formatted conversation ────────────────────────────
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

// ══════════════════════════════════════════════════════════════════
// GET /conversations/:conversationId/messages — Paginated
// ══════════════════════════════════════════════════════════════════
export const getMessages = async (req, res) => {
    const { conversationId } = req.params;
    const limit = parseInt(req.query.limit) || DEFAULT_PAGE_SIZE;
    const before = req.query.before ? parseInt(req.query.before) : null;
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

        // ── Mark undelivered messages as delivered ───────────────────
        if (requestingUserId) {
            await supabase
                .from("messages")
                .update({ delivered_at: now })
                .eq("conversation_id", conversationId)
                .neq("user_id", requestingUserId)
                .is("delivered_at", null);
        }

        // ── Build query ──────────────────────────────────────────────
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
                delivered_at,
                expires_at,
                is_system,
                created_at,
                updated_at,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .eq("conversation_id", conversationId)
            .or(`expires_at.is.null,expires_at.gt.${now}`)
            .order("created_at", { ascending: false })
            .limit(limit + 1); // +1 to check has_more

        // Cursor pagination: load messages before this ID
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

        // Check if there are more messages
        const hasMore = messages.length > limit;
        const pageMessages = hasMore ? messages.slice(0, limit) : messages;

        // ── Get last_read_at for other participants (for read receipts) ──
        let othersLastRead = [];
        if (requestingUserId) {
            const { data: otherReads } = await supabase
                .from("conversation_user")
                .select("user_id, last_read_at")
                .eq("conversation_id", conversationId)
                .neq("user_id", requestingUserId);

            othersLastRead = otherReads || [];
        }

        // Format messages
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
                    delivered_at: msg.delivered_at,
                    is_system: msg.is_system || false,
                    status,
                    created_at: msg.created_at,
                    updated_at: msg.updated_at,
                    sender_username: msg.users?.username ?? null,
                    sender_avatar: msg.users?.avatar ?? null,
                };
            })
            .reverse(); // Reverse so oldest first

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
            messages: formatted,
            has_more: hasMore,
            last_read_at: myLastReadAt,
        });
    } catch (err) {
        console.error("getMessages:", err);
        res.status(500).json({ error: "Erro ao buscar mensagens." });
    }
};

// ══════════════════════════════════════════════════════════════════
// POST /conversations/:conversationId/messages — Send message
// ══════════════════════════════════════════════════════════════════
export const sendMessage = async (req, res) => {
    const { conversationId } = req.params;
    const { userId, body, attachment, attachment_type, attachment_name } =
        req.body;

    if (!conversationId || !userId || (!body && !attachment)) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // ── Check send permission ────────────────────────────────────
        const { data: settings } = await supabase
            .from("conversation_settings")
            .select("who_can_send_messages, ephemeral_duration")
            .eq("conversation_id", conversationId)
            .single();

        if (settings && settings.who_can_send_messages === 1) {
            // Admins only — check if user is admin
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

        // ── Calculate expires_at if ephemeral ────────────────────────
        let expiresAt = null;
        if (settings && settings.ephemeral_duration > 0) {
            const durationMs = EPHEMERAL_MS[settings.ephemeral_duration] || 0;
            if (durationMs > 0) {
                expiresAt = new Date(Date.now() + durationMs).toISOString();
            }
        }

        // ── Insert message ───────────────────────────────────────────
        const { data: message, error } = await supabase
            .from("messages")
            .insert({
                conversation_id: parseInt(conversationId),
                user_id: userId,
                body: body ?? "",
                attachment: attachment ?? null,
                attachment_type: attachment_type ?? null,
                attachment_name: attachment_name ?? null,
                expires_at: expiresAt,
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
                delivered_at,
                expires_at,
                created_at,
                updated_at,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .single();

        if (error) throw error;

        // Update conversation updated_at
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
            delivered_at: message.delivered_at,
            status: 0, // just sent
            created_at: message.created_at,
            updated_at: message.updated_at,
            sender_username: message.users?.username ?? null,
            sender_avatar: message.users?.avatar ?? null,
        });
    } catch (err) {
        console.error("sendMessage:", err);
        res.status(500).json({ error: "Erro ao enviar mensagem." });
    }
};

// Removed searchMessages (Logic unified into listConversations)

// ══════════════════════════════════════════════════════════════════
// GET /messages/link-preview — Link preview
// ══════════════════════════════════════════════════════════════════
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
        // Silent error handling: return null if we can't scrape
        return res.json(null);
    }
};
