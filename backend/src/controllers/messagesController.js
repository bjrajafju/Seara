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

    if (!userId) {
        return res.status(400).json({ error: "User ID é obrigatório." });
    }

    try {
        // Get conversation memberships (non-archived)
        const { data: userConversations, error: convError } = await supabase
            .from("conversation_user")
            .select("conversation_id, is_pinned, last_read_at")
            .eq("user_id", userId)
            .eq("is_archived", false);

        if (convError) throw convError;

        if (!userConversations || userConversations.length === 0) {
            return res.json([]);
        }

        const conversationIds = userConversations.map((c) => c.conversation_id);
        const membershipMap = {};
        for (const uc of userConversations) {
            membershipMap[uc.conversation_id] = {
                is_pinned: uc.is_pinned,
                last_read_at: uc.last_read_at,
            };
        }

        // Fetch conversations with participants and last message
        const { data: conversations, error } = await supabase
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
                ),
                conversation_settings (
                    image
                )
            `,
            )
            .in("id", conversationIds)
            .order("updated_at", { ascending: false });

        if (error) throw error;

        // Count unread messages per conversation
        const unreadCounts = {};
        for (const uc of userConversations) {
            const { count, error: countError } = await supabase
                .from("messages")
                .select("id", { count: "exact", head: true })
                .eq("conversation_id", uc.conversation_id)
                .neq("user_id", userId)
                .gt("created_at", uc.last_read_at || "1970-01-01T00:00:00Z");

            if (!countError) {
                unreadCounts[uc.conversation_id] = count || 0;
            }
        }

        // Format response
        const formatted = conversations.map((conv) => {
            const participants = Array.isArray(conv.conversation_user)
                ? conv.conversation_user.map((cu) => cu.users)
                : [];

            const messages = Array.isArray(conv.messages) ? conv.messages : [];
            const sortedMessages = messages.sort(
                (a, b) => new Date(b.created_at) - new Date(a.created_at),
            );

            const membership = membershipMap[conv.id] || {};
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
                messages: sortedMessages.slice(0, 1),
                is_pinned: membership.is_pinned || false,
                unread_count: unreadCounts[conv.id] || 0,
                created_at: conv.created_at,
                updated_at: conv.updated_at,
            };
        });

        // Sort: pinned first, then by updated_at
        formatted.sort((a, b) => {
            if (a.is_pinned && !b.is_pinned) return -1;
            if (!a.is_pinned && b.is_pinned) return 1;
            return new Date(b.updated_at) - new Date(a.updated_at);
        });

        res.json(formatted);
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

// ══════════════════════════════════════════════════════════════════
// GET /conversations/search/:userId — Search conversations
// ══════════════════════════════════════════════════════════════════
export const searchMessages = async (req, res) => {
    const { userId } = req.params;
    const { q } = req.query;

    if (!userId || !q || q.trim().length === 0) {
        return res.status(400).json({ error: "Parâmetros inválidos." });
    }

    try {
        const { data: userConversations, error: convError } = await supabase
            .from("conversation_user")
            .select("conversation_id")
            .eq("user_id", userId)
            .eq("is_archived", false);

        if (convError) throw convError;

        const conversationIds = userConversations.map(
            (c) => c.conversation_id,
        );

        if (conversationIds.length === 0) {
            return res.json([]);
        }

        const now = new Date().toISOString();

        const { data: messages, error: msgError } = await supabase
            .from("messages")
            .select(
                `
                id,
                conversation_id,
                user_id,
                body,
                attachment,
                created_at,
                updated_at,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .in("conversation_id", conversationIds)
            .ilike("body", `%${q.trim()}%`)
            .or(`expires_at.is.null,expires_at.gt.${now}`)
            .order("created_at", { ascending: false });

        if (msgError) throw msgError;

        const conversationMap = new Map();
        for (const msg of messages) {
            if (!conversationMap.has(msg.conversation_id)) {
                conversationMap.set(msg.conversation_id, msg);
            }
        }

        if (conversationMap.size === 0) {
            return res.json([]);
        }

        const matchedIds = Array.from(conversationMap.keys());

        const { data: conversations, error: fullError } = await supabase
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
            .in("id", matchedIds);

        if (fullError) throw fullError;

        const formatted = conversations.map((conv) => {
            const matchedMsg = conversationMap.get(conv.id);
            const participants = Array.isArray(conv.conversation_user)
                ? conv.conversation_user.map((cu) => cu.users)
                : [];

            return {
                id: conv.id,
                name: conv.name,
                is_group: conv.is_group,
                participants,
                messages: [
                    {
                        id: matchedMsg.id,
                        conversation_id: matchedMsg.conversation_id,
                        user_id: matchedMsg.user_id,
                        body: matchedMsg.body,
                        attachment: matchedMsg.attachment,
                        created_at: matchedMsg.created_at,
                        updated_at: matchedMsg.updated_at,
                        sender_username: matchedMsg.users?.username ?? null,
                        sender_avatar: matchedMsg.users?.avatar ?? null,
                    },
                ],
                created_at: conv.created_at,
                updated_at: conv.updated_at,
            };
        });

        res.json(formatted);
    } catch (err) {
        console.error("searchMessages:", err);
        res.status(500).json({ error: "Erro ao pesquisar mensagens." });
    }
};

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
