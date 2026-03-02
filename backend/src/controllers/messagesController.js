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
