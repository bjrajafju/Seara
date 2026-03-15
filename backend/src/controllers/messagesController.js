import supabase from "../services/supabase.js";

export const listConversations = async (req, res) => {
    const { userId } = req.params;

    if (!userId) {
        return res.status(400).json({ error: "User ID é obrigatório." });
    }

    try {
        // Buscar IDs das conversas onde o user participa
        const { data: userConversations, error: convError } = await supabase
            .from("conversation_user")
            .select("conversation_id")
            .eq("user_id", userId);

        if (convError) throw convError;

        const conversationIds = userConversations.map((c) => c.conversation_id);

        if (conversationIds.length === 0) {
            return res.json([]);
        }

        // Buscar conversas + participantes + última mensagem
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
                    created_at,
                    updated_at
                )
            `,
            )
            .in("id", conversationIds)
            .order("updated_at", { ascending: false });

        if (error) throw error;

        // Transformar estrutura para ficar clean para Flutter
        const formatted = conversations.map((conv) => {
            const participants = Array.isArray(conv.conversation_user)
                ? conv.conversation_user.map((cu) => cu.users)
                : [];

            // ordenar mensagens por data
            const messages = Array.isArray(conv.messages) ? conv.messages : [];

            const sortedMessages = messages.sort(
                (a, b) => new Date(b.created_at) - new Date(a.created_at),
            );

            return {
                id: conv.id,
                name: conv.name,
                is_group: conv.is_group,
                participants,
                messages: sortedMessages.slice(0, 1), // só última mensagem
                created_at: conv.created_at,
                updated_at: conv.updated_at,
            };
        });

        res.json(formatted);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro ao listar conversas." });
    }
};

export const createConversation = async (req, res) => {
    const { creatorId, participantIds, name } = req.body;

    if (!creatorId || !participantIds || participantIds.length === 0) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const allParticipants = [...new Set([creatorId, ...participantIds])];

        const isGroup = allParticipants.length > 2;

        // Se for conversa 1:1 verificar se já existe
        if (!isGroup) {
            const { data: conversations, error } = await supabase
                .from("conversations")
                .select(
                    `
            id,
            conversation_user ( user_id )
        `,
                )
                .eq("is_group", false);

            if (error) throw error;

            const existingConversation = conversations.find((conv) => {
                const ids = conv.conversation_user.map((u) => u.user_id).sort();
                return (
                    JSON.stringify(ids) ===
                    JSON.stringify(allParticipants.sort())
                );
            });

            if (existingConversation) {
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

        // Criar conversa
        const { data: newConversation, error } = await supabase
            .from("conversations")
            .insert({
                name: isGroup ? name : null,
                is_group: isGroup,
            })
            .select()
            .single();

        if (error) throw error;

        // Inserir participantes
        const inserts = allParticipants.map((userId) => ({
            conversation_id: newConversation.id,
            user_id: userId,
        }));

        const { error: insertError } = await supabase
            .from("conversation_user")
            .insert(inserts);

        if (insertError) throw insertError;

        // Buscar conversa completa formatada
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
        console.error(err);
        res.status(500).json({ error: "Erro ao criar conversa." });
    }
};

export const getMessages = async (req, res) => {
    const { conversationId } = req.params;

    if (!conversationId) {
        return res
            .status(400)
            .json({ error: "Conversation ID e obrigatorio." });
    }

    try {
        const { data: messages, error } = await supabase
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
            .order("created_at", { ascending: true });

        if (error) throw error;

        const formatted = messages.map((msg) => ({
            id: msg.id,
            conversation_id: msg.conversation_id,
            user_id: msg.user_id,
            body: msg.body,
            attachment: msg.attachment,
            attachment_type: msg.attachment_type,
            attachment_name: msg.attachment_name,
            created_at: msg.created_at,
            updated_at: msg.updated_at,
            sender_username: msg.users?.username ?? null,
            sender_avatar: msg.users?.avatar ?? null,
        }));

        res.json(formatted);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro ao buscar mensagens." });
    }
};

export const sendMessage = async (req, res) => {
    const { conversationId } = req.params;
    const { userId, body, attachment, attachment_type, attachment_name } =
        req.body;

    if (!conversationId || !userId || (!body && !attachment)) {
        return res.status(400).json({ error: "Dados invalidos." });
    }

    try {
        const { data: message, error } = await supabase
            .from("messages")
            .insert({
                conversation_id: parseInt(conversationId),
                user_id: userId,
                body: body ?? "",
                attachment: attachment ?? null,
                attachment_type: attachment_type ?? null,
                attachment_name: attachment_name ?? null,
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

        // Atualizar updated_at da conversa para ordenacao correta na lista
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
            created_at: message.created_at,
            updated_at: message.updated_at,
            sender_username: message.users?.username ?? null,
            sender_avatar: message.users?.avatar ?? null,
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro ao enviar mensagem." });
    }
};

export const searchMessages = async (req, res) => {
    const { userId } = req.params;
    const { q } = req.query;

    if (!userId || !q || q.trim().length === 0) {
        return res.status(400).json({ error: "Parametros invalidos." });
    }

    try {
        // Buscar IDs das conversas do utilizador
        const { data: userConversations, error: convError } = await supabase
            .from("conversation_user")
            .select("conversation_id")
            .eq("user_id", userId);

        if (convError) throw convError;

        const conversationIds = userConversations.map((c) => c.conversation_id);

        if (conversationIds.length === 0) {
            return res.json([]);
        }

        // Pesquisar mensagens com o texto em todas as conversas do utilizador
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
            .order("created_at", { ascending: false });

        if (msgError) throw msgError;

        // Agrupar por conversa, ficando com a mensagem mais recente de cada
        const conversationMap = new Map();
        for (const msg of messages) {
            if (!conversationMap.has(msg.conversation_id)) {
                conversationMap.set(msg.conversation_id, msg);
            }
        }

        if (conversationMap.size === 0) {
            return res.json([]);
        }

        // Buscar dados completos das conversas com match
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
        console.error(err);
        res.status(500).json({ error: "Erro ao pesquisar mensagens." });
    }
};
