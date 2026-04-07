import supabase from "../services/supabase.js";

// ── Helper: check if user is admin in conversation ──────────────
const isAdmin = async (conversationId, userId) => {
    const { data } = await supabase
        .from("conversation_user")
        .select("role, is_creator")
        .eq("conversation_id", conversationId)
        .eq("user_id", userId)
        .single();
    return data && (data.role === 1 || data.is_creator);
};

// ── Helper: check if user is member ─────────────────────────────
const isMember = async (conversationId, userId) => {
    const { data } = await supabase
        .from("conversation_user")
        .select("id")
        .eq("conversation_id", conversationId)
        .eq("user_id", userId)
        .maybeSingle();
    return !!data;
};

// ── Helper: insert system message ───────────────────────────────
const insertSystemMessage = async (conversationId, body) => {
    await supabase.from("messages").insert({
        conversation_id: conversationId,
        user_id: 0,
        body: body,
        is_system: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
    });
    // Also update conversation's updated_at
    await supabase
        .from("conversations")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", conversationId);
};

// ── Helper: check permission level ──────────────────────────────
const hasPermission = async (conversationId, userId, permissionField) => {
    const { data: settings } = await supabase
        .from("conversation_settings")
        .select(permissionField)
        .eq("conversation_id", conversationId)
        .single();

    if (!settings) return true; // no settings = allow all
    if (settings[permissionField] === 0) return true; // 0 = all

    // 1 = admins only
    return isAdmin(conversationId, userId);
};

// ══════════════════════════════════════════════════════════════════
// GET /:id/details — Full conversation details
// ══════════════════════════════════════════════════════════════════
export const getConversationDetails = async (req, res) => {
    const { id } = req.params;
    const userId = parseInt(req.query.userId);

    if (!id || !userId) {
        return res.status(400).json({ error: "Parâmetros inválidos." });
    }

    try {
        // Check membership
        if (!(await isMember(id, userId))) {
            return res
                .status(403)
                .json({ error: "Não é membro desta conversa." });
        }

        // Fetch conversation
        const { data: conversation, error: convError } = await supabase
            .from("conversations")
            .select("id, name, is_group, created_at, updated_at")
            .eq("id", id)
            .single();

        if (convError) throw convError;

        // Fetch members with roles
        const { data: members, error: membersError } = await supabase
            .from("conversation_user")
            .select(
                `
                user_id,
                role,
                is_creator,
                users (
                    id,
                    username,
                    name,
                    avatar
                )
            `,
            )
            .eq("conversation_id", id)
            .eq("is_archived", false);

        if (membersError) throw membersError;

        // Fetch settings
        const { data: settings } = await supabase
            .from("conversation_settings")
            .select("*")
            .eq("conversation_id", id)
            .single();

        // Fetch my notification preferences
        const { data: notification } = await supabase
            .from("conversation_notifications")
            .select("*")
            .eq("conversation_id", id)
            .eq("user_id", userId)
            .maybeSingle();

        // Fetch my membership info
        const { data: myMembership } = await supabase
            .from("conversation_user")
            .select("role, is_creator, is_pinned, last_read_at")
            .eq("conversation_id", id)
            .eq("user_id", userId)
            .single();

        // Task 3: Filter out system user (id=0) from members
        const formattedMembers = (members || [])
            .filter((m) => m.users && m.users.id !== 0)
            .map((m) => ({
                id: m.users.id,
                username: m.users.username,
                name: m.users.name,
                avatar: m.users.avatar,
                role: m.role,
                is_creator: m.is_creator,
            }));

        res.json({
            ...conversation,
            image: settings?.image || null,
            members: formattedMembers,
            settings: settings
                ? {
                      who_can_manage_members: settings.who_can_manage_members,
                      who_can_edit_info: settings.who_can_edit_info,
                      who_can_send_messages: settings.who_can_send_messages,
                      who_can_edit_bio: settings.who_can_edit_bio,
                      ephemeral_duration: settings.ephemeral_duration,
                      theme: settings.theme,
                  }
                : null,
            description: settings?.description || null,
            my_role: myMembership?.role ?? 0,
            is_creator: myMembership?.is_creator ?? false,
            is_pinned: myMembership?.is_pinned ?? false,
            notification: notification
                ? {
                      is_muted: notification.is_muted,
                      muted_until: notification.muted_until,
                  }
                : { is_muted: false, muted_until: null },
        });
    } catch (err) {
        console.error("getConversationDetails:", err);
        res.status(500).json({ error: "Erro ao obter detalhes da conversa." });
    }
};

// ══════════════════════════════════════════════════════════════════
// PUT /:id/name — Update conversation name
// ══════════════════════════════════════════════════════════════════
export const updateConversationName = async (req, res) => {
    const { id } = req.params;
    const { userId, name } = req.body;

    if (!id || !userId || !name?.trim()) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        if (!(await hasPermission(id, userId, "who_can_edit_info"))) {
            return res
                .status(403)
                .json({ error: "Sem permissão para editar." });
        }

        const { error } = await supabase
            .from("conversations")
            .update({ name: name.trim(), updated_at: new Date().toISOString() })
            .eq("id", id);

        if (error) throw error;

        // FIX #11: System message
        const { data: actor } = await supabase
            .from("users")
            .select("username")
            .eq("id", userId)
            .single();
        await insertSystemMessage(
            id,
            `${actor?.username || "Alguém"} alterou o nome do grupo para "${name.trim()}"`,
        );

        res.json({ success: true, name: name.trim() });
    } catch (err) {
        console.error("updateConversationName:", err);
        res.status(500).json({ error: "Erro ao atualizar nome." });
    }
};

// ══════════════════════════════════════════════════════════════════
// PUT /:id/image — Update conversation image
// ══════════════════════════════════════════════════════════════════
export const updateConversationImage = async (req, res) => {
    const { id } = req.params;
    const { userId, image } = req.body;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        if (!(await hasPermission(id, userId, "who_can_edit_info"))) {
            return res
                .status(403)
                .json({ error: "Sem permissão para editar." });
        }

        const { error } = await supabase
            .from("conversation_settings")
            .update({ image, updated_at: new Date().toISOString() })
            .eq("conversation_id", id);

        if (error) throw error;

        // FIX #11: System message
        const { data: actor } = await supabase
            .from("users")
            .select("username")
            .eq("id", userId)
            .single();
        await insertSystemMessage(
            id,
            `${actor?.username || "Alguém"} alterou a imagem do grupo`,
        );

        res.json({ success: true, image });
    } catch (err) {
        console.error("updateConversationImage:", err);
        res.status(500).json({ error: "Erro ao atualizar imagem." });
    }
};

// ══════════════════════════════════════════════════════════════════
// POST /:id/members — Add members
// ══════════════════════════════════════════════════════════════════
export const addMembers = async (req, res) => {
    const { id } = req.params;
    const { userId, memberIds } = req.body;

    if (!id || !userId || !Array.isArray(memberIds) || memberIds.length === 0) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        if (!(await hasPermission(id, userId, "who_can_manage_members"))) {
            return res
                .status(403)
                .json({ error: "Sem permissão para gerir membros." });
        }

        // Filter out already-existing members
        const { data: existing } = await supabase
            .from("conversation_user")
            .select("user_id")
            .eq("conversation_id", id)
            .in("user_id", memberIds);

        const existingIds = new Set((existing || []).map((e) => e.user_id));
        const newIds = memberIds.filter((mid) => !existingIds.has(mid));

        if (newIds.length === 0) {
            return res.json({ success: true, added: [] });
        }

        const inserts = newIds.map((uid) => ({
            conversation_id: parseInt(id),
            user_id: uid,
            role: 0,
            is_creator: false,
        }));

        const { error } = await supabase
            .from("conversation_user")
            .insert(inserts);

        if (error) throw error;

        // Fetch added users info
        const { data: addedUsers } = await supabase
            .from("users")
            .select("id, username, name, avatar")
            .in("id", newIds);

        // FIX #11: System messages for each added member
        const { data: actor } = await supabase
            .from("users")
            .select("username")
            .eq("id", userId)
            .single();
        for (const u of addedUsers || []) {
            await insertSystemMessage(
                id,
                `${actor?.username || "Alguém"} adicionou ${u.username}`,
            );
        }

        res.json({
            success: true,
            added: (addedUsers || []).map((u) => ({
                ...u,
                role: 0,
                is_creator: false,
            })),
        });
    } catch (err) {
        console.error("addMembers:", err);
        res.status(500).json({ error: "Erro ao adicionar membros." });
    }
};

// ══════════════════════════════════════════════════════════════════
// DELETE /:id/members/:targetId — Remove member
// ══════════════════════════════════════════════════════════════════
export const removeMember = async (req, res) => {
    const { id, targetId } = req.params;
    const userId = parseInt(req.query.userId);

    if (!id || !targetId || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // Can't remove the creator
        const { data: target } = await supabase
            .from("conversation_user")
            .select("is_creator")
            .eq("conversation_id", id)
            .eq("user_id", targetId)
            .single();

        if (target?.is_creator) {
            return res
                .status(403)
                .json({ error: "Não é possível remover o criador." });
        }

        // Must be admin to remove others
        if (parseInt(targetId) !== userId) {
            if (!(await isAdmin(id, userId))) {
                return res
                    .status(403)
                    .json({ error: "Apenas admins podem remover membros." });
            }
        }

        const { error } = await supabase
            .from("conversation_user")
            .delete()
            .eq("conversation_id", id)
            .eq("user_id", targetId);

        if (error) throw error;

        // FIX #11: System message
        const { data: actor } = await supabase
            .from("users")
            .select("username")
            .eq("id", userId)
            .single();
        const { data: removed } = await supabase
            .from("users")
            .select("username")
            .eq("id", parseInt(targetId))
            .single();
        await insertSystemMessage(
            id,
            `${actor?.username || "Alguém"} removeu ${removed?.username || "um membro"}`,
        );

        res.json({ success: true });
    } catch (err) {
        console.error("removeMember:", err);
        res.status(500).json({ error: "Erro ao remover membro." });
    }
};

// ══════════════════════════════════════════════════════════════════
// PUT /:id/members/:targetId/role — Promote/demote
// ══════════════════════════════════════════════════════════════════
export const updateMemberRole = async (req, res) => {
    const { id, targetId } = req.params;
    const { userId, role } = req.body;

    if (!id || !targetId || !userId || role === undefined) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // Only admins can change roles
        if (!(await isAdmin(id, userId))) {
            return res
                .status(403)
                .json({ error: "Apenas admins podem alterar cargos." });
        }

        // Can't change creator's role
        const { data: target } = await supabase
            .from("conversation_user")
            .select("is_creator")
            .eq("conversation_id", id)
            .eq("user_id", targetId)
            .single();

        if (target?.is_creator) {
            return res
                .status(403)
                .json({ error: "Não é possível alterar o cargo do criador." });
        }

        const { error } = await supabase
            .from("conversation_user")
            .update({ role: parseInt(role) })
            .eq("conversation_id", id)
            .eq("user_id", targetId);

        if (error) throw error;

        res.json({ success: true, role: parseInt(role) });
    } catch (err) {
        console.error("updateMemberRole:", err);
        res.status(500).json({ error: "Erro ao alterar cargo." });
    }
};

// ══════════════════════════════════════════════════════════════════
// PUT /:id/settings — Update conversation settings
// ══════════════════════════════════════════════════════════════════
export const updateSettings = async (req, res) => {
    const { id } = req.params;
    const { userId, ...settingsUpdate } = req.body;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        if (!(await isAdmin(id, userId))) {
            return res
                .status(403)
                .json({ error: "Apenas admins podem alterar definições." });
        }

        const allowedFields = [
            "who_can_manage_members",
            "who_can_edit_info",
            "who_can_send_messages",
            "who_can_edit_bio",
            "ephemeral_duration",
            "theme",
            "description",
        ];

        const updateData = {};
        for (const field of allowedFields) {
            if (settingsUpdate[field] !== undefined) {
                updateData[field] = settingsUpdate[field];
            }
        }
        updateData.updated_at = new Date().toISOString();

        // Fix #1: Enforce who_can_edit_bio permission for description edits
        if (settingsUpdate.description !== undefined) {
            const canEdit = await hasPermission(id, userId, "who_can_edit_bio");
            if (!canEdit) {
                return res
                    .status(403)
                    .json({ error: "Sem permissão para editar a descrição." });
            }
        }

        // Fetch current settings to detect changes for system messages
        const { data: currentSettings } = await supabase
            .from("conversation_settings")
            .select("theme, ephemeral_duration")
            .eq("conversation_id", id)
            .single();

        const { error } = await supabase
            .from("conversation_settings")
            .update(updateData)
            .eq("conversation_id", id);

        if (error) throw error;

        // Fetch username for system messages
        const { data: user } = await supabase
            .from("users")
            .select("username")
            .eq("id", userId)
            .single();
        const username = user?.username || "Alguém";

        // Task 2: System message for theme change
        if (
            settingsUpdate.theme !== undefined &&
            currentSettings &&
            settingsUpdate.theme !== currentSettings.theme
        ) {
            const themeNames = {
                0: "Padrão",
                1: "Oceano",
                2: "Pôr do Sol",
                3: "Floresta",
                4: "Meia-noite",
            };
            const themeName = themeNames[settingsUpdate.theme] || "Padrão";
            await insertSystemMessage(
                id,
                `${username} alterou o tema para ${themeName}`,
            );
        }

        // Task 2: System message for ephemeral toggle
        if (
            settingsUpdate.ephemeral_duration !== undefined &&
            currentSettings &&
            settingsUpdate.ephemeral_duration !==
                currentSettings.ephemeral_duration
        ) {
            const durLabels = {
                0: "desativou",
                1: "24 horas",
                2: "7 dias",
                3: "30 dias",
            };
            if (settingsUpdate.ephemeral_duration === 0) {
                await insertSystemMessage(
                    id,
                    `${username} desativou as mensagens temporárias`,
                );
            } else {
                const label =
                    durLabels[settingsUpdate.ephemeral_duration] || "";
                await insertSystemMessage(
                    id,
                    `${username} ativou mensagens temporárias (${label})`,
                );
            }
        }

        res.json({ success: true, ...updateData });
    } catch (err) {
        console.error("updateSettings:", err);
        res.status(500).json({ error: "Erro ao atualizar definições." });
    }
};

// ══════════════════════════════════════════════════════════════════
// PUT /:id/notifications — Update user notification preferences
// ══════════════════════════════════════════════════════════════════
export const updateNotifications = async (req, res) => {
    const { id } = req.params;
    const { userId, isMuted, mutedUntil } = req.body;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const { error } = await supabase
            .from("conversation_notifications")
            .upsert(
                {
                    conversation_id: parseInt(id),
                    user_id: userId,
                    is_muted: isMuted ?? false,
                    muted_until: mutedUntil ?? null,
                },
                { onConflict: "conversation_id,user_id" },
            );

        if (error) throw error;

        res.json({ success: true, is_muted: isMuted, muted_until: mutedUntil });
    } catch (err) {
        console.error("updateNotifications:", err);
        res.status(500).json({ error: "Erro ao atualizar notificações." });
    }
};

// ══════════════════════════════════════════════════════════════════
// POST /:id/leave — Leave conversation
// ══════════════════════════════════════════════════════════════════
export const leaveConversation = async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // Check if conversation is group or 1:1
        const { data: conv } = await supabase
            .from("conversations")
            .select("is_group")
            .eq("id", id)
            .single();

        if (!conv) {
            return res.status(404).json({ error: "Conversa não encontrada." });
        }

        if (conv.is_group) {
            // Check if user is creator — creator can't leave
            const { data: membership } = await supabase
                .from("conversation_user")
                .select("is_creator")
                .eq("conversation_id", id)
                .eq("user_id", userId)
                .single();

            if (membership?.is_creator) {
                return res.status(403).json({
                    error: "O criador não pode sair do grupo. Transfira a propriedade primeiro.",
                });
            }

            // Remove from conversation_user
            const { error } = await supabase
                .from("conversation_user")
                .delete()
                .eq("conversation_id", id)
                .eq("user_id", userId);

            if (error) throw error;

            // FIX #11: System message
            const { data: actor } = await supabase
                .from("users")
                .select("username")
                .eq("id", userId)
                .single();
            await insertSystemMessage(
                id,
                `${actor?.username || "Alguém"} saiu do grupo`,
            );
        } else {
            // 1:1 — archive instead of delete
            const { error } = await supabase
                .from("conversation_user")
                .update({ is_archived: true })
                .eq("conversation_id", id)
                .eq("user_id", userId);

            if (error) throw error;
        }

        res.json({ success: true });
    } catch (err) {
        console.error("leaveConversation:", err);
        res.status(500).json({ error: "Erro ao sair da conversa." });
    }
};

// ══════════════════════════════════════════════════════════════════
// PUT /:id/pin — Toggle pin
// ══════════════════════════════════════════════════════════════════
export const togglePin = async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        // Get current state
        const { data: current } = await supabase
            .from("conversation_user")
            .select("is_pinned")
            .eq("conversation_id", id)
            .eq("user_id", userId)
            .single();

        if (!current) {
            return res
                .status(404)
                .json({ error: "Não é membro desta conversa." });
        }

        const newState = !current.is_pinned;

        const { error } = await supabase
            .from("conversation_user")
            .update({ is_pinned: newState })
            .eq("conversation_id", id)
            .eq("user_id", userId);

        if (error) throw error;

        res.json({ success: true, is_pinned: newState });
    } catch (err) {
        console.error("togglePin:", err);
        res.status(500).json({ error: "Erro ao fixar/desfixar conversa." });
    }
};

// ══════════════════════════════════════════════════════════════════
// POST /:id/read — Mark conversation as read
// ══════════════════════════════════════════════════════════════════
export const markAsRead = async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        const now = new Date().toISOString();

        const { error } = await supabase
            .from("conversation_user")
            .update({ last_read_at: now })
            .eq("conversation_id", id)
            .eq("user_id", userId);

        if (error) throw error;

        res.json({ success: true, last_read_at: now });
    } catch (err) {
        console.error("markAsRead:", err);
        res.status(500).json({ error: "Erro ao marcar como lido." });
    }
};

// ══════════════════════════════════════════════════════════════════
// GET /:id/search — Search messages with filters
// ══════════════════════════════════════════════════════════════════
export const searchConversationMessages = async (req, res) => {
    const { id } = req.params;
    const { userId, q, type, senderId, from, to } = req.query;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        if (!(await isMember(id, parseInt(userId)))) {
            return res
                .status(403)
                .json({ error: "Não é membro desta conversa." });
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
                created_at,
                updated_at,
                users (
                    id,
                    username,
                    avatar
                )
            `,
            )
            .eq("conversation_id", id)
            .order("created_at", { ascending: false })
            .limit(50);

        // Text filter
        if (q && q.trim().length > 0) {
            query = query.ilike("body", `%${q.trim()}%`);
        }

        // User filter
        if (senderId) {
            query = query.eq("user_id", parseInt(senderId));
        }

        // Type filter (image, video, audio, file)
        if (type) {
            if (type === "image") {
                query = query.ilike("attachment_type", "image/%");
            } else if (type === "video") {
                query = query.ilike("attachment_type", "video/%");
            } else if (type === "audio") {
                query = query.ilike("attachment_type", "audio/%");
            } else if (type === "file") {
                query = query
                    .not("attachment", "is", null)
                    .not("attachment_type", "ilike", "image/%")
                    .not("attachment_type", "ilike", "video/%")
                    .not("attachment_type", "ilike", "audio/%");
            }
        }

        // Date range
        if (from) {
            query = query.gte("created_at", from);
        }
        if (to) {
            query = query.lte("created_at", to);
        }

        // Filter expired ephemerals
        query = query.or(
            "expires_at.is.null,expires_at.gt." + new Date().toISOString(),
        );

        const { data: messages, error } = await query;

        if (error) throw error;

        const formatted = (messages || []).map((msg) => ({
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
        console.error("searchConversationMessages:", err);
        res.status(500).json({ error: "Erro ao pesquisar mensagens." });
    }
};

// ══════════════════════════════════════════════════════════════════
// GET /:id/media — Get shared media by type
// ══════════════════════════════════════════════════════════════════
export const getSharedMedia = async (req, res) => {
    const { id } = req.params;
    const { userId, type } = req.query;

    if (!id || !userId) {
        return res.status(400).json({ error: "Dados inválidos." });
    }

    try {
        if (!(await isMember(id, parseInt(userId)))) {
            return res
                .status(403)
                .json({ error: "Não é membro desta conversa." });
        }

        let query = supabase
            .from("messages")
            .select(
                "id, attachment, attachment_type, attachment_name, created_at, user_id",
            )
            .eq("conversation_id", id)
            .not("attachment", "is", null)
            .order("created_at", { ascending: false })
            .limit(100);

        // FIX #9: 'media' type = images + videos combined
        if (type === "media") {
            query = query.or(
                "attachment_type.ilike.image/%,attachment_type.ilike.video/%",
            );
        } else if (type === "image") {
            query = query.ilike("attachment_type", "image/%");
        } else if (type === "video") {
            query = query.ilike("attachment_type", "video/%");
        } else if (type === "audio") {
            query = query.ilike("attachment_type", "audio/%");
        } else if (type === "file") {
            query = query
                .not("attachment_type", "ilike", "image/%")
                .not("attachment_type", "ilike", "video/%")
                .not("attachment_type", "ilike", "audio/%");
        }

        // Task 10: 'link' type = messages whose body contains URLs (not storage attachments)
        if (type === "link") {
            query = supabase
                .from("messages")
                .select("id, body, created_at, user_id")
                .eq("conversation_id", id)
                .or("body.ilike.%https://%,body.ilike.%http://%")
                .order("created_at", { ascending: false })
                .limit(100);

            // Filter expired
            query = query.or(
                "expires_at.is.null,expires_at.gt." + new Date().toISOString(),
            );

            const { data, error } = await query;
            if (error) throw error;
            return res.json(data || []);
        }

        // Filter expired
        query = query.or(
            "expires_at.is.null,expires_at.gt." + new Date().toISOString(),
        );

        const { data, error } = await query;

        if (error) throw error;

        res.json(data || []);
    } catch (err) {
        console.error("getSharedMedia:", err);
        res.status(500).json({ error: "Erro ao obter media partilhada." });
    }
};
